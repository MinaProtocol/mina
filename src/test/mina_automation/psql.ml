(**
Module for psql tool automation. One can use it to create database schema
*)

open Integration_test_lib
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

let create_credential_arg ~connection =
  let value_or_empty arg item =
    match item with Some item -> [ arg; item ] | None -> []
  in

  let credentials =
    match connection with
    | Conn_str conn_str ->
        let uri = conn_str |> Uri.of_string in
        let password = uri |> Uri.password |> Option.value_exn in
        let user = uri |> Uri.user in
        let host = uri |> Uri.host in
        let port = uri |> Uri.port in
        let db = uri |> Uri.path in
        let db = if String.is_empty db then None else Some db in
        { Credentials.password; user; host; db; port }
    | Credentials credentials ->
        credentials
  in

  Unix.putenv ~key:"PGPASSWORD" ~data:credentials.password ;
  value_or_empty "-U" credentials.user
  @ value_or_empty "-p" (Option.map ~f:string_of_int credentials.port)
  @ value_or_empty "-h" credentials.host
  @ value_or_empty "-U" credentials.user
  @ value_or_empty "-d" credentials.db

let run_command ~connection command =
  let creds = create_credential_arg ~connection in
  Util.run_cmd_exn "." psql (creds @ [ "-c"; command ])

let run_script ~connection ~db script =
  let creds = create_credential_arg ~connection in
  Util.run_cmd_exn "." psql (creds @ [ "-d"; db; "-a"; "-f"; script ])

let create_empty_db ~connection ~db =
  run_command ~connection (sprintf "CREATE DATABASE %s;" db)

let create_empty_random_db ~connection ~prefix =
  let open Deferred.Let_syntax in
  let db = sprintf "%s_%d" prefix (Random.int 10000 + 1000) in
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
