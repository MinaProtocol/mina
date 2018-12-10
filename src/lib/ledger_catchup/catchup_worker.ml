open Core
open Async
open Coda_base

let dispatch rpc query peer =
  Tcp.with_connection (Tcp.Where_to_connect.of_host_and_port peer)
    ~timeout:(Time.Span.of_sec 1.) (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn -> return (Or_error.of_exn exn)
      | Ok conn -> Rpc.Rpc.dispatch rpc conn query )

module Make (Inputs : Inputs.S) = struct
  open Inputs

  let get_external_transitions ~frontier hash =
    let open Option.Let_syntax in
    let%map breadcrumb = Transition_frontier.find frontier hash in
    Transition_frontier.path_map
      ~f:Transition_frontier.Breadcrumb.transition_with_hash frontier
      breadcrumb

  module Worker_rpc = struct
    type query = State_hash.t [@@deriving bin_io]

    type response =
      (Inputs.External_transition.t, State_hash.t) With_hash.t list option
    [@@deriving bin_io]

    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Catchup_worker" ~version:0 ~bin_query ~bin_response
  end

  let setup_server ~frontier ~logger my_port =
    let implementations =
      [ Rpc.Rpc.implement Worker_rpc.rpc (fun () state_hash ->
            return @@ get_external_transitions ~frontier state_hash ) ]
    in
    let where_to_listen =
      Tcp.Where_to_listen.bind_to All_addresses (On_port my_port)
    in
    Tcp.Server.create where_to_listen
      ~on_handler_error:
        (`Call
          (fun _ exn -> Logger.error logger "%s" (Exn.to_string_mach exn)))
      (fun _ reader writer ->
        Rpc.Connection.server_with_close reader writer
          ~implementations:
            (Rpc.Implementations.create_exn ~implementations
               ~on_unknown_rpc:`Raise)
          ~on_handshake_error:
            (`Call
              (fun exn ->
                Logger.error logger "%s" (Exn.to_string_mach exn) ;
                Deferred.unit ))
          ~connection_state:(fun _ -> ()) )
end
