open Core
open Async

type state = Start | Run_client | Abort | No_daemon

let does_daemon_exist host_and_port =
  let open Deferred.Let_syntax in
  let%map result =
    Rpc.Connection.client (Tcp.Where_to_connect.of_host_and_port host_and_port)
  in
  Result.is_ok result

let run ~f (t : Host_and_port.t Flag.Types.with_name) arg =
  let rec go = function
    | Start ->
        let%bind has_daemon = does_daemon_exist t.value in
        if has_daemon then go Run_client else go No_daemon
    | No_daemon ->
        Print.printf
          !"Error: Unable to connect to Mina daemon.\n\
            - The daemon might not be running. See logs (in \
            `~/.mina-config/mina.log`) for details under the host:%s.\n\
           \  Run `mina daemon -help` to see how to start daemon.\n\
            - If you just started the daemon, wait a minute for the RPC server \
            to start.\n\
            - Alternatively, the daemon may not be running the RPC server on \
            %{sexp:Host_and_port.t}.\n\
           \  If so, add flag `-%s` with correct port when running this command.\n"
          (Host_and_port.host t.value)
          t.value t.name ;
        go Abort
    | Run_client ->
        f t.value arg
    | Abort ->
        exit 15
  in
  go Start

let rpc_init ~f arg_flag =
  let open Command.Param.Applicative_infix in
  Command.Param.return (fun port arg () -> run ~f port arg)
  <*> Flag.Host_and_port.Client.daemon <*> arg_flag

let graphql_init ~f arg_flag =
  let open Command.Param.Applicative_infix in
  Command.Param.return (fun rest_uri arg () -> f rest_uri arg)
  <*> Flag.Uri.Client.rest_graphql <*> arg_flag
