open Core
open Async
open Cli_lib

let command =
  let open Command.Let_syntax in
  let%map_open log_json = Flag.Log.json and log_level = Flag.Log.level in
  fun () ->
    let logger = Logger.create () in
    Stdout_log.setup log_json log_level ;
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Failed to connect to postgresql database" ;
    Deferred.unit

let () =
  Command.run
    (Command.async
       ~summary:"Run an archive process that can store all of the data of Coda"
       command)
