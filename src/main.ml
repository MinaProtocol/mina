open Core
open Async

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
    let from_new_peers_reader, from_new_peers_writer = Linear_pipe.create () in
    let fetch_period = Time.Span.of_min 10. in
    let fetch_peer_count = 4 in
    let rec timer () = 
      let%bind () = after fetch_period in
      let%bind () = 
        Deferred.List.iter
          ~how:`Parallel
          (Gossip_net.query_random_peers gossip_net fetch_peer_count Rpcs.Get_strongest_block.rpc ())
          ~f:(fun x -> match%bind x with
            | Ok b -> Pipe.write from_new_peers_writer (Blockchain.Update.New_block b)
            | Error e -> printf "%s\n" (Error.to_string_hum e); return ())
      in
      timer ()
    in
    don't_wait_for (timer ());
    let broadcasts =
      Linear_pipe.filter_map (Gossip_net.received gossip_net)
        ~f:(function
          | New_strongest_block b -> Some (Blockchain.Update.New_block b))
    in
    Linear_pipe.merge_unordered
      [ from_new_peers_reader
      ; broadcasts
      ]
  ;;

  let main storage_location genesis_block initial_peers should_mine me =
    let open Let_syntax in
    let params : Gossip_net.Params.t =
      { timeout = Time.Span.of_sec 1.
      ; target_peer_count = 8
      ; address = me
      }
    in
    let strongest_block_reader, strongest_block_writer = Pipe.create () in
    let latest_strongest_block = ref Blockchain.genesis in
    let () =
      don't_wait_for begin
        Pipe.iter strongest_block_reader
          ~f:(fun b -> return (latest_strongest_block := b))
      end
    in
    let get_strongest_block_handler _ _ = 
      return !latest_strongest_block
    in
    let handlers = [
      (Rpcs.Get_strongest_block.rpc, get_strongest_block_handler)
    ] in
    let implementations = 
      Rpc.Implementations.create_exn 
        ~implementations: (List.map handlers ~f:(fun (rpc, cb) -> (Rpc.Rpc.implement rpc cb)))
        ~on_unknown_rpc:`Close_connection
    in
    let swim = Swim.connect ~config:(SwimConfig.create ()) ~initial_peers ~me in
    let gossip_net = Gossip_net.create (Swim.changes swim) params implementations in
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
              (Miner.Update.Change_body (Int64.(b.block.body + Int64.one))))
      end
    in
    let mined_blocks =
      if should_mine
      then
        Miner_impl.mine
          ~previous:initial_blockchain
          ~body:(Int64.succ initial_blockchain.block.body)
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
      ~strongest_block:strongest_block_writer
      ~updates:(
        Linear_pipe.merge_unordered
          [ peer_strongest_blocks gossip_net
          ; Linear_pipe.map mined_blocks ~f:(fun b -> Blockchain.Update.New_block b)
          ])
  ;;
end

module Main = Make(Swim.Udp)(Gossip_net.Make)(Miner.Cpu)(Storage.Filesystem)

let int16 =
  let max_port = 1 lsl 16 in
  Command.Arg_type.map Command.Param.int ~f:(fun x ->
    if 0 <= x && x < max_port
    then x
    else failwithf "Port not between 0 and %d" max_port ())

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
        and port =
          flag "port"
            ~doc:"server port" (required int16)
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
