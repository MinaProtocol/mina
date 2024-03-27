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

type connection = Conn_str of string | Credentials of Credentials.t

let psql = "psql"

let create_credential_arg ~connection =
  match connection with
  | Conn_str conn_str ->
      [ conn_str ]
  | Credentials { user; password; host; port; db } ->
      Unix.putenv ~key:"PGPASSWORD" ~data:password ;
      let value_or_empty arg item =
        match item with Some item -> [ arg; item ] | None -> []
      in

      value_or_empty "-U" user
      @ value_or_empty "-p" (Option.map ~f:string_of_int port)
      @ value_or_empty "-h" host @ value_or_empty "-U" user
      @ value_or_empty "-d" db

let run_command ~connection command =
  let creds = create_credential_arg ~connection in
  Util.run_cmd_exn "." psql (creds @ [ "-c"; command ])

let run_script ~connection ~db script =
  let creds = create_credential_arg ~connection in
  Util.run_cmd_exn "." psql (creds @ [ "-d"; db; "-a"; "-f"; script ])

let create_new_mina_archive ~connection ~db ~script =
  let open Deferred.Let_syntax in
  let%bind _ = run_command ~connection (sprintf "CREATE DATABASE %s;" db) in
  let%bind _ = run_script ~connection ~db script in
  Deferred.unit

let create_new_random_archive ~connection ~prefix ~script =
  let open Deferred.Let_syntax in
  let db = sprintf "%s_%d" prefix (Random.int 10000 + 1000) in
  let%bind _ = create_new_mina_archive ~connection ~db ~script in
  Deferred.return db

let create_mainnet_db ~connection ~name ~working_dir =
  let open Deferred.Let_syntax in
  let create_schema_script =
    Filename.concat working_dir (sprintf "%s.sql" name)
  in
  let%bind _ = run_command ~connection (sprintf "CREATE DATABASE %s;" name) in
  let%bind _ =
    Util.run_cmd_exn "." "wget"
      [ "-c"
      ; "https://raw.githubusercontent.com/MinaProtocol/mina/compatible/src/app/archive/create_schema.sql"
      ; "-O"
      ; create_schema_script
      ]
  in
  let%bind _ = run_script ~connection ~db:name create_schema_script in
  Deferred.return name

let create_random_mainnet_db ~connection ~prefix ~working_dir =
  let open Deferred.Let_syntax in
  let name = sprintf "%s_%d" prefix (Random.int 1000000 + 1000) in
  let create_schema_script =
    Filename.concat working_dir (sprintf "%s.sql" name)
  in
  let%bind _ = run_command ~connection (sprintf "CREATE DATABASE %s;" name) in
  let%bind _ =
    Util.run_cmd_exn "." "wget"
      [ "-c"
      ; "https://raw.githubusercontent.com/MinaProtocol/mina/compatible/src/app/archive/create_schema.sql"
      ; "-O"
      ; create_schema_script
      ]
  in
  let%bind _ = run_script ~connection ~db:name create_schema_script in
  Deferred.return name
