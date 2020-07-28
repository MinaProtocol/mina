(** An agent that pokes at Coda and peeks at Rosetta to see if things look alright *)

open Core_kernel
open Lib
open Async

let run ~logger ~rosetta_uri ~graphql_uri =
  let open Deferred.Result.Let_syntax in
  let%bind _res = Poke.disableStaking ~graphql_uri in
  let%map res = Peek.Network.list ~rosetta_uri in
  Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:[("res", res)] "Network list got $res" ;
  ()

let command =
  let open Command.Let_syntax in
  let%map_open rosetta_uri =
    flag "rosetta-uri" ~doc:"URI of Rosetta endpoint to connect to"
      Cli.required_uri
  and graphql_uri =
    flag "graphql-uri" ~doc:"URI of Coda GraphQL endpoint to connect to"
      Cli.required_uri
  and log_json =
    flag "log-json" ~doc:"Print log output as JSON (default: plain text)"
      no_arg
  and log_level =
    flag "log-level" ~doc:"Set log level (default: Info)" Cli.log_level
  in
  let open Deferred.Let_syntax in
  fun () ->
    let logger = Logger.create () in
    Cli.logger_setup log_json log_level ;
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Rosetta test-agent starting" ;
    match%bind run ~logger ~rosetta_uri ~graphql_uri with
    | Ok () ->
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__
          "Rosetta test-agent stopping successfully" ;
        return ()
    | Error e ->
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          "Rosetta test-agent stopping with a failure: %s" (Errors.show e) ;
        exit 1

let () =
  Command.run
    (Command.async ~summary:"Run agent to poke at Coda and peek at Rosetta"
       command)
