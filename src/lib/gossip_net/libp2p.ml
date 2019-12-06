[%%import
"../../config.mlh"]

open Core
open Async
open Network_peer
open O1trace
open Pipe_lib
open Coda_base.Rpc_intf

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module Get_chain_id = struct
  module Master = struct
    let name = "get_chain_id"

    module T = struct
      (* "master" types, do not change *)
      type query = unit

      type response = string
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  module M = Versioned_rpc.Both_convert.Plain.Make (Master)
  include M

  include Perf_histograms.Rpc.Plain.Extend (struct
    include M
    include Master
  end)

  module V1 = struct
    module T = struct
      type query = unit [@@deriving bin_io, version {rpc}]

      type response = string [@@deriving bin_io, version {rpc}]

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model = Fn.id

      let caller_model_of_response = Fn.id
    end

    module T' =
      Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
          include M
          include Master
        end)
        (T)

    include T'
    include Register (T')
  end
end

module Connection_with_state = struct
  type t = Banned | Allowed of Rpc.Connection.t Ivar.t

  let value_map ~when_allowed ~when_banned t =
    match t with Allowed c -> when_allowed c | _ -> when_banned
end

module Config = struct
  type t =
    { timeout: Time.Span.t
    ; initial_peers: Coda_net2.Multiaddr.t list
    ; addrs_and_ports: Node_addrs_and_ports.t
    ; conf_dir: string
    ; chain_id: string
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; keypair: Coda_net2.Keypair.t option }
  [@@deriving make]
end

module type S = sig
  include Intf.Gossip_net_intf

  val create : Config.t -> Rpc_intf.rpc_handler list -> t Deferred.t
end

let rpc_transport_proto = "coda/rpcs/0.0.1"

module Make (Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf = struct
  open Rpc_intf

  module T = struct
    type t =
      { config: Config.t
      ; net2: Coda_net2.net
      ; first_peer_ivar: unit Ivar.t
      ; high_connectivity_ivar: unit Ivar.t
      ; ban_reader: Intf.ban_notification Linear_pipe.Reader.t
      ; subscription: Message.msg Coda_net2.Pubsub.Subscription.t }

    let create_libp2p (config : Config.t) first_peer_ivar
        high_connectivity_ivar =
      let fail m =
        failwithf "Failed to connect to libp2p_helper process: %s" m ()
      in
      match%bind
        Monitor.try_with (fun () ->
            trace "coda_net2" (fun () ->
                Coda_net2.create ~logger:config.logger
                  ~conf_dir:(config.conf_dir ^/ "coda_net2") ) )
      with
      | Ok (Ok net2) -> (
          let open Coda_net2 in
          (* Make an ephemeral keypair for this session TODO: persist in the config dir *)
          let%bind me =
            match config.keypair with
            | Some kp ->
                return kp
            | None ->
                Keypair.random net2
          in
          let peer_id = Keypair.to_peer_id me |> Peer.Id.to_string in
          ( match config.addrs_and_ports.peer with
          | Some _ ->
              ()
          | None ->
              config.addrs_and_ports.peer
              <- Some
                   (Peer.create config.addrs_and_ports.bind_ip
                      ~libp2p_port:config.addrs_and_ports.libp2p_port ~peer_id)
          ) ;
          Logger.info config.logger "libp2p peer ID this session is $peer_id"
            ~location:__LOC__ ~module_:__MODULE__
            ~metadata:[("peer_id", `String peer_id)] ;
          let ctr = ref 0 in
          let initializing_libp2p_result : unit Deferred.Or_error.t =
            let open Deferred.Or_error.Let_syntax in
            let%bind () =
              configure net2 ~me ~maddrs:[]
                ~external_maddr:
                  (Multiaddr.of_string
                     (sprintf "/ip4/%s/tcp/%d"
                        (Unix.Inet_addr.to_string
                           config.addrs_and_ports.external_ip)
                        (Option.value_exn config.addrs_and_ports.peer)
                          .libp2p_port))
                ~network_id:config.chain_id
                ~on_new_peer:(fun _ ->
                  Ivar.fill_if_empty first_peer_ivar () ;
                  if !ctr < 4 then incr ctr
                  else Ivar.fill_if_empty high_connectivity_ivar () )
            in
            let%map _ =
              listen_on net2
                (Multiaddr.of_string
                   (sprintf "/ip4/%s/tcp/%d"
                      ( config.addrs_and_ports.bind_ip
                      |> Unix.Inet_addr.to_string )
                      (Option.value_exn config.addrs_and_ports.peer)
                        .libp2p_port))
            in
            Deferred.ignore
              (Deferred.bind
                 ~f:(fun _ -> Coda_net2.begin_advertising net2)
                 (* TODO: timeouts here in addition to the libp2p side? *)
                 (Deferred.all
                    (List.map ~f:(Coda_net2.add_peer net2) config.initial_peers)))
            |> don't_wait_for ;
            ()
          in
          match%map initializing_libp2p_result with
          | Ok () ->
              net2
          | Error e ->
              fail (Error.to_string_hum e) )
      | Ok (Error e) ->
          fail (Error.to_string_hum e)
      | Error e ->
          fail (Exn.to_string e)

    let create config _rpc_handlers =
      let first_peer_ivar = Ivar.create () in
      let high_connectivity_ivar = Ivar.create () in
      let%bind net2 =
        create_libp2p config first_peer_ivar high_connectivity_ivar
      in
      let%map subscription =
        Coda_net2.Pubsub.subscribe_encode net2
          "coda/consensus-messages/0.0.1"
          (* FIXME: instead of doing validation here we put the message into a
           queue for later potential broadcast. It will still be broadcast
           despite failing validation, validation is only for automatic forwarding.
           Instead, we should probably do "initial validation" up front here,
           and turn should_forward_message into a filter_map instead of just a filter. *)
          ~should_forward_message:(fun ~sender:_ ~data:_ ->
            Deferred.return false )
          ~bin_prot:Message.V1.T.bin_msg ~on_decode_failure:`Ignore
        >>| Or_error.ok_exn
      in
      let ban_reader, ban_writer = Linear_pipe.create () in
      don't_wait_for
        (let%map () =
           Strict_pipe.Reader.iter (Trust_system.ban_pipe config.trust_system)
             ~f:(fun (addr, expiration) ->
               don't_wait_for
                 ( after Time.(diff expiration (now ()))
                 >>= fun () -> Coda_net2.unban_ip net2 addr |> Deferred.ignore
                 ) ;
               Coda_net2.ban_ip net2 addr |> Deferred.ignore )
         in
         Linear_pipe.close ban_writer) ;
      { config
      ; net2
      ; first_peer_ivar
      ; high_connectivity_ivar
      ; subscription
      ; ban_reader }

    let peers t = Coda_net2.peers t.net2

    let initial_peers t = t.config.initial_peers

    (* OPTIMIZATION: use fast n choose k implementation - see python or old flow code *)
    let random_sublist xs n = List.take (List.permute xs) n

    let random_peers t n =
      let%map peers = peers t in
      random_sublist peers n

    let random_peers_except t n ~except =
      let%map peers = peers t in
      random_sublist
        Hash_set.(diff (Peer.Hash_set.of_list peers) except |> to_list)
        n

    let try_call_rpc_with_dispatch : type r q.
           t
        -> Unix.Inet_addr.t
        -> string Pipe.Reader.t
        -> string Pipe.Writer.t
        -> (r, q) dispatch
        -> r
        -> q Deferred.Or_error.t =
     fun t addr rd wr dispatch query ->
      let call () =
        Monitor.try_with (fun () ->
            Async_rpc_kernel.Rpc.Connection.with_close
              ~connection_state:(fun _ -> ())
              ~dispatch_queries:(fun conn ->
                Versioned_rpc.Connection_with_menu.create conn
                >>=? fun conn' -> dispatch conn' query )
              Async_rpc_kernel.Pipe_transport.(create Kind.string rd wr)
              ~on_handshake_error:
                (`Call
                  (fun exn ->
                    let%map () =
                      Trust_system.(
                        record t.config.trust_system t.config.logger addr
                          Actions.
                            ( Outgoing_connection_error
                            , Some
                                ( "Handshake error: $exn"
                                , [("exn", `String (Exn.to_string exn))] ) ))
                    in
                    Or_error.error_string "handshake error" )) )
        >>= function
        | Ok (Ok result) ->
            (* call succeeded, result is valid *)
            Deferred.return (Ok result)
        | Ok (Error err) -> (
            (* call succeeded, result is an error *)
            Logger.error t.config.logger ~module_:__MODULE__ ~location:__LOC__
              "RPC call error: $error, same error in machine format: \
               $machine_error"
              ~metadata:
                [ ("error", `String (Error.to_string_hum err))
                ; ("machine_error", `String (Error.to_string_mach err)) ] ;
            match (Error.to_exn err, Error.sexp_of_t err) with
            | ( _
              , Sexp.List
                  [ Sexp.List
                      [ Sexp.Atom "rpc_error"
                      ; Sexp.List [Sexp.Atom "Connection_closed"; _] ]
                  ; _connection_description
                  ; _rpc_tag
                  ; _rpc_version ] ) ->
                let%map () =
                  Trust_system.(
                    record t.config.trust_system t.config.logger addr
                      Actions.
                        ( Outgoing_connection_error
                        , Some ("Closed connection", []) ))
                in
                Error err
            | _ ->
                let%map () =
                  Trust_system.(
                    record t.config.trust_system t.config.logger addr
                      Actions.
                        ( Violated_protocol
                        , Some
                            ( "RPC call failed, reason: $exn"
                            , [("exn", `String (Error.to_string_hum err))] ) ))
                in
                Error err )
        | Error monitor_exn -> (
            (* call itself failed *)
            (* TODO: learn what other exceptions are raised here *)
            let exn = Monitor.extract_exn monitor_exn in
            match exn with
            | _ ->
                Logger.error t.config.logger ~module_:__MODULE__
                  ~location:__LOC__ "RPC call raised an exception: $exn"
                  ~metadata:[("exn", `String (Exn.to_string exn))] ;
                Deferred.return (Or_error.of_exn exn) )
      in
      call ()

    let try_call_rpc : type q r.
           t
        -> Unix.Inet_addr.t
        -> _
        -> _
        -> (q, r) rpc
        -> q
        -> r Deferred.Or_error.t =
     fun t peer rd wr rpc query ->
      let (module Impl) = implementation_of_rpc rpc in
      try_call_rpc_with_dispatch t peer rd wr Impl.dispatch_multi query

    let query_peer t (peer : Peer.Id.t) rpc rpc_input =
      match%bind
        Coda_net2.open_stream t.net2 ~protocol:rpc_transport_proto peer
      with
      | Ok stream ->
          let rd, wr = Coda_net2.Stream.pipes stream in
          let peer = Coda_net2.Stream.remote_peer stream in
          try_call_rpc t peer.host rd wr rpc rpc_input
          >>| fun data ->
          Connected (Envelope.Incoming.wrap_peer ~data ~sender:peer)
      | Error e ->
          return (Failed_to_connect e)

    let query_random_peers t n rpc query =
      let%map peers = random_peers t n in
      Logger.trace t.config.logger ~module_:__MODULE__ ~location:__LOC__
        !"Querying random peers: %s"
        (Peer.pretty_list peers) ;
      List.map peers ~f:(fun peer -> query_peer t peer.peer_id rpc query)

    let broadcast t msg =
      don't_wait_for (Coda_net2.Pubsub.Subscription.publish t.subscription msg)

    let on_first_connect t ~f = Deferred.map (Ivar.read t.first_peer_ivar) ~f

    let on_first_high_connectivity t ~f =
      Deferred.map (Ivar.read t.high_connectivity_ivar) ~f

    let received_message_reader t =
      Coda_net2.Pubsub.Subscription.message_pipe t.subscription

    let ban_notification_reader t = t.ban_reader

    let ip_for_peer t peer_id =
      Coda_net2.lookup_peerid t.net2 peer_id
      >>| function Ok p -> Some p | Error _ -> None

    let net2 t = Some t.net2
  end

  include T
end
