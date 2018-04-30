open Core
open Async
open Nanobit_base
open Blockchain_snark

module type Init_intf = sig
  type proof [@@deriving bin_io]

  val conf_dir : string
  val prover : Prover.t

  val genesis_proof : proof
end

module Make_inputs0
  (Init : Init_intf)
  (Ledger_proof : Protocols.Minibit_pow.Proof_intf)
  (State_proof : sig
    type t = Init.proof [@@deriving bin_io]
    include Protocols.Minibit_pow.Proof_intf with type input = State.t
                                              and type t := t
  end)
  (Difficulty : module type of Difficulty)
= struct
  module State_proof = State_proof
  module Ledger_proof = Ledger_proof
  module Time = Block_time
  module State_hash = State_hash.Stable.V1
  module Ledger_hash = Ledger_hash.Stable.V1
  module Transaction = Transaction

  module Nonce = Nanobit_base.Nonce

  module Difficulty = Difficulty

  module Pow = Snark_params.Tick.Pedersen.Digest

  module Strength = Strength
  module Ledger = struct
    type t = Nanobit_base.Ledger.t [@@deriving sexp, compare, hash, bin_io]
    type valid_transaction = Transaction.With_valid_signature.t

    let create = Ledger.create
    let merkle_root = Ledger.merkle_root
    let copy = Nanobit_base.Ledger.copy
    let apply_transaction t (valid_transaction : Transaction.With_valid_signature.t) : unit Or_error.t =
      Nanobit_base.Ledger.apply_transaction_unchecked t (valid_transaction :> Transaction.t)
    let undo_transaction = Nanobit_base.Ledger.undo_transaction
  end

  module Transition = struct
    type t =
      { ledger_hash : Ledger_hash.t
      ; ledger_proof : Ledger_proof.t sexp_opaque
      ; timestamp : Time.t
      ; nonce : Nonce.t
      }
    [@@deriving sexp, fields]
  end

  module Time_close_validator = struct
    let validate t =
      let now_time = Time.now () in
      Time.(diff now_time t < (Span.of_time_span (Core_kernel.Time.Span.of_sec 900.)))
  end

  module State = struct
    include State
    module Proof = State_proof
  end

  module Proof_carrying_state = struct
    type t = (State.t, State.Proof.t sexp_opaque) Protocols.Minibit_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end

  module State_with_witness = struct
    type ledger_hash = Ledger_hash.t
      [@@deriving sexp, bin_io]
    type transaction = Transaction.t
      [@@deriving sexp, bin_io]
    type transaction_with_valid_signature = Transaction.With_valid_signature.t
      [@@deriving sexp, bin_io]
    type witness = (transaction_with_valid_signature list * ledger_hash)
      [@@deriving sexp, bin_io]
    type state = Proof_carrying_state.t 
      [@@deriving sexp, bin_io]
    type t =
      { transactions : transaction_with_valid_signature list
      ; previous_ledger_hash : ledger_hash
      ; state : state
      }
      [@@deriving sexp, bin_io]

    module Stripped = struct
      type witness0 = witness [@@deriving bin_io]
      type witness = witness0 [@@deriving bin_io]
      type t =
        { transactions : transaction list
        ; previous_ledger_hash : ledger_hash
        ; state : state
        }
      [@@deriving bin_io]
    end

    let strip t = 
      { Stripped.transactions = (t.transactions :> Transaction.t list)
      ; previous_ledger_hash = t.previous_ledger_hash
      ; state = t.state
      }

    let forget_witness {state} = state
    (* TODO should we also consume a ledger here so we know the transactions valid? *)
    let add_witness_exn state (transactions, previous_ledger_hash) =
      {state ; transactions ; previous_ledger_hash}
    (* TODO same *)
    let add_witness state (transactions, previous_ledger_hash) = Or_error.return {state ; transactions ; previous_ledger_hash}
  end
  module Transition_with_witness = struct
    type witness = (Transaction.With_valid_signature.t list * Ledger_hash.t)
    [@@deriving sexp]
    type t =
      { transactions : Transaction.With_valid_signature.t list
      ; previous_ledger_hash : Ledger_hash.t
      ; transition : Transition.t
      }
    [@@deriving sexp]

    let forget_witness {transition} = transition
    (* TODO should we also consume a ledger here so we know the transactions valid? *)
    let add_witness_exn transition (transactions, previous_ledger_hash) =
      {transition ; transactions ; previous_ledger_hash}
    (* TODO same *)
    let add_witness transition (transactions, previous_ledger_hash) = Or_error.return {transition ; transactions ; previous_ledger_hash}
  end

end
module Make_inputs
  (Init : Init_intf)
  (Ledger_proof : Protocols.Minibit_pow.Proof_intf)
  (State_proof : sig
    type t = Init.proof [@@deriving bin_io]
    include Protocols.Minibit_pow.Proof_intf with type input = State.t
                                              and type t := t
  end)
  (Difficulty : module type of Difficulty)
  (Store : Storage.With_checksum_intf)
  (Bundle : Bundle.S0 with type proof := Ledger_proof.t)
= struct
  module Inputs0 = Make_inputs0(Init)(Ledger_proof)(State_proof)(Difficulty)
  include Inputs0
  module Net = Minibit_networking.Make(struct
    module State_with_witness = State_with_witness
    module Ledger_hash = Ledger_hash
    module Ledger = Ledger
    module State = State
  end)
  module Ledger_fetcher_io = Net.Ledger_fetcher_io

  module State_io = Net.State_io

  module Bundle = struct
    include Bundle
    let create ledger ts = create ledger ts ~conf_dir:Init.conf_dir
  end

  module Transaction_pool = Transaction_pool.Make(Transaction)(Ledger)

  module Genesis = struct
    let state : State.t = State.zero
    let proof = Init.genesis_proof
  end
  module Ledger_fetcher = Ledger_fetcher.Make(struct
    include Inputs0
    module Net = Net
    module Store = Store
    module Genesis = Genesis
    module Genesis_ledger = Genesis_ledger
  end)

  module Miner = Minibit_miner.Make(struct
    include Inputs0
    module Bundle = Bundle
  end)
end

module Main_without_snark (Init : Init_intf) = struct
  module Init = struct
    type proof = () [@@deriving bin_io]

    let conf_dir = Init.conf_dir
    let prover = Init.prover
    let genesis_proof = ()
  end

  module Ledger_proof = Ledger_proof.Debug

  module State_proof = State_proof.Make_debug(Init)

  module Bundle = struct
    type t = Ledger_hash.t

    let create ~conf_dir ledger ts =
      Ledger.merkle_root_after_transactions ledger ts

    let cancel (t : t) : unit = ()

    let target_hash t = t

    let result (t : t) =
      (* I need this local variable to convince the type checker *)
      let p : Ledger_proof.t = () in
      Deferred.Option.return p
  end

  module Inputs =
    Make_inputs(Init)(Ledger_proof)(State_proof)(Difficulty)(Storage.Disk)(Bundle)

  module Main =
      Minibit.Make(Inputs)(struct
        module Witness = struct
          type t =
            { old_state : Inputs.State.t
            ; old_proof : Inputs.State.Proof.t
            ; transition : Inputs.Transition.t
            }
        end

        let prove_zk_state_valid _ ~new_state:_ = return Inputs.Genesis.proof
      end)
end

module Main_with_snark
    (Init : Init_intf with type proof = Proof.t)
= struct
  module Ledger_proof = Ledger_proof.Make_prod(Init)
  module State_proof = State_proof.Make_prod(Init)
  module Bundle = struct
    include Bundle
    let result t = Deferred.Option.(result t >>| Transaction_snark.proof)
  end

  module Inputs = Make_inputs(Init)(Ledger_proof)(State_proof)(Difficulty)(Storage.Disk)(Bundle)

  module Main =
    Minibit.Make(Inputs)(struct
      module Witness = struct
        type t =
          { old_state : Inputs.State.t
          ; old_proof : Inputs.State.Proof.t
          ; transition : Inputs.Transition.t
          }
      end

      let prove_zk_state_valid ({ old_state; old_proof; transition } : Witness.t) ~new_state:_ =
        Prover.extend_blockchain Init.prover
          { state = State.to_blockchain_state old_state; proof = old_proof }
          { header = { time = transition.timestamp; nonce = transition.nonce }
          ; body = { target_hash = transition.ledger_hash; proof = transition.ledger_proof }
          }
        >>| Or_error.ok_exn
        >>| Blockchain.proof
    end)
end

module type Main_intf = sig
  module Inputs : sig
    module Ledger_fetcher : sig
      type t
      val best_ledger : t -> Ledger.t
    end
    module Transaction_pool : sig
      type t
      val add : t -> Transaction.With_valid_signature.t -> t
    end
    module Net : sig
      open Kademlia
      module Gossip_net : sig
        module Params : sig
          type t =
            { timeout           : Time.Span.t
            ; target_peer_count : int
            ; address           : Peer.t
            }
        end
      end
      module Config : sig
        type t = 
          { parent_log : Logger.t
          ; gossip_net_params : Gossip_net.Params.t
          ; initial_peers : Peer.t list
          ; me : Peer.t
          ; remap_addr_port : Peer.t -> Peer.t
          }
      end
    end
  end

  module Main : sig
    module Config : sig
      type t =
        { log : Logger.t
        ; net_config : Inputs.Net.Config.t
        ; ledger_disk_location : string
        ; pool_disk_location : string
        }
    end

    type t
    val ledger_fetcher : t -> Inputs.Ledger_fetcher.t
    val modify_transaction_pool : t -> f:(Inputs.Transaction_pool.t -> Inputs.Transaction_pool.t) -> unit

    val create : Config.t -> t Deferred.t
    val run : t -> unit
  end
end

module Run (Program : Main_intf) = struct
  open Program

  let get_balance t (addr : Public_key.Stable.V1.t) =
    let ledger = Inputs.Ledger_fetcher.best_ledger (Main.ledger_fetcher t) in
    let key = Public_key.compress addr in
    let maybe_balance =
      Option.map
        (Ledger.get ledger key)
        ~f:(fun account -> account.Account.balance)
    in
    return maybe_balance

  let send_txn log t txn =
    let ledger = Inputs.Ledger_fetcher.best_ledger (Main.ledger_fetcher t) in
    match Transaction.check txn with
    | Some txn ->
      let ledger' = Ledger.copy ledger in
      let () = Ledger.apply_transaction ledger' txn |> Or_error.ok_exn in
      Main.modify_transaction_pool t ~f:(fun pool ->
        Inputs.Transaction_pool.add pool txn
      );
      Logger.info log !"Added transaction %{sexp: Transaction.With_valid_signature.t} to pool successfully" txn;
      return (Some ())
    | None -> return None

  let setup_client_server ~minibit ~log ~client_port =
    (* Setup RPC server for client interactions *)
    let module Client_server = Client.Rpc_server(struct
      type t = Main.t
      let get_balance = get_balance
      let send_txn = send_txn log
    end) in
    Client_server.init_server
      ~parent_log:log
      ~minibit
      ~port:client_port

  let run ~minibit ~log =
    Logger.debug log "Created minibit\n%!";
    Main.run minibit;
    Logger.debug log "Ran minibit\n%!";
end


