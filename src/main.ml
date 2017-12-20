open Core
open Async

module Rpcs = struct
  module Get_strongest_block = struct
    type query = unit [@@deriving bin_io]
    type response = Block.t [@@deriving bin_io]

    (* TODO: Use stable types. *)
    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_strongest_block" ~version:0
        ~bin_query ~bin_response
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

module Message = struct
  type t =
    | New_strongest_block of Block.t
  [@@deriving bin_io]
end

module Make
    (Swim       : Swim.S)
    (Gossip_net : Gossip_net.S)
    (Miner      : Miner.S)
    (Storage    : Storage.S)
  =
struct
  module Gossip_net = Gossip_net(Message)

  let peer_strongest_blocks gossip_net
    : Blockchain.Update.t Pipe.Reader.t
    =
    let from_new_peers =
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

  let main storage_location genesis_block initial_peers should_mine =
    let open Let_syntax in
    let params : Gossip_net.Params.t =
      { timeout = Time.Span.of_sec 1.
      ; initial_peers
      ; target_peer_count = 8
      }
    in
    let peer_stream = Swim.connect ~initial_peers in
    let%bind gossip_net = Gossip_net.create peer_stream params in
    let%bind initial_block = 
      match%map Storage.load storage_location with
      | Some x -> x
      | None -> genesis_block
    in
    (* Are peers bi-directional? *)
    let strongest_block_reader, strongest_block_writer = Pipe.create () in
    don't_wait_for begin
      Pipe.transfer ~f:(fun b -> New_strongest_block b)
        strongest_block_reader
        (Gossip_net.broadcast gossip_net);
    end;
    let head_changes = 
      Pipe.map strongest_block_reader
        ~f:(fun b -> `Change_head b) 
    in
    let body_changes_reader, body_changes_writer = Pipe.create () in
    let () =
      don't_wait_for begin
        Pipe.iter strongest_block_reader 
          ~f:(fun b -> 
            Pipe.write body_changes_writer (`Change_body (Int64.(b.body + Int64.one))))
      end
    in
    let%map mined_blocks = Miner.mine head_changes body_changes_reader in
    Storage.persist storage_location head_changes;
    Blockchain.accumulate
      ~init:initial_block
      ~strongest_block:strongest_block_writer
      ~updates:(
        Pipe.merge ~cmp:(fun _ _ -> 1)
          [ peer_strongest_blocks gossip_net
          ; Pipe.map mined_blocks ~f:(fun b -> Blockchain.Update.New_block b)
          ])
  ;;
end
