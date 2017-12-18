open Core
open Async

type peer_stream = Peer.Event.t Pipe.Reader.t

module type Swim_intf = sig
  val connect
    : initial_peers:Peer.t list
    -> peer_stream Deferred.t (* TODO: Deferred? *)
end

module type Gossip_net_intf =
  functor
    (Message : sig type t [@@deriving bin_io] end) ->
  sig
    type t

    module Params : sig
      type t =
        { timeout           : Time.Span.t
        ; initial_peers     : Peer.t list
        ; target_peer_count : int
        }
    end

    val create
      :  peer_stream
      -> Params.t
      -> t Deferred.t

    val received : t -> Message.t Pipe.Reader.t

    val broadcast : t -> Message.t Pipe.Writer.t

    val new_peers : t -> Peer.t Pipe.Reader.t

    val query_random_peers
      : t
      -> int
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t list Deferred.t

    val add_handler
      : t
      -> ('q, 'r) Rpc.Rpc.t
      -> ('q -> 'r Or_error.t Deferred.t)
      -> unit

    val query_peer
      : t
      -> Peer.t
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t Deferred.t
  end

module type Miner_intf = sig
  val mine
    :  [ `Change_head of Block.t ] Pipe.Reader.t
    -> Block.t Pipe.Reader.t Deferred.t
end

module Rpcs = struct
  module Get_strongest_block = struct
    type query = unit [@@deriving bin_io]
    type response = Block.t [@@deriving bin_io]

    (* TODO: Remember the right way to version things *)
    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_strongest_block" ~version:0
        ~bin_query ~bin_response
  end
end

module type Blockchain_intf = sig
  module Update : sig
    type t =
      | New_block of Block.t
  end

  module Chain_state : sig
    type t

    val create
      :  strongest_block:Block.t Pipe.Writer.t
      -> updates:Update.t Pipe.Reader.t
      -> t
  end
end

let filter_map_unordered
      (t : 'a Pipe.Reader.t)
      ~(f : 'a -> 'b option Deferred.t)
  : 'b Pipe.Reader.t
  =
  let reader, writer = Pipe.create () in
  (* TODO: Is this bad? *)
  don't_wait_for begin
    Pipe.iter_without_pushback t ~f:(fun x ->
      don't_wait_for begin
        match%map f x with
        | Some y -> Pipe.write_without_pushback writer y
        | None -> ()
      end)
  end;
  reader
;;

module Make
    (Swim : Swim_intf)
    (Gossip_net : Gossip_net_intf)
    (Miner : Miner_intf)
    (Blockchain : Blockchain_intf)
  =
struct
  module Message = struct
    type t =
      | New_strongest_block of Block.t
    [@@deriving bin_io]
  end

  module Gossip_net = Gossip_net(Message)

  let peer_strongest_blocks gossip_net
    : Blockchain.Update.t Pipe.Reader.t
    =
    let from_new_peers =
      (* TODO: Gossip net should actually re-export a pipe of
         just connects *)
      filter_map_unordered (Gossip_net.new_peers gossip_net) ~f:(fun peer ->
        Deferred.map ~f:(function
          | Ok b -> Some (Blockchain.Update.New_block b)
          | Error _ -> None)
          (Gossip_net.query_peer gossip_net peer
              Rpcs.Get_strongest_block.rpc ()))
    in
    let broadcasts =
      Pipe.filter_map (Gossip_net.received gossip_net)
        ~f:(function
          | New_strongest_block b -> Some (Blockchain.Update.New_block b))
    in
    Pipe.merge
      ~cmp:(fun _ _ -> 1)
      [ from_new_peers
      ; broadcasts
      ]
  ;;

  let main initial_peers should_mine =
    let open Let_syntax in
    let params : Gossip_net.Params.t =
      { timeout = Time.Span.of_sec 1.
      ; initial_peers
      ; target_peer_count = 8
      }
    in
    let%bind peer_stream = Swim.connect ~initial_peers in
    let%bind gossip_net = Gossip_net.create peer_stream params in
    (* Are peers bi-directional? *)
    let strongest_block_reader, strongest_block_writer = Pipe.create () in
    don't_wait_for begin
      Pipe.transfer ~f:(fun b -> New_strongest_block b)
        strongest_block_reader
        (Gossip_net.broadcast gossip_net);
    end;
    let%map mined_blocks =
      Miner.mine
        (Pipe.map strongest_block_reader
           ~f:(fun b -> `Change_head b))
    in
    Blockchain.Chain_state.create
      ~strongest_block:strongest_block_writer
      ~updates:(
        Pipe.merge ~cmp:(fun _ _ -> 1)
          [ peer_strongest_blocks gossip_net
          ; Pipe.map mined_blocks ~f:(fun b -> Blockchain.Update.New_block b)
          ])
  ;;
end
