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

let init ?(rest = false) ~f arg_flag =
  let open Command.Param.Applicative_infix in
  if rest then
    Command.Param.return (fun rest_port arg () ->
        let port = Option.value rest_port ~default:Port.default_rest in
        f port arg )
    <*> Flag.rest_port <*> arg_flag
  else
    Command.Param.return (fun port arg () -> run ~f port arg)
    <*> Flag.port <*> arg_flag
