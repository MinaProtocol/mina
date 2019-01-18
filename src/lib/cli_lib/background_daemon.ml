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
        Print.printf !"Error: daemon not running. See `coda daemon`\n" ;
        go Abort
    | Run_client -> f port arg
    | Abort -> Deferred.unit
  in
  go Start

let init ~f arg_flag =
  let open Command.Param.Applicative_infix in
  Command.Param.return (fun port arg () -> run ~f port arg)
  <*> Flag.port <*> arg_flag
