open Core
open Async
open Kademlia
open Nanobit_base
open Blockchain_snark

module Snark = Snark
module Digest = Snark_params.Tick.Pedersen.Digest

module Rpcs = struct
  module Get_strongest_block = struct
    module T = struct
      let name = "get_strongest_block"
      module T = struct
        type query = unit
        type response = Blockchain.t
      end
      module Caller = T
      module Callee = T
    end
    include T.T
    include Versioned_rpc.Both_convert.Plain.Make(T)

    module V1 = struct
      module T = struct
        type query = unit [@@deriving bin_io]
        type response = Blockchain.Stable.V1.t [@@deriving bin_io]
        let version = 1
        let query_of_caller_model = Fn.id
        let callee_model_of_query = Fn.id
        let response_of_callee_model = Fn.id
        let caller_model_of_response = Fn.id
      end
      include T
      include Register(T)
    end
  end
end

module Message = struct
  module T = struct
    module T = struct
      type msg =
        | New_strongest_block of Blockchain.Stable.V1.t
      [@@deriving bin_io]
    end
    let name = "message"
    module Caller = T
    module Callee = T
  end
  include T.T
  include Versioned_rpc.Both_convert.One_way.Make(T)

  module V1 = struct
    module T = struct
      include T.T
      let version = 1
      let callee_model_of_msg = Fn.id
      let msg_of_caller_model = Fn.id
    end
    include Register(T)
  end
end
 
let assert_chain_verifies prover chain =
  let%map b = Prover.verify_blockchain prover chain >>| Or_error.ok_exn in
  if not b then failwith "Chain did not verify"
;;

module Make
    (Membership       : Membership.S)
    (Gossip_net : Gossip_net.S)
    (Miner_impl : Miner.S)
  =
struct
  module Gossip_net = Gossip_net(Message)

  let peer_strongest_blocks first_peers gossip_net log
    : Blockchain_accumulator.Update.t Linear_pipe.Reader.t
    =
    let from_new_peers_reader, from_new_peers_writer = Linear_pipe.create () in
    let fetch_period = Time.Span.of_min 10. in
    let fetch_peer_count = 4 in
    let rec timer () = 
      let%bind () = 
        Deferred.List.iter
          ~how:`Parallel
          (Gossip_net.query_random_peers gossip_net fetch_peer_count Rpcs.Get_strongest_block.dispatch_multi ())
          ~f:(fun x -> match%bind x with
            | Ok b ->
                Pipe.write from_new_peers_writer (Blockchain_accumulator.Update.New_chain b)
            | Error e -> Logger.error log "%s" (Error.to_string_hum e); return ())
      in
      (* After a query, wait the fetch_period before re-requesting *)
      let%bind () = after fetch_period in
      timer ()
    in
    don't_wait_for (
      (* Except the first time, wait for peers to exist before querying random people *)
      let%bind _ = first_peers in
      timer ()
    );

    let broadcasts =
      Linear_pipe.filter_map (Gossip_net.received gossip_net)
        ~f:(function
          | New_strongest_block b -> Some (Blockchain_accumulator.Update.New_chain b))
    in
    Linear_pipe.merge_unordered
      [ from_new_peers_reader
      ; broadcasts
      ]
  ;;

  type pipes =
    { strongest_block_writer : Blockchain.t Linear_pipe.Writer.t
    ; gossip_net_strongest_block_reader : Blockchain.t Linear_pipe.Reader.t
    ; gossip_net_strongest_block_propagator : Blockchain.t Linear_pipe.Reader.t
    ; body_changes_strongest_block_reader : Blockchain.t Linear_pipe.Reader.t
    ; storage_strongest_block_reader : Blockchain.t Linear_pipe.Reader.t
    ; latest_strongest_block_reader : Blockchain.t Linear_pipe.Reader.t
    ; body_changes_reader : Miner.Update.t Linear_pipe.Reader.t
    ; body_changes_writer : Miner.Update.t Linear_pipe.Writer.t
    }

  let init_pipes () : pipes =
    let strongest_block_reader, strongest_block_writer = Linear_pipe.create () in
    let gossip_net_strongest_block_reader,
        gossip_net_strongest_block_propagator,
        body_changes_strongest_block_reader,
        storage_strongest_block_reader,
        latest_strongest_block_reader =
      Linear_pipe.fork5 strongest_block_reader in
    let body_changes_reader, body_changes_writer = Linear_pipe.create () in
    { strongest_block_writer
    ; gossip_net_strongest_block_reader
    ; gossip_net_strongest_block_propagator
    ; body_changes_strongest_block_reader
    ; storage_strongest_block_reader
    ; latest_strongest_block_reader
    ; body_changes_reader
    ; body_changes_writer
    }

  let init_pipes_with_log log : pipes =
    let strongest_block_reader, strongest_block_writer = Linear_pipe.create () in
    let gossip_net_strongest_block_reader,
        gossip_net_strongest_block_propagator,
        body_changes_strongest_block_reader,
        storage_strongest_block_reader,
        latest_strongest_block_reader,
        log_strongest_block_reader
      = Linear_pipe.fork6 strongest_block_reader in
    let body_changes_reader, body_changes_writer = Linear_pipe.create () in
    let body_changes_reader, log_body_changes_reader = Linear_pipe.fork2 body_changes_reader in
    don't_wait_for begin
      let last_time = ref None in
      Linear_pipe.iter 
        log_strongest_block_reader 
        ~f:(fun blockchain ->
          let state = blockchain.Blockchain.state in
          let ledger_hash = state.Blockchain_state.ledger_hash in
          let time = state.Blockchain_state.timestamp in
          let target = (Nanobit_base.Target.to_bigint state.Blockchain_state.next_difficulty) in
          let strength = Bignum.Bigint.((Nanobit_base.Target.to_bigint Nanobit_base.Target.max) / target) in
          let diff = 
            match !last_time with
            | None -> ""
            | Some previous_time -> 
              let a = Block_time.to_time time in
              let b = Block_time.to_time previous_time in
              Time.Span.to_string (Time.diff a b)
          in
          Logger.info log ~attrs:[ ("ledger_hash", [%sexp_of: Ledger_hash.t] ledger_hash )
                                 ; ("strength", [%sexp_of: Bignum.Bigint.t] strength)
                                 ; ("mining time", [%sexp_of: String.t] diff) ]
            "new strongest blockchain";
          last_time := Some time;
          Deferred.unit)
    end;
    don't_wait_for begin
      Linear_pipe.iter 
        log_body_changes_reader 
        ~f:(fun u ->
          begin match u with
          | Miner.Update.Change_body body -> 
            Logger.debug log !"new block body %{sexp:Block.With_transactions.Body.t}" body
          | Change_previous prev ->
            Logger.debug log !"new previous chain %{sexp:Blockchain_state.t}"
              prev.state
          end;
          Deferred.unit)
    end;
    { strongest_block_writer
    ; gossip_net_strongest_block_reader
    ; gossip_net_strongest_block_propagator
    ; body_changes_strongest_block_reader
    ; storage_strongest_block_reader
    ; latest_strongest_block_reader
    ; body_changes_reader
    ; body_changes_writer
    }

  let init_gossip_net 
        ~me 
        ~pipes:{gossip_net_strongest_block_reader} 
        ~log
        ~membership 
        ~latest_strongest_block 
        ~latest_mined_block 
        ~remap_addr_port
    =
    let params : Gossip_net.Params.t =
      { timeout = Time.Span.of_sec 1.
      ; target_peer_count = 8
      ; address = remap_addr_port me
      }
    in
    let get_strongest_block_handler () ~version () = 
      return !latest_strongest_block
    in
    let implementations = 
      Rpcs.Get_strongest_block.implement_multi get_strongest_block_handler
    in
    let rebroadcast_period = Time.Span.of_sec 10. in
    let remap_ports peers = 
      List.map peers ~f:(fun peer -> remap_addr_port peer)
    in
    let gossip_net = 
      Gossip_net.create 
        (Linear_pipe.map 
           (Membership.changes membership) 
           ~f:(function
             | Connect peers -> Peer.Event.Connect (remap_ports peers)
             | Disconnect peers -> Disconnect (remap_ports peers)
           ))
        params 
        log
        implementations 
    in
    (* someday this could be much more sophisticated 
     *   don't wait for each target_peer group to finish
     *   stop sending once everyone seems to have the message
     *   send to # > target_peers simultaenously based on machine capacity
     * *)
    let rec rebroadcast_timer () = 
      let rec rebroadcast_loop (blockchain : Blockchain.t) continue = 
        let is_latest =
          Blockchain_state.equal blockchain.state !latest_strongest_block.state
        in
        if is_latest
        then 
          match%bind continue () with
          | `Done -> return ()
          | `Continue ->
            rebroadcast_loop blockchain continue
        else return ()
      in
      let%bind () = after rebroadcast_period in
      let mined_block : Blockchain.t = !latest_mined_block in
      let is_latest = Blockchain_state.equal mined_block.state !latest_strongest_block.state in
      let%bind () = 
        if is_latest
        then rebroadcast_loop 
               !latest_mined_block
               (unstage
                  (Gossip_net.broadcast_all
                     gossip_net (Message.New_strongest_block !latest_mined_block)))
        else return ()
      in
      rebroadcast_timer  ()
    in
    don't_wait_for (rebroadcast_timer ());
    don't_wait_for begin
      Linear_pipe.transfer ~f:(fun b -> New_strongest_block b)
        gossip_net_strongest_block_reader
        (Gossip_net.broadcast gossip_net);
    end;
    gossip_net

  let start_mining ~prover ~parent_log ~pipes ~initial_blockchain =
    let mined_blocks_reader =
      Miner_impl.mine ~prover
        ~initial:initial_blockchain
        ~parent_log
        ~body:Block.With_transactions.Body.dummy
        (Linear_pipe.merge_unordered
           [ Linear_pipe.map pipes.body_changes_strongest_block_reader ~f:(fun b -> Miner.Update.Change_previous b)
          ; pipes.body_changes_reader
          ])
    in
    Linear_pipe.fork2 mined_blocks_reader

  let main_nowait 
        ~log
        ~prover
        ~storage_location 
        ~genesis_blockchain
        ~initial_peers 
        ~should_mine 
        ~me 
        ~remap_addr_port
        ~client_port
        ~pipes
    =
      Logger.debug log "Starting with me %s; client_port %s" (Host_and_port.to_string me) (Int.to_string client_port);
    let open Let_syntax in
    let initial_blockchain =
      (*match%map Storage.load storage_location log with*)
      (*| Some x -> x*)
      genesis_blockchain
    in
    (* TODO: fix mined_block vs mined_blocks *)
    let (blockchain_mined_block_reader, latest_mined_blocks_reader) =
      if should_mine then
        start_mining ~prover ~parent_log:log ~pipes ~initial_blockchain
      else
        (Linear_pipe.of_list [], Linear_pipe.of_list [])
    in
    let%map membership =
      match%map (Membership.connect ~initial_peers ~me ~parent_log:log) with
      | Ok membership -> membership
      | Error e -> failwith (Printf.sprintf "Failed to connect to kademlia process: %s\n" (Error.to_string_hum e))
    in
    let gossip_net =
      init_gossip_net
        ~me
        ~log
        ~pipes
        ~latest_strongest_block:(
          Linear_pipe.latest_ref ~initial:genesis_blockchain pipes.latest_strongest_block_reader)
        ~latest_mined_block:(
          Linear_pipe.latest_ref ~initial:genesis_blockchain latest_mined_blocks_reader)
        ~membership
        ~remap_addr_port
    in
    don't_wait_for begin
      Linear_pipe.transfer
        pipes.gossip_net_strongest_block_propagator
        pipes.body_changes_writer
        ~f:(fun b -> Miner.Update.Change_body Block.With_transactions.Body.dummy)
    end;

    Blockchain_accumulator.accumulate
      ~prover
      ~parent_log:log
      ~init:initial_blockchain
      ~strongest_chain:pipes.strongest_block_writer
      ~updates:(
        Linear_pipe.merge_unordered
          [ peer_strongest_blocks (Membership.first_peers membership) gossip_net log
          ; Linear_pipe.map blockchain_mined_block_reader ~f:(fun b ->
              Blockchain_accumulator.Update.New_chain b)
          ]);

    (* Setup RPC server for client interactions *)
    Client.init_server
      ~parent_log:log
      ~port:client_port;

    membership


  let main
        ~log
        ~prover
        ~storage_location 
        ~genesis_blockchain
        ~initial_peers 
        ~should_mine 
        ~me 
        ?(remap_addr_port=(fun addr -> addr))
        ?(client_port=(Host_and_port.port me) + 2)
        ()
    =
    Logger.info log "starting nanobit";
    let%bind _ = 
      main_nowait 
        ~log
        ~prover
        ~storage_location 
        ~genesis_blockchain
        ~initial_peers 
        ~should_mine 
        ~me 
        ~remap_addr_port 
        ~client_port
        ~pipes:(init_pipes_with_log log)
    in
    Async.never ()
  ;;
end

(* Make sure tests work *)
let%test "trivial" = true

include Make(Membership.Haskell)(Gossip_net.Make)(Miner.Cpu)

