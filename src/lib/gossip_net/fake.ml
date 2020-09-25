open Async_kernel
open Core
open Pipe_lib
open Network_peer

(* TODO: Implement RPC version translations (documented in Async_rpc_kernel).
 * This code currently only supports the latest version of RPCs. *)

module type S = sig
  include Intf.Gossip_net_intf

  type network

  val create_network : Peer.t list -> network

  val create_instance :
    network -> Peer.t -> Rpc_intf.rpc_handler list -> t Deferred.t
end

module Make (Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf = struct
  open Intf
  open Rpc_intf

  module Network = struct
    type rpc_hook =
      { hook:
          'q 'r.    Peer.Id.t -> ('q, 'r) rpc -> 'q
          -> 'r Coda_base.Rpc_intf.rpc_response Deferred.t }

    type network_interface =
      { broadcast_message_writer:
          ( Message.msg Envelope.Incoming.t * (bool -> unit)
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; rpc_hook: rpc_hook }

    type node = {peer: Peer.t; mutable interface: network_interface option}

    type t = {nodes: (Peer.Id.t, node list) Hashtbl.t}

    let create peers =
      let nodes = Hashtbl.create (module Peer.Id) in
      List.iter peers ~f:(fun peer ->
          Hashtbl.add_multi nodes ~key:peer.Peer.peer_id
            ~data:{peer; interface= None} ) ;
      {nodes}

    let get_initial_peers {nodes} local_ip =
      Hashtbl.data nodes |> List.concat
      |> List.filter_map ~f:(fun node ->
             if Unix.Inet_addr.equal node.peer.host local_ip then None
             else Some node.peer )

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
      Option.value_exn peer.interface
        ~error:
          (Error.of_string "cannot call rpc on peer which was never registered")

    let broadcast t ~sender msg =
      Hashtbl.iter t.nodes ~f:(fun nodes ->
          List.iter nodes ~f:(fun node ->
              if not (Peer.equal node.peer sender) then
                let intf = get_interface node in
                let msg =
                  Envelope.(
                    Incoming.wrap ~data:msg ~sender:(Sender.Remote sender))
                in
                Strict_pipe.Writer.write intf.broadcast_message_writer
                  (msg, Fn.const ()) ) )

    let call_rpc : type q r.
           t
        -> _
        -> sender_id:Peer.Id.t
        -> responder_id:Peer.Id.t
        -> (q, r) rpc
        -> q
        -> r Coda_base.Rpc_intf.rpc_response Deferred.t =
     fun t peer_table ~sender_id ~responder_id rpc query ->
      let responder =
        Option.value_exn
          (Hashtbl.find peer_table responder_id)
          ~error:
            (Error.createf "failed to find peer %s in peer_table" responder_id)
      in
      let intf = get_interface (lookup_node t responder) in
      intf.rpc_hook.hook sender_id rpc query
  end

  module Instance = struct
    type t =
      { network: Network.t
      ; me: Peer.t
      ; rpc_handlers: rpc_handler list
      ; peer_table: (Peer.Id.t, Peer.t) Hashtbl.t
      ; initial_peers: Peer.t list
      ; connection_gating: Coda_net2.connection_gating ref
      ; received_message_reader:
          (Message.msg Envelope.Incoming.t * (bool -> unit))
          Strict_pipe.Reader.t
      ; received_message_writer:
          ( Message.msg Envelope.Incoming.t * (bool -> unit)
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; ban_notification_reader: ban_notification Linear_pipe.Reader.t
      ; ban_notification_writer: ban_notification Linear_pipe.Writer.t }

    let rpc_hook t rpc_handlers =
      let hook : type q r.
             Peer.Id.t
          -> (q, r) rpc
          -> q
          -> r Coda_base.Rpc_intf.rpc_response Deferred.t =
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
                  f sender ~version:latest_version query ) )
        with
        | None ->
            failwith "fake gossip net error: rpc not implemented"
        | Some deferred ->
            let%map response = deferred in
            Coda_base.Rpc_intf.Connected
              (Envelope.Incoming.wrap_peer ~data:(Ok response) ~sender)
      in
      Network.{hook}

    let create network me rpc_handlers =
      let initial_peers = Network.get_initial_peers network me.Peer.host in
      let peer_table = Hashtbl.create (module Peer.Id) in
      List.iter initial_peers ~f:(fun peer ->
          Hashtbl.add_exn peer_table ~key:peer.peer_id ~data:peer ) ;
      let received_message_reader, received_message_writer =
        Strict_pipe.(create (Buffered (`Capacity 5, `Overflow Crash)))
      in
      let ban_notification_reader, ban_notification_writer =
        Linear_pipe.create ()
      in
      let t =
        { network
        ; me
        ; rpc_handlers
        ; peer_table
        ; initial_peers
        ; connection_gating=
            ref Coda_net2.{banned_peers= []; trusted_peers= []; isolate= false}
        ; received_message_reader
        ; received_message_writer
        ; ban_notification_reader
        ; ban_notification_writer }
      in
      Network.(
        attach_interface network me
          { broadcast_message_writer= received_message_writer
          ; rpc_hook= rpc_hook t rpc_handlers }) ;
      t

    let peers {peer_table; _} = Hashtbl.data peer_table |> Deferred.return

    let initial_peers t =
      Hashtbl.data t.peer_table
      |> List.map
           ~f:
             (Fn.compose Coda_net2.Multiaddr.of_string Peer.to_multiaddr_string)

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

    let received_message_reader {received_message_reader; _} =
      received_message_reader

    let ban_notification_reader {ban_notification_reader; _} =
      ban_notification_reader

    let query_peer t peer rpc query =
      Network.call_rpc t.network t.peer_table ~sender_id:t.me.peer_id
        ~responder_id:peer rpc query

    let query_random_peers _ = failwith "TODO stub"

    let broadcast t msg = Network.broadcast t.network ~sender:t.me msg

    let ip_for_peer t peer_id =
      Deferred.return (Hashtbl.find t.peer_table peer_id)

    let connection_gating t = Deferred.return !(t.connection_gating)

    let set_connection_gating t config =
      t.connection_gating := config ;
      Deferred.unit
  end

  type network = Network.t

  include Instance

  let create_network = Network.create

  let create_instance network local_ip impls =
    Deferred.return (Instance.create network local_ip impls)
end
