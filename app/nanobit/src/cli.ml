open Core
open Async
open Nanobit_base
open Blockchain_snark
open Cli_common

module Inputs0 = struct
  module Time = Block_time
  module Hash = struct
    type 'a t = Snark_params.Tick.Pedersen.Digest.t
    [@@deriving compare, hash, sexp, bin_io]
    (* TODO *)
    let digest _ = Snark_params.Tick.Pedersen.zero_hash
  end
  module Transaction = struct
    type t = { transaction: Nanobit_base.Transaction.t }
      [@@deriving eq, bin_io]
    (* The underlying transaction has an arbitrary compare func, fallback to that *)
    let compare t t' = 
      let fee_compare =
        Transaction.Fee.compare
          t.transaction.payload.fee
          t'.transaction.payload.fee
      in
      match fee_compare with
      | 0 -> Transaction.compare t.transaction t'.transaction
      | _ -> fee_compare

    module With_valid_signature = struct
      type t = 
        { transaction: Nanobit_base.Transaction.t 
        ; validation: unit
        }
      [@@deriving eq, bin_io]
      let compare t t' = compare {transaction = t.transaction} {transaction = t'.transaction}
    end

    let check t =
      if Nanobit_base.Transaction.check_signature t.transaction then
        Some
          { transaction = t.transaction
          ; With_valid_signature.validation = ()
          }
      else
        None
    let forget t = { transaction = t.With_valid_signature.transaction }
  end
  module Nonce = Nanobit_base.Nonce
  module Difficulty = struct
    type t = Target.t
    [@@deriving bin_io]

    let next t ~last ~this =
      Blockchain_state.compute_target last t this

    let meets t h =
      Target.meets_target_unchecked t h
  end
  module Strength = struct
    include Strength

    (* TODO *)
    let increase t ~by = t
  end
  module Ledger = struct
    type t = Nanobit_base.Ledger.t [@@deriving sexp, compare, hash, bin_io]
    type valid_transaction = Transaction.With_valid_signature.t

    let copy = Nanobit_base.Ledger.copy
    let apply_transaction t (valid_transaction : Transaction.With_valid_signature.t) : unit Or_error.t =
      Nanobit_base.Ledger.apply_transaction_unchecked t valid_transaction.transaction
  end
  module Ledger_proof = struct
    type t = unit
    type input = Ledger.t Hash.t * Ledger.t Hash.t

    (* TODO *)
    let verify t _ = return true
  end
  module Transition = struct
    type t =
      { ledger_hash : Ledger.t Hash.t
      ; ledger_proof : Ledger_proof.t
      ; timestamp : Time.t
      ; nonce : Nonce.t
      }
    [@@deriving fields]
  end
  module Time_close_validator = struct
    let validate t =
      let now_time = Time.now () in
      Time.(diff now_time t < (Span.of_time_span (Core_kernel.Time.Span.of_sec 900.)))
  end
  module State = struct
    type 'a hash = 'a Hash.t [@@deriving bin_io]
    type transition = Transition.t
    type difficulty = Difficulty.t [@@deriving bin_io]
    type strength = Strength.t [@@deriving bin_io]
    type ledger = Ledger.t [@@deriving bin_io]
    type time = Time.t [@@deriving bin_io]

    type t =
      { next_difficulty      : difficulty
      ; previous_state_hash  : t hash
      ; ledger_hash          : ledger hash
      ; strength             : strength
      ; timestamp            : time
      }
    [@@deriving fields, bin_io]

    module Proof = struct
      type input = t
      type t = unit
      [@@deriving bin_io]

      (* TODO *)
      let verify t _ = return true
    end
  end
  module Proof_carrying_state = struct
    type t = (State.t, State.Proof.t) Protocols.Minibit_pow.Proof_carrying_data.t
    [@@deriving bin_io]
  end
  module State_with_witness = struct
    type transaction_with_valid_signature = Transaction.With_valid_signature.t
    type transaction = Transaction.t
      [@@deriving bin_io]
    type witness = Transaction.With_valid_signature.t list
      [@@deriving bin_io]
    type state = Proof_carrying_state.t 
      [@@deriving bin_io]
    type t =
      { transactions : witness
      ; state : state
      }
      [@@deriving bin_io]

    module Stripped = struct
      type witness = Transaction.t list
        [@@deriving bin_io]
      type t =
        { transactions : witness
        ; state : Proof_carrying_state.t
        }
      [@@deriving bin_io]
    end

    let strip t = 
      { Stripped.transactions = List.map t.transactions ~f:(fun t -> Transaction.forget t)
      ; state = t.state
      }

    let forget_witness {state} = state
    (* TODO should we also consume a ledger here so we know the transactions valid? *)
    let add_witness_exn state transactions =
      {state ; transactions}
    (* TODO same *)
    let add_witness state transactions = Or_error.return {state ; transactions}
  end
  module Transition_with_witness = struct
    type witness = Transaction.With_valid_signature.t list
    type t =
      { transactions : witness
      ; transition : Transition.t
      }

    let forget_witness {transition} = transition
    (* TODO should we also consume a ledger here so we know the transactions valid? *)
    let add_witness_exn transition transactions =
      {transition ; transactions}
    (* TODO same *)
    let add_witness transition transactions = Or_error.return {transition ; transactions}
  end

end
module Inputs = struct
  include Inputs0
  module Net = Minibit_networking.Make(State_with_witness)(Hash)(Ledger)(State)
  module Ledger_fetcher_io = Net.Ledger_fetcher_io
  module State_io = Net.State_io
  module Ledger_fetcher = Ledger_fetcher.Make(struct
    include Inputs0
    module Net = Net
  end)

  module Bundle = struct
    (* TODO *)
    type t = unit
    let create _ _ = ()
    let cancel _ = ()
    let target_hash _ = failwith "TODO"
    let result _ = failwith "TODO"
  end

  module Transaction_pool = Transaction_pool.Make(Transaction)
  module Miner = Minibit_miner.Make(Inputs0)(Transition_with_witness)(Transaction_pool)(Bundle)
  module Genesis = struct
    (* TODO actually do this right *)
    let state : State.t =
      { next_difficulty = Blockchain_state.zero.Blockchain_state.target
      ; previous_state_hash = Blockchain_state.negative_one.Blockchain_state.block_hash
      ; ledger_hash = Snark_params.Tick.Field.of_int 0
      ; strength = Nanobit_base.Strength.zero
      ; timestamp = Block.genesis.Block.header.Block.Header.time
      }
    let proof = ()
  end
  module Block_state_transition_proof = struct
    module Witness = struct
      type t =
        { old_state : State.t
        ; old_proof : State.Proof.t
        ; transition : Transition.t
        }
    end

    (* TODO *)
    let prove_zk_state_valid t ~new_state = return ()
  end
end

module Main = Minibit.Make(Inputs)(Inputs.Block_state_transition_proof)


let daemon =
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
            ~doc:"Server port for other to connect" (required int16)
        and ip =
          flag "ip"
            ~doc:"External IP address for others to connect" (optional string)
        and start_prover =
          flag "start-prover" no_arg
            ~doc:"Start a new prover process"
        and prover_port =
          flag "prover-port" (optional_with_default Prover.default_port int16)
            ~doc:"Port for prover to listen on" 
        in
        fun () ->
          let open Deferred.Let_syntax in
          let%bind home = Sys.home_directory () in
          let conf_dir =
            Option.value ~default:(home ^/ ".current-config") conf_dir
          in
          let%bind () = Unix.mkdir ~p:() conf_dir in
          let%bind initial_peers =
            let peers_path = conf_dir ^/ "peers" in
            match%bind Reader.load_sexp peers_path [%of_sexp: Host_and_port.t list] with
            | Ok ls -> return ls
            | Error e -> 
              begin
                let default_initial_peers = [] in
                let%map () = Writer.save_sexp peers_path ([%sexp_of: Host_and_port.t list] default_initial_peers) in
                []
              end
          in
          let log = Logger.create () in
          let%bind ip =
            match ip with
            | None -> Find_ip.find ()
            | Some ip -> return ip
          in
          let remap_addr_port = Fn.id in
          let me = Host_and_port.create ~host:ip ~port in
          let net_config = 
            { Inputs.Net.Config.parent_log = log
            ; gossip_net_params =
                { timeout = Time.Span.of_sec 1.
                ; target_peer_count = 8
                ; address = remap_addr_port me
                } 
            ; initial_peers
            ; me
            ; remap_addr_port
            }
          in
          let%bind minibit = Main.create {log ; net_config} in
          printf "Created minibit\n%!";
          Main.run minibit;
          printf "Ran minibit\n%!";
          Async.never ()

          (*let%bind prover =*)
            (*if start_prover*)
            (*then Prover.create ~port:prover_port ~debug:()*)
            (*else Prover.connect { host = "0.0.0.0"; port = prover_port }*)
          (*in*)
          (*let%bind genesis_proof = Prover.genesis_proof prover >>| Or_error.ok_exn in*)
          (*let genesis_blockchain =*)
            (*{ Blockchain.state = Blockchain.State.zero*)
            (*; proof = genesis_proof*)
            (*; most_recent_block = Block.genesis*)
            (*}*)
          (*in*)
          (*let%bind () = Main.assert_chain_verifies prover genesis_blockchain in*)
          (*let%bind ip =*)
            (*match ip with*)
            (*| None -> Find_ip.find ()*)
            (*| Some ip -> return ip*)
          (*in*)
          (*let minibit = Main.create ()*)
          (*let log = Logger.create () in*)
          (*Main.main*)
            (*~log*)
            (*~prover*)
            (*~storage_location:(conf_dir ^/ "storage")*)
            (*~genesis_blockchain*)
            (*~initial_peers *)
            (*~should_mine*)
            (*~me:(Host_and_port.create ~host:ip ~port)*)
            (*()*)
      ]
    end
;;

  let () = 
  Command.group ~summary:"Current"
    [ "daemon", daemon
    ; "prover", Prover.command
    ; "rpc", Main_rpc.command
    ; "client", Client.command
    ]
  |> Command.run
;;

let () = never_returns (Scheduler.go ())
;;
