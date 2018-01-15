open Core
open Async

module Snark = Snark

module Rpcs = struct
  module Get_strongest_block = struct
    type query = unit [@@deriving bin_io]
    type response = Blockchain.t [@@deriving bin_io]

    (* TODO: Use stable types. *)
    let rpc : (query, response) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Get_strongest_block" ~version:0
        ~bin_query ~bin_response
  end
end

module Message = struct
  type t =
    | New_strongest_block of Blockchain.t
  [@@deriving bin_io]
end

module SwimConfig = Swim.Config
module Make
    (Swim       : Swim.S)
    (Gossip_net : Gossip_net.S)
    (Miner_impl : Miner.S)
    (Storage    : Storage.S)
  =
struct
  module Gossip_net = Gossip_net(Message)

  let peer_strongest_blocks gossip_net
    : Blockchain.Update.t Linear_pipe.Reader.t
    =
    let from_new_peers =
      Linear_pipe.filter_map_unordered ~max_concurrency:64 (Gossip_net.new_peers gossip_net) ~f:(fun peer ->
        Deferred.map ~f:(function
          | Ok b -> Some (Blockchain.Update.New_chain b)
          | Error _ -> None)
          (Gossip_net.query_peer gossip_net peer
              Rpcs.Get_strongest_block.rpc ()))
    in
    let broadcasts =
      Linear_pipe.filter_map (Gossip_net.received gossip_net)
        ~f:(function
          | New_strongest_block b -> Some (Blockchain.Update.New_chain b))
    in
    Linear_pipe.merge_unordered
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
    let%bind swim = Swim.connect ~config:(SwimConfig.create ()) ~initial_peers ~me in
    let%bind gossip_net = Gossip_net.create (Swim.changes swim) params in
    let%map initial_blockchain =
      match%map Storage.load storage_location with
      | Some x -> x
      | None -> genesis_block
    in
    (* Are peers bi-directional? *)
    let strongest_block_reader, strongest_block_writer = Linear_pipe.create () in
    let gossip_net_strongest_block_reader, 
        body_changes_strongest_block_reader,
        storage_strongest_block_reader = Linear_pipe.fork3 strongest_block_reader in
    don't_wait_for begin
      Linear_pipe.transfer ~f:(fun b -> New_strongest_block b)
        gossip_net_strongest_block_reader 
        (Gossip_net.broadcast gossip_net);
    end;
    let body_changes_reader, body_changes_writer = Linear_pipe.create () in
    let () =
      don't_wait_for begin
        Linear_pipe.iter gossip_net_strongest_block_reader
          ~f:(fun b ->
            Pipe.write body_changes_writer
              (Miner.Update.Change_body (Int64.succ b.state.number)))
      end
    in
    let mined_blocks =
      if should_mine
      then
        Miner_impl.mine
          ~previous:initial_blockchain
          ~body:(Int64.succ initial_blockchain.state.number)
          (Linear_pipe.merge_unordered
            [ Linear_pipe.map body_changes_strongest_block_reader ~f:(fun b -> Miner.Update.Change_previous b)
            ; body_changes_reader
            ])
      else Linear_pipe.of_list []
    in
    Storage.persist storage_location
      (Linear_pipe.map storage_strongest_block_reader ~f:(fun b -> `Change_head b));
    Blockchain.accumulate
      ~init:initial_blockchain
      ~strongest_chain:strongest_block_writer
      ~updates:(
        Linear_pipe.merge_unordered
          [ peer_strongest_blocks gossip_net
          ; Linear_pipe.map mined_blocks ~f:(fun b -> Blockchain.Update.New_chain b)
          ])
  ;;
end

module Main = Make(Swim.Udp)(Gossip_net.Make)(Miner.Cpu)(Storage.Filesystem)

let () =
  let open Command.Let_syntax in
  Command.async'
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
            Reader.load_sexps_exn conf_dir Host_and_port.t_of_sexp
          in
          Main.main (conf_dir ^/ "storage") Blockchain.genesis initial_peers should_mine
            (* TODO: This should be inside the config_dir right? *)
            (Host_and_port.create ~host:"127.0.0.1" ~port:8884)
      ]
    end
  |> Command.run
;;
