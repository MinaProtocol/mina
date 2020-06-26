open Core
open Async
open Cli_lib

let command =
  let open Command.Let_syntax in
  let%map_open log_json = Flag.Log.json
  and log_level = Flag.Log.level
  and server_port = Flag.Port.Archive.server
  and postgres = Flag.Uri.Archive.postgres in
  fun () ->
    let logger = Logger.create () in
    Stdout_log.setup log_json log_level ;
    Archive_lib.Processor.setup_server ~logger
      ~constraint_constants:Genesis_constants.Constraint_constants.compiled
      ~postgres_address:postgres.value
      ~server_port:
        (Option.value server_port.value ~default:server_port.default)

let () =
  Command.run
    (Command.async
       ~summary:"Run an archive process that can store all of the data of Coda"
       command)
