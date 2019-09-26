open Core
open Async

type state = Start | Run_client | Abort | No_daemon

let does_daemon_exist port =
  let open Deferred.Let_syntax in
  let%map result =
    Rpc.Connection.client
      (Tcp.Where_to_connect.of_host_and_port (Port.of_local port))
  in
  Result.is_ok result

let run ~f port arg =
  let port = Option.value port ~default:Port.default_client in
  let rec go = function
    | Start ->
        let%bind has_daemon = does_daemon_exist port in
        if has_daemon then go Run_client else go No_daemon
    | No_daemon ->
        Print.printf
          !"Error: Daemon not running on port %d. See `coda daemon -help`\n"
          port ;
        go Abort
    | Run_client ->
        f port arg
    | Abort ->
        exit 15
  in
  go Start

let rpc_init ~f arg_flag =
  let open Command.Param.Applicative_infix in
  Command.Param.return (fun port arg () -> run ~f port arg)
  <*> Flag.port <*> arg_flag

let graphql_init ~f arg_flag =
  let open Command.Param.Applicative_infix in
  Command.Param.return (fun rest_port arg () ->
      let port = Option.value rest_port ~default:Port.default_rest in
      let (module Graphql_client : Graphql_client_lib.S) =
        ( module struct
          include Graphql_client_lib.Make (struct
            let address = "graphql"

            let port = port

            let headers = String.Map.empty
          end)
        end )
      in
      f (module Graphql_client : Graphql_client_lib.S) arg )
  <*> Flag.rest_port <*> arg_flag
