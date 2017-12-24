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
    (Miner_impl : Miner.S)
    (Storage    : Storage.S)
  =
struct
  module Gossip_net = Gossip_net(Message)

  let merge = Pipe.merge ~cmp:(fun _ _ -> 1)

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
    merge
      [ from_new_peers
      ; broadcasts
      ]
  ;;

  let main storage_location genesis_block initial_peers should_mine me =
    let open Let_syntax in
    let params : Gossip_net.Params.t =
      { timeout = Time.Span.of_sec 1.
      ; initial_peers
      ; target_peer_count = 8
      }
    in
    let%bind swim = Swim.connect ~initial_peers ~me in
    let%bind gossip_net = Gossip_net.create (Swim.changes swim) params in
    let%map initial_block = 
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
    let body_changes_reader, body_changes_writer = Pipe.create () in
    let () =
      don't_wait_for begin
        Pipe.iter strongest_block_reader
          ~f:(fun b ->
            Pipe.write body_changes_writer
              (Miner.Update.Change_body (Int64.(b.body + Int64.one))))
      end
    in
    let mined_blocks =
      if should_mine
      then
        Miner_impl.mine
          ~previous:initial_block
          ~body:(Int64.succ initial_block.body)
          (merge
            [ Pipe.map strongest_block_reader ~f:(fun b -> Miner.Update.Change_previous b)
            ; body_changes_reader
            ])
      else Pipe.of_list []
    in
    Storage.persist storage_location
      (Pipe.map strongest_block_reader ~f:(fun b -> `Change_head b));
    Blockchain.accumulate
      ~init:initial_block
      ~strongest_block:strongest_block_writer
      ~updates:(
        merge
          [ peer_strongest_blocks gossip_net
          ; Pipe.map mined_blocks ~f:(fun b -> Blockchain.Update.New_block b)
          ])
  ;;
end

module Main = Make(Swim.Udp)(Gossip_net.Make)(Miner.Cpu)(Storage.Filesystem)

let () =
  let open Command.Let_syntax in
  Command.async
    ~summary:"Current daemon"
    begin
      [%map_open
        let conf_dir =
          flag "config directory"
            ~doc:"Configuration directory"
            (optional file)
        and should_mine =
          flag "mine"
            ~doc:"Run the miner" (required bool)
        in
        fun () ->
          let open Deferred.Let_syntax in
          let%bind home = Sys.home_directory () in
          let conf_dir =
            Option.value ~default:(home ^/ ".current-config") conf_dir
          in
          let%bind initial_peers =
            Reader.load_sexps_exn conf_dir Peer.t_of_sexp
          in
          Main.main (conf_dir ^/ "storage") Block.genesis initial_peers should_mine
      ]
    end
  |> Command.run
;;
