open Async_kernel
open Core
open Pipe_lib
open Network_peer

(* TODO: Implement RPC version translations (documented in Async_rpc_kernel).
 * This code currently only supports the latest version of RPCs. *)

module type S = sig
  include Intf.Gossip_net_intf

  type sinks

  type network

  val create_network : Peer.t list -> network

  val create_instance :
    network -> Peer.t -> Rpc_intf.rpc_handler list -> sinks -> t Deferred.t
end

module Make
    (SinksImpl : Message.Sinks)
    (Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf with type sinks := SinksImpl.sinks = struct
  open Intf
  open Rpc_intf

  module Network = struct
    type rpc_hook =
      { hook :
          'q 'r.    Peer.Id.t -> ('q, 'r) rpc -> 'q
          -> 'r Mina_base.Rpc_intf.rpc_response Deferred.t
      }

    type network_interface = { sinks : SinksImpl.sinks; rpc_hook : rpc_hook }

    type node = { peer : Peer.t; mutable interface : network_interface option }

    type t = { nodes : (Peer.Id.t, node list) Hashtbl.t }

    let create peers =
      let nodes = Hashtbl.create (module Peer.Id) in
      List.iter peers ~f:(fun peer ->
          Hashtbl.add_multi nodes ~key:peer.Peer.peer_id
            ~data:{ peer; interface = None }) ;
      { nodes }

    let get_initial_peers { nodes } local_ip =
      Hashtbl.data nodes |> List.concat
      |> List.filter_map ~f:(fun node ->
             if Unix.Inet_addr.equal node.peer.host local_ip then None
             else Some node.peer)

    let lookup_node t peer =
      let error = Error.of_string "peer does not exist" in
      let nodes =
        Hashtbl.find t.nodes peer.Peer.peer_id |> Option.value_exn ~error
      in
      List.find nodes ~f:(fun node -> Peer.equal peer node.peer)
      |> Option.value_exn ~error

    let attach_interface t peer interface =
      let node = lookup_node t peer in
      node.interface <- Some interface

    let get_interface peer =
      match peer.interface with
      | Some x ->
          Ok x
      | None ->
          Or_error.error_string
            "cannot call rpc on peer which was never registered"

    let broadcast t ~sender msg send_f =
      Hashtbl.fold t.nodes ~init:Deferred.unit
        ~f:(fun ~key:_ ~data:nodes prev ->
          prev
          >>= fun () ->
          Deferred.List.iter ~how:`Sequential nodes ~f:(fun node ->
              if Peer.equal node.peer sender then Deferred.unit
              else
                Option.fold node.interface
                  ~f:(fun a intf ->
                    a
                    >>= fun () ->
                    let msg =
                      Envelope.(
                        Incoming.wrap ~data:msg ~sender:(Sender.Remote sender))
                    in
                    send_f intf.sinks
                      ( msg
                      , Mina_net2.Validation_callback.create_without_expiration
                          () ))
                  ~init:Deferred.unit))

    let call_rpc :
        type q r.
           t
        -> _
        -> sender_id:Peer.Id.t
        -> responder_id:Peer.Id.t
        -> (q, r) rpc
        -> q
        -> r Mina_base.Rpc_intf.rpc_response Deferred.t =
     fun t peer_table ~sender_id ~responder_id rpc query ->
      let responder =
        Option.value_exn
          (Hashtbl.find peer_table responder_id)
          ~error:
            (Error.createf "failed to find peer %s in peer_table" responder_id)
      in
      match get_interface (lookup_node t responder) with
      | Ok intf ->
          intf.rpc_hook.hook sender_id rpc query
      | Error e ->
          Deferred.return (Mina_base.Rpc_intf.Failed_to_connect e)
  end

  module Instance = struct
    type t =
      { network : Network.t
      ; me : Peer.t
      ; rpc_handlers : rpc_handler list
      ; peer_table : (Peer.Id.t, Peer.t) Hashtbl.t
      ; initial_peers : Peer.t list
      ; connection_gating : Mina_net2.connection_gating ref
      ; ban_notification_reader : ban_notification Linear_pipe.Reader.t
      ; ban_notification_writer : ban_notification Linear_pipe.Writer.t
      ; time_controller : Block_time.Controller.t
      }

    let rpc_hook t rpc_handlers =
      let hook :
          type q r.
             Peer.Id.t
          -> (q, r) rpc
          -> q
          -> r Mina_base.Rpc_intf.rpc_response Deferred.t =
       fun peer rpc query ->
        let (module Impl) = implementation_of_rpc rpc in
        let latest_version =
          (* this is assumed safe since there should always be at least one version *)
          Int.Set.max_elt (Impl.versions ())
          |> Option.value_exn ~error:(Error.of_string "no versions?")
        in
        let sender =
          Hashtbl.find t.peer_table peer
          |> Option.value_exn ~error:(Error.createf "cannot find peer %s" peer)
        in
        match
          List.find_map rpc_handlers ~f:(fun handler ->
              match_handler handler rpc ~do_:(fun f ->
                  f sender ~version:latest_version query))
        with
        | None ->
            failwith "fake gossip net error: rpc not implemented"
        | Some deferred ->
            let%map response = deferred in
            Mina_base.Rpc_intf.Connected
              (Envelope.Incoming.wrap_peer ~data:(Ok response) ~sender)
      in
      Network.{ hook }

    let create network me rpc_handlers sinks =
      let initial_peers = Network.get_initial_peers network me.Peer.host in
      let peer_table = Hashtbl.create (module Peer.Id) in
      List.iter initial_peers ~f:(fun peer ->
          Hashtbl.add_exn peer_table ~key:peer.peer_id ~data:peer) ;
      let ban_notification_reader, ban_notification_writer =
        Linear_pipe.create ()
      in
      let time_controller =
        Block_time.Controller.create
        @@ Block_time.Controller.basic ~logger:(Logger.create ())
      in
      let t =
        { network
        ; me
        ; rpc_handlers
        ; peer_table
        ; initial_peers
        ; connection_gating =
            ref
              Mina_net2.
                { banned_peers = []; trusted_peers = []; isolate = false }
        ; ban_notification_reader
        ; ban_notification_writer
        ; time_controller
        }
      in
      Network.(
        attach_interface network me
          { sinks; rpc_hook = rpc_hook t rpc_handlers }) ;
      t

    let peers { peer_table; _ } = Hashtbl.data peer_table |> Deferred.return

    let bandwidth_info _ =
      Deferred.Or_error.fail
        (Error.of_string "fake bandwidth info: Not implemented")

    let set_node_status _ _ = Deferred.Or_error.ok_unit

    let get_peer_node_status _ _ =
      Deferred.Or_error.error_string "fake node status: Not implemented"

    let add_peer _ (_p : Peer.t) ~is_seed:_ = Deferred.return (Ok ())

    let initial_peers t =
      Hashtbl.data t.peer_table
      |> List.map
           ~f:
             (Fn.compose Mina_net2.Multiaddr.of_string Peer.to_multiaddr_string)

    let random_peers t n =
      let%map peers = peers t in
      List.take (List.permute @@ peers) n

    let random_peers_except t n ~except =
      let%map peers = peers t in
      let peers_without_exception =
        List.filter peers ~f:(fun peer -> not (Base.Hash_set.mem except peer))
      in
      List.take (List.permute peers_without_exception) n

    let on_first_connect _ ~f = Deferred.return (f ())

    let on_first_high_connectivity _ ~f:_ = Deferred.never ()

    let ban_notification_reader { ban_notification_reader; _ } =
      ban_notification_reader

    let query_peer ?heartbeat_timeout:_ ?timeout:_ t peer rpc query =
      Network.call_rpc t.network t.peer_table ~sender_id:t.me.peer_id
        ~responder_id:peer rpc query

    let query_peer' ?how ?heartbeat_timeout ?timeout t peer rpc qs =
      let%map rs =
        Deferred.List.map ?how qs
          ~f:(query_peer ?timeout ?heartbeat_timeout t peer rpc)
      in
      with_return (fun { return } ->
          let data =
            List.map rs ~f:(function
              | Connected x ->
                  x.data
              | Failed_to_connect e ->
                  return (Mina_base.Rpc_intf.Failed_to_connect e))
            |> Or_error.all
          in
          let sender =
            Option.value_exn
              (Hashtbl.find t.peer_table peer)
              ~error:(Error.createf "failed to find peer %s in peer_table" peer)
          in
          Connected (Envelope.Incoming.wrap_peer ~data ~sender))

    let query_random_peers _ = failwith "TODO stub"

    let broadcast_state t state =
      Network.broadcast t.network ~sender:t.me state (fun sinks (env, vc) ->
          let time = Block_time.now t.time_controller in
          SinksImpl.Block_sink.push sinks.sink_block (env, time, vc))

    let broadcast_snark_pool_diff t diff =
      Network.broadcast t.network ~sender:t.me diff (fun sinks ->
          SinksImpl.Snark_sink.push sinks.sink_snark_work)

    let broadcast_transaction_pool_diff t diff =
      Network.broadcast t.network ~sender:t.me diff (fun sinks ->
          SinksImpl.Tx_sink.push sinks.sink_tx)

    let connection_gating t = Deferred.return !(t.connection_gating)

    let set_connection_gating t config =
      t.connection_gating := config ;
      Deferred.return config
  end

  type network = Network.t

  include Instance

  let restart_helper (_ : t) = ()

  let create_network = Network.create

  let create_instance network local_ip impls sinks =
    Deferred.return (Instance.create network local_ip impls sinks)
end
