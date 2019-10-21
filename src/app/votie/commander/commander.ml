open Core_kernel
open Async

module Command_spec = struct
  type 's t =
    | T :
        { name: string
        ; param: 'q Command.Param.t
        ; bin_query: 'q Bin_prot.Type_class.t
        ; bin_response: 'r Bin_prot.Type_class.t
        ; on_response: 'r -> unit Deferred.t
        ; handle: state:'s -> 'q -> 'r Deferred.t }
        -> 's t

  let exitf fmt = ksprintf (fun s -> eprintf "%s\n" s ; exit 1) fmt

  let client_command ~daemon_port
      (T {param; bin_query; bin_response; on_response; name; handle= _}) =
    let rpc = Rpc.Rpc.create ~name ~version:0 ~bin_query ~bin_response in
    Command.async
      ~summary:(sprintf "Send %s command to daemon" name)
      Command.Let_syntax.(
        let%map query = param in
        fun () ->
          Tcp.with_connection
            (Tcp.Where_to_connect.of_host_and_port
               {port= daemon_port; host= "0.0.0.0"})
            ~timeout:(Time.Span.of_sec 10.)
            (fun _ r w ->
              let open Deferred.Let_syntax in
              match%bind
                Rpc.Connection.create r w ~connection_state:(fun _ -> ())
              with
              | Error exn ->
                  exitf
                    !"Error connecting to daemon on port %d: %s."
                    daemon_port (Exn.to_string exn)
              | Ok conn -> (
                  match%bind Rpc.Rpc.dispatch rpc conn query with
                  | Error e ->
                      exitf "Got error from daemon: %s"
                        (Core.Error.to_string_hum e)
                  | Ok resp ->
                      on_response resp ) ))

  let client_commands ~daemon_port commands =
    List.map commands ~f:(fun (T {name; _} as t) ->
        (name, client_command ~daemon_port t) )

  let client ~daemon_port ~summary commands =
    Command.group ~summary
      (List.map commands ~f:(fun (T {name; _} as t) ->
           (name, client_command ~daemon_port t) ))

  let create_daemon_server (type s) ~daemon_port ~(state : s) commands =
    let log_error = `Call (fun _ e -> eprintf "%s\n" (Exn.to_string e)) in
    let open Rpc in
    let implementations =
      Implementations.create_exn
        ~implementations:
          (List.map commands
             ~f:(fun (T {bin_query; bin_response; handle; name; _}) ->
               let rpc =
                 Rpc.create ~name ~version:0 ~bin_query ~bin_response
               in
               Rpc.implement rpc (fun () query -> handle ~state query) ))
        ~on_unknown_rpc:`Close_connection
    in
    let open Tcp in
    Server.create
      (Where_to_listen.bind_to Bind_to_address.Localhost
         (Bind_to_port.On_port daemon_port)) ~on_handler_error:log_error
      (fun _ reader writer ->
        Connection.server_with_close reader writer ~implementations
          ~connection_state:(fun _ -> ())
          ~on_handshake_error:
            (`Call
              (fun e ->
                eprintf "%s\n" (Exn.to_string e) ;
                Deferred.unit )) )
end
