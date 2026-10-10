(**
Module for psql tool automation. One can use it to create database schema
*)

open Mina_automation_process
open Core
open Async

module Credentials = struct
  type t =
    { user : string option
    ; password : string
    ; host : string option
    ; port : int option
    ; db : string option
    }
end

let create_db_script () =
  match%bind Sys.file_exists "src/app/archive/create_schema.sql" with
  | `Yes ->
      Deferred.return "src/app/archive/create_schema.sql"
  | _ -> (
      match%bind
        Sys.file_exists "_build/default/src/archive/create_schema.sql"
      with
      | `Yes ->
          Deferred.return "_build/default/src/archive/create_schema.sql"
      | _ -> (
          match%bind Sys.file_exists "/etc/mina/archive/create_schema.sql" with
          | `Yes ->
              Deferred.return "/etc/mina/archive/create_schema.sql"
          | _ ->
              failwith "cannot find create db script" ) )

type connection = Conn_str of string | Credentials of Credentials.t

let psql = "psql"

(** psql arguments that reach [connection], or the database [db] on the same
    server. A connection URI goes to psql whole, so a password-less URI (trust,
    .pgpass) and query parameters such as [sslmode] keep working. *)
let create_credential_arg ~connection ?db () =
  let value_or_empty arg item =
    match item with Some item -> [ arg; item ] | None -> []
  in
  match connection with
  | Conn_str conn_str ->
      let uri = Uri.of_string conn_str in
      let uri =
        Option.value_map db ~default:uri ~f:(fun db ->
            Uri.with_path uri ("/" ^ db) )
      in
      [ "-d"; Uri.to_string uri ]
  | Credentials credentials ->
      Unix.putenv ~key:"PGPASSWORD" ~data:credentials.password ;
      value_or_empty "-U" credentials.user
      @ value_or_empty "-p" (Option.map ~f:string_of_int credentials.port)
      @ value_or_empty "-h" credentials.host
      @ value_or_empty "-d" (Option.first_some db credentials.db)

let run_command ~connection command =
  let creds = create_credential_arg ~connection () in
  Cmd.run_cmd_or_error "." psql (creds @ [ "-c"; command; "-t" ])
  >>| Result.map ~f:String.strip

(** [run_command_exn ~connection command] runs a SQL command using psql with the given connection. 
  The command is executed in the current directory, and the output is stripped of leading and trailing whitespace.
  It raises an exception if the command fails.

  @param connection The connection string or credentials to connect to the PostgreSQL database.
  @param command The SQL command to execute.
  @return A deferred string containing the output of the command.
*)

let script_args ~connection ?db script =
  create_credential_arg ~connection ?db () @ [ "-f"; script ]

let run_script ~connection ?db script =
  Cmd.run_cmd_exn "." psql (script_args ~connection ?db script @ [ "-a" ])

(** Like [run_script], but stops at the first failing statement and returns
    the failure instead of raising. *)
let run_script_or_error ~connection ?db script =
  Cmd.run_cmd_or_error "." psql
    (script_args ~connection ?db script @ [ "-v"; "ON_ERROR_STOP=1"; "-q" ])
  >>| Result.ignore_m

(** [db] as an SQL identifier: exact case, any character. *)
let quote_ident db =
  "\"" ^ String.substr_replace_all db ~pattern:"\"" ~with_:"\"\"" ^ "\""

let create_empty_db ~connection ~db =
  run_command ~connection (sprintf "CREATE DATABASE %s;" (quote_ident db))

let drop_db_if_exists ~connection ~db =
  run_command ~connection
    (sprintf "DROP DATABASE IF EXISTS %s;" (quote_ident db))

(** A database name no other test process makes. *)
let random_db_name ~prefix =
  sprintf "%s_%d_%06d" prefix
    (Core_unix.getpid () |> Pid.to_int)
    (Random.int 1_000_000)

let create_empty_random_db ~connection ~prefix =
  let open Deferred.Let_syntax in
  let db = random_db_name ~prefix in
  let%bind _ = create_empty_db ~connection ~db in
  Deferred.return db

let create_mina_db ~connection ~db =
  let open Deferred.Let_syntax in
  let%bind _ = create_empty_db ~connection ~db in
  let%bind create_script = create_db_script () in
  run_script ~connection ~db create_script >>| ignore

let create_random_mina_db ~connection ~prefix =
  let open Deferred.Let_syntax in
  let%bind db = create_empty_random_db ~connection ~prefix in
  let%bind create_script = create_db_script () in
  let%bind _ = run_script ~connection ~db create_script in
  Deferred.return db
