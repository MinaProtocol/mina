open Async_kernel
open Core
open Pipe_lib
open Network_peer
open Peer

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
    type rpc_hook = {hook: 'q 'r. ('q, 'r) rpc -> 'q -> 'r Deferred.Or_error.t}

    type network_interface =
      { broadcast_message_writer:
          ( Message.msg Envelope.Incoming.t
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; rpc_hook: rpc_hook }

    type node = {peer: Peer.t; mutable interface: network_interface option}

    type t = {nodes: (Unix.Inet_addr.t, node list) Hashtbl.t}

    let create peers =
      let nodes = Hashtbl.create (module Unix.Inet_addr) in
      List.iter peers ~f:(fun peer ->
          Hashtbl.add_multi nodes ~key:peer.host ~data:{peer; interface= None}
      ) ;
      {nodes}

    let get_initial_peers {nodes} local_ip =
      Hashtbl.data nodes |> List.concat
      |> List.filter_map ~f:(fun node ->
             if Unix.Inet_addr.equal node.peer.host local_ip then None
             else Some node.peer )

    let lookup_node t peer =
      let error = Error.of_string "peer does not exist" in
      let nodes = Hashtbl.find t.nodes peer.host |> Option.value_exn ~error in
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
                    Incoming.wrap ~data:msg ~sender:(Sender.Remote sender.host))
                in
                Strict_pipe.Writer.write intf.broadcast_message_writer msg ) )

    let call_rpc : type q r.
        t -> Peer.t -> (q, r) rpc -> q -> r Deferred.Or_error.t =
     fun t peer rpc query ->
      let intf = get_interface (lookup_node t peer) in
      intf.rpc_hook.hook rpc query
  end

  module Instance = struct
    type t =
      { network: Network.t
      ; me: Peer.t
      ; rpc_handlers: rpc_handler list
      ; peer_table: (Unix.Inet_addr.t, Peer.t list) Hashtbl.t
      ; initial_peers: Host_and_port.t list
      ; received_message_reader:
          Message.msg Envelope.Incoming.t Strict_pipe.Reader.t
      ; received_message_writer:
          ( Message.msg Envelope.Incoming.t
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; ban_notification_reader: ban_notification Linear_pipe.Reader.t
      ; ban_notification_writer: ban_notification Linear_pipe.Writer.t }

    let rpc_hook me rpc_handlers =
      let hook : type q r. (q, r) rpc -> q -> r Deferred.Or_error.t =
       fun rpc query ->
        let (module Impl) = implementation_of_rpc rpc in
        let latest_version =
          (* this is assumed safe since there should always be at least one version *)
          Int.Set.max_elt (Impl.versions ()) |> Option.value_exn
        in
        match
          List.find_map rpc_handlers ~f:(fun handler ->
              match_handler handler rpc ~do_:(fun f ->
                  f
                    (Peer.to_communications_host_and_port me)
                    ~version:latest_version query ) )
        with
        | None ->
            failwith "fake gossip net error: rpc not implemented"
        | Some deferred ->
            let%map response = deferred in
            Ok response
      in
      Network.{hook}

    let create network me rpc_handlers =
      let initial_peers = Network.get_initial_peers network me.host in
      let initial_peer_hosts =
        List.map initial_peers ~f:Peer.to_communications_host_and_port
      in
      let peer_table = Hashtbl.create (module Unix.Inet_addr) in
      List.iter initial_peers ~f:(fun peer ->
          Hashtbl.add_multi peer_table ~key:peer.host ~data:peer ) ;
      let received_message_reader, received_message_writer =
        Strict_pipe.(create (Buffered (`Capacity 5, `Overflow Crash)))
      in
      let ban_notification_reader, ban_notification_writer =
        Linear_pipe.create ()
      in
      Network.(
        attach_interface network me
          { broadcast_message_writer= received_message_writer
          ; rpc_hook= rpc_hook me rpc_handlers }) ;
      { network
      ; me
      ; rpc_handlers
      ; peer_table
      ; initial_peers= initial_peer_hosts
      ; received_message_reader
      ; received_message_writer
      ; ban_notification_reader
      ; ban_notification_writer }

    let peers {peer_table; _} = List.concat (Hashtbl.data peer_table)

    let initial_peers {initial_peers; _} = initial_peers

    let peers_by_ip {peer_table; _} ip = Hashtbl.find_multi peer_table ip

    let random_peers t n = List.take (List.permute @@ peers t) n

    let random_peers_except t n ~except =
      let peers_without_exception =
        List.filter (peers t) ~f:(fun peer ->
            not (Base.Hash_set.mem except peer) )
      in
      List.take (List.permute peers_without_exception) n

    let on_first_connect _ ~f = Deferred.return (f ())

    let on_first_high_connectivity _ ~f:_ = Deferred.never ()

    let received_message_reader {received_message_reader; _} =
      received_message_reader

    let ban_notification_reader {ban_notification_reader; _} =
      ban_notification_reader

    let query_peer t peer rpc query = Network.call_rpc t.network peer rpc query

    let query_random_peers _ = failwith "TODO stub"

    let broadcast t msg = Network.broadcast t.network ~sender:t.me msg

    let broadcast_all _ = failwith "TODO stub"

    let net2 _ = None
  end

  type network = Network.t

  include Instance

  let create_network = Network.create

  let create_instance network local_ip impls =
    Deferred.return (Instance.create network local_ip impls)
end
