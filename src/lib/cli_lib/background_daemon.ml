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
          !"Error: Unable to connect to Coda daemon.\n\
            - The daemon might not be running. See logs (in \
            `~/.coda-config/coda.log`) for details.\n\
           \  Run `coda daemon -help` to see how to start daemon.\n\
            - If you just started the daemon, wait a minute for the RPC \
            server to start.\n\
            - Alternatively, the daemon may not be running the RPC server on \
            port %d.\n\
           \  If so, add flag `-daemon-port` with correct port when running \
            this command.\n"
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
