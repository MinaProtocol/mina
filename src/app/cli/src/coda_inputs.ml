[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Coda_state
open Coda_transition
open Signature_lib
open Blockchain_snark
open Coda_numbers
open Pipe_lib
open O1trace

module type Work_selector_F = functor
  (Inputs : Work_selector.Inputs.Inputs_intf)
  -> Work_selector.Intf.S
     with type staged_ledger := Inputs.Staged_ledger.t
      and type work :=
                 ( Inputs.Ledger_proof_statement.t
                 , Inputs.Transaction.t
                 , Inputs.Transaction_witness.t
                 , Inputs.Ledger_proof.t )
                 Snark_work_lib.Work.Single.Spec.t
      and type snark_pool := Inputs.Snark_pool.t
      and type fee := Inputs.Fee.t

module type Config_intf = sig
  val logger : Logger.t

  val conf_dir : string

  val lbc_tree_max_depth : [`Infinity | `Finite of int]

  val propose_keypair : Keypair.t option

  val genesis_proof : Snark_params.Tock.Proof.t

  val commit_id : Daemon_rpcs.Types.Git_sha.t option

  val work_selection : Cli_lib.Arg_type.work_selection
end

module type Init_intf = sig
  include Config_intf

  module Make_work_selector : Work_selector_F

  val proposer_prover : Prover.t

  val verifier : Verifier.t

  val genesis_proof : Proof.t
end

module type Main_intf = sig
  module Inputs : sig
    module Net : sig
      type t

      module Gossip_net : sig
        module Config : Gossip_net.Config_intf
      end

      module Config :
        Coda_networking.Config_intf
        with type gossip_config := Gossip_net.Config.t
    end

    module Snark_pool : sig
      type t

      val add_completed_work :
        t -> Snark_worker.Work.Result.t -> unit Deferred.t
    end

    module Transaction_pool : sig
      type t

      val add : t -> User_command.t -> unit Deferred.t
    end

    module Staged_ledger :
      Coda_intf.Staged_ledger_intf
      with type diff := Staged_ledger_diff.t
       and type valid_diff :=
                  Staged_ledger_diff.With_valid_signatures_and_proofs.t
       and type ledger_proof := Ledger_proof.t
       and type transaction_snark_work := Transaction_snark_work.t
       and type transaction_snark_work_statement :=
                  Transaction_snark_work.Statement.t
       and type transaction_snark_work_checked :=
                  Transaction_snark_work.Checked.t
       and type verifier := Verifier.t

    module Transition_frontier :
      Coda_intf.Transition_frontier_intf
      with type external_transition_validated :=
                  External_transition.Validated.t
       and type mostly_validated_external_transition :=
                  ( [`Time_received] * Truth.true_t
                  , [`Proof] * Truth.true_t
                  , [`Frontier_dependencies] * Truth.true_t
                  , [`Staged_ledger_diff] * Truth.false_t )
                  External_transition.Validation.with_transition
       and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
       and type staged_ledger_diff := Staged_ledger_diff.t
       and type staged_ledger := Staged_ledger.t
       and type verifier := Verifier.t
       and type 'a transaction_snark_work_statement_table :=
         'a Transaction_snark_work.Statement.Table.t
  end

  module Config : sig
    (** If ledger_db_location is None, will auto-generate a db based on a UUID *)
    type t =
      { logger: Logger.t
      ; trust_system: Trust_system.t
      ; verifier: Verifier.t
      ; initial_propose_keypairs: Keypair.Set.t
      ; snark_worker_key: Public_key.Compressed.Stable.V1.t option
      ; net_config: Inputs.Net.Config.t
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; wallets_disk_location: string
      ; persistent_root_location: string
      ; persistent_frontier_location: string
      ; staged_ledger_transition_backup_capacity: int [@default 10]
      ; time_controller: Block_time.Controller.t
      ; receipt_chain_database: Receipt_chain_database.t
      ; transaction_database: Auxiliary_database.Transaction_database.t
      ; external_transition_database:
          Auxiliary_database.External_transition_database.t
      ; snark_work_fee: Currency.Fee.t
      ; monitor: Async.Monitor.t option
      ; consensus_local_state: Consensus.Data.Local_state.t }
    [@@deriving make]
  end

  type t

  (** Derived from local state (aka they may not reflect the latest public keys to which you've attempted to change *)
  val propose_public_keys : t -> Public_key.Compressed.Set.t

  val replace_propose_keypairs : t -> Keypair.And_compressed_pk.Set.t -> unit

  val add_block_subscriber :
       t
    -> Public_key.Compressed.t
    -> ( Auxiliary_database.Filtered_external_transition.t
       , State_hash.t )
       With_hash.t
       Pipe.Reader.t

  val add_payment_subscriber : t -> Account.key -> User_command.t Pipe.Reader.t

  val snark_worker_key : t -> Public_key.Compressed.Stable.V1.t option

  val snark_work_fee : t -> Currency.Fee.t

  val request_work : t -> Snark_worker.Work.Spec.t option

  val best_staged_ledger : t -> Inputs.Staged_ledger.t Participating_state.t

  val best_ledger : t -> Ledger.t Participating_state.t

  val root_length : t -> int Participating_state.t

  val best_protocol_state : t -> Protocol_state.Value.t Participating_state.t

  val best_tip :
    t -> Inputs.Transition_frontier.Breadcrumb.t Participating_state.t

  val sync_status :
    t -> [`Offline | `Synced | `Bootstrap] Coda_incremental.Status.Observer.t

  val visualize_frontier : filename:string -> t -> unit Participating_state.t

  val peers : t -> Network_peer.Peer.t list

  val initial_peers : t -> Host_and_port.t list

  val validated_transitions :
       t
    -> (External_transition.Validated.t, State_hash.t) With_hash.t
       Strict_pipe.Reader.t

  val root_diff :
       t
    -> ([`User_commands of User_command.t list] * [`New_length of int])
       Strict_pipe.Reader.t

  val transaction_pool : t -> Inputs.Transaction_pool.t

  val transaction_database : t -> Auxiliary_database.Transaction_database.t

  val external_transition_database :
    t -> Auxiliary_database.External_transition_database.t

  val snark_pool : t -> Inputs.Snark_pool.t

  val create : Config.t -> t Deferred.t

  val staged_ledger_ledger_proof : t -> Ledger_proof.t option

  val transition_frontier :
    t -> Inputs.Transition_frontier.t option Broadcast_pipe.Reader.t

  val get_ledger :
    t -> Staged_ledger_hash.t -> Account.t list Deferred.Or_error.t

  val receipt_chain_database : t -> Receipt_chain_database.t

  val wallets : t -> Secrets.Wallets.t

  val top_level_logger : t -> Logger.t
end

module Pending_coinbase = struct
  module V1 = struct
    include Pending_coinbase.Stable.V1

    [%%define_locally
    Pending_coinbase.
      ( hash_extra
      , oldest_stack
      , latest_stack
      , create
      , remove_coinbase_stack
      , update_coinbase_stack
      , merkle_root )]

    module Stack = Pending_coinbase.Stack
    module Coinbase_data = Pending_coinbase.Coinbase_data
    module Hash = Pending_coinbase.Hash
  end
end

let make_init (module Config : Config_intf) : (module Init_intf) Deferred.t =
  let open Config in
  let%bind proposer_prover = Prover.create () in
  let%map verifier = Verifier.create () in
  let (module Make_work_selector : Work_selector_F) =
    match work_selection with
    | Seq ->
        (module Work_selector.Sequence.Make : Work_selector_F)
    | Random ->
        (module Work_selector.Random.Make : Work_selector_F)
  in
  let module Init = struct
    module Make_work_selector = Make_work_selector
    include Config

    let proposer_prover = proposer_prover

    let verifier = verifier
  end in
  (module Init : Init_intf)

module Make_inputs0 (Init : Init_intf) = struct
  open Init

  let max_length = Consensus.Constants.k

  module Time_close_validator = struct
    let limit = Block_time.Span.of_time_span (Core.Time.Span.of_sec 15.)

    let validate t =
      let now = Block_time.now Block_time.Controller.basic in
      (* t should be at most [limit] greater than now *)
      Block_time.Span.( < ) (Block_time.diff t now) limit
  end

  module State_body_hash = State_body_hash
  module Ledger_proof = Ledger_proof
  module Sync_ledger = Sync_ledger
  module Syncable_ledger = Sync_ledger
  module Transition_frontier = Transition_frontier
  module Staged_ledger = Staged_ledger
  module Staged_ledger_diff = Staged_ledger_diff
  module Transaction_snark_work = Transaction_snark_work
  module External_transition = External_transition
  module Internal_transition = Internal_transition
  module Verifier = Verifier

  module Transaction_snark_work_proof = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Ledger_proof.Stable.V1.t list
          [@@deriving sexp, bin_io, yojson, version]
        end

        include T
      end
    end
  end

  module Staged_ledger_transition = struct
    type t = {old: Staged_ledger.t sexp_opaque; diff: Staged_ledger_diff.t}
    [@@deriving sexp]

    module With_valid_signatures_and_proofs = struct
      type t =
        { old: Staged_ledger.t sexp_opaque
        ; diff: Staged_ledger_diff.With_valid_signatures_and_proofs.t }
      [@@deriving sexp]
    end

    let forget {With_valid_signatures_and_proofs.old; diff} =
      {old; diff= Staged_ledger_diff.forget diff}
  end

  module Transition_frontier_inputs = struct
    module Ledger_proof = Ledger_proof
    module Transaction_snark_work = Transaction_snark_work
    module Staged_ledger_diff = Staged_ledger_diff
    module External_transition = External_transition
    module Internal_transition = Internal_transition
    module Staged_ledger = Staged_ledger
    module Verifier = Verifier

    let max_length = Consensus.Constants.k
  end

  module Transaction_pool = struct
    module Pool = Transaction_pool.Make (Staged_ledger) (Transition_frontier)
    include Network_pool.Make (Transition_frontier) (Pool) (Pool.Diff)

    type pool_diff = Pool.Diff.t

    let load ~logger ~trust_system ~disk_location:_ ~incoming_diffs
        ~frontier_broadcast_pipe =
      return
        (create ~logger ~trust_system ~incoming_diffs ~frontier_broadcast_pipe)

    let transactions t = Pool.transactions (pool t)

    (* TODO: This causes the signature to get checked twice as it is checked
       below before feeding it to add *)
    let add t txn = apply_and_broadcast t (Envelope.Incoming.local [txn])
  end

  module Transaction_pool_diff = Transaction_pool.Pool.Diff
end

module Make_inputs
    (Init : Init_intf)
    (Store : Storage.With_checksum_intf with type location = string) =
struct
  open Init
  module Inputs0 = Make_inputs0 (Init)
  include Inputs0

  module Genesis = struct
    let state = Genesis_protocol_state.t

    let ledger = Genesis_ledger.t

    let proof = Init.genesis_proof
  end

  module Snark_pool = struct
    module Pool =
      Snark_pool.Make
        (Ledger_proof.Stable.V1)
        (Transaction_snark_work.Statement)
        (Transition_frontier)
    module Snark_pool_diff =
      Network_pool.Snark_pool_diff.Make
        (Ledger_proof.Stable.V1)
        (Transaction_snark_work.Statement)
        (Transition_frontier)
        (Pool)

    type pool_diff = Snark_pool_diff.t

    include Network_pool.Make (Transition_frontier) (Pool) (Snark_pool_diff)

    let get_completed_work t statement =
      Option.map
        (Pool.request_proof (pool t) statement)
        ~f:(fun Snark_pool.Priced_proof.{proof; fee= {fee; prover}} ->
          Transaction_snark_work.Checked.create_unsafe
            {Transaction_snark_work.fee; proofs= proof; prover} )

    let load ~logger ~trust_system ~disk_location ~incoming_diffs
        ~frontier_broadcast_pipe =
      match%map Reader.load_bin_prot disk_location Pool.bin_reader_t with
      | Ok pool ->
          let network_pool = of_pool_and_diffs pool ~logger ~incoming_diffs in
          Pool.listen_to_frontier_broadcast_pipe frontier_broadcast_pipe pool ;
          network_pool
      | Error _e ->
          create ~logger ~trust_system ~incoming_diffs ~frontier_broadcast_pipe

    open Snark_work_lib.Work
    open Network_pool.Snark_pool_diff

    let add_completed_work t
        (res :
          (('a, 'b, 'c, 'd) Single.Spec.t Spec.t, Ledger_proof.t) Result.t) =
      apply_and_broadcast t
        (Envelope.Incoming.wrap
           ~data:
             (Diff.Add_solved_work
                ( List.map res.spec.instances ~f:Single.Spec.statement
                , { proof= res.proofs
                  ; fee= {fee= res.spec.fee; prover= res.prover} } ))
           ~sender:Envelope.Sender.Local)
  end

  module Root_sync_ledger = Sync_ledger.Db

  module Net = Coda_networking.Make (struct
    include Inputs0
    module Snark_pool = Snark_pool
    module Snark_pool_diff = Snark_pool.Snark_pool_diff
  end)

  module Sync_handler = Sync_handler.Make (Inputs0)
  module Transition_handler = Transition_handler.Make (Inputs0)

  module Ledger_catchup = Ledger_catchup.Make (struct
    include Inputs0
    module Transition_handler_validator = Transition_handler.Validator
    module Unprocessed_transition_cache =
      Transition_handler.Unprocessed_transition_cache
    module Ledger_proof_statement = Transaction_snark.Statement
    module Network = Net
    module Breadcrumb_builder = Transition_handler.Breadcrumb_builder
  end)

  module Root_prover = Root_prover.Make (Inputs0)

  module Bootstrap_controller = Bootstrap_controller.Make (struct
    include Inputs0
    module Root_sync_ledger = Root_sync_ledger
    module Network = Net
    module Sync_handler = Sync_handler
    module Root_prover = Root_prover
  end)

  module Transition_frontier_controller =
  Transition_frontier_controller.Make (struct
    include Inputs0
    module Sync_handler = Sync_handler
    module Catchup = Ledger_catchup
    module Transition_handler = Transition_handler
    module Network = Net
  end)

  module Transition_router = Transition_router.Make (struct
    include Transition_frontier_inputs
    module Network = Net
    module Transition_frontier = Transition_frontier
    module Transition_frontier_controller = Transition_frontier_controller
    module Bootstrap_controller = Bootstrap_controller
  end)

  module Pending_coinbase_witness = Pending_coinbase_witness

  module Proposer = Proposer.Make (struct
    include Inputs0

    module Prover = struct
      let prove ~prev_state ~prev_state_proof ~next_state
          (transition : Internal_transition.t) pending_coinbase =
        let prover = Init.proposer_prover in
        let open Deferred.Or_error.Let_syntax in
        Prover.extend_blockchain prover
          (Blockchain.create ~proof:prev_state_proof ~state:prev_state)
          next_state
          (Internal_transition.snark_transition transition)
          (Internal_transition.prover_state transition)
          pending_coinbase
        >>| fun {Blockchain.proof; _} -> proof
    end
  end)

  module Work_selector_inputs = struct
    module Transaction_witness = Transaction_witness
    module Ledger_proof_statement = Transaction_snark.Statement
    module Sparse_ledger = Sparse_ledger
    module Transaction = Transaction
    module Ledger_hash = Ledger_hash
    module Ledger_proof = Ledger_proof
    module Staged_ledger = Staged_ledger
    module Snark_pool = Snark_pool
    module Fee = Currency.Fee

    module Transaction_snark_work = struct
      type t = Transaction_snark_work.Checked.t

      let fee t =
        let {Transaction_snark_work.fee; _} =
          Transaction_snark_work.forget t
        in
        fee
    end
  end

  module Work_selector = Make_work_selector (Work_selector_inputs)

  let request_work ~logger ~best_staged_ledger
      ~(seen_jobs : 'a -> Work_selector.State.t)
      ~(set_seen_jobs : 'a -> Work_selector.State.t -> unit)
      ~(snark_pool : 'a -> Snark_pool.t) (t : 'a) (fee : Currency.Fee.t) =
    let best_staged_ledger t =
      match best_staged_ledger t with
      | `Active staged_ledger ->
          Some staged_ledger
      | `Bootstrapping ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "Could not retrieve staged_ledger due to bootstrapping" ;
          None
    in
    let open Option.Let_syntax in
    let%bind sl = best_staged_ledger t in
    let instances, seen_jobs =
      Work_selector.work ~fee ~snark_pool:(snark_pool t) sl (seen_jobs t)
    in
    set_seen_jobs t seen_jobs ;
    if List.is_empty instances then None
    else Some {Snark_work_lib.Work.Spec.instances; fee}
end

module Make_coda (Init : Init_intf) = struct
  module Inputs = struct
    include Make_inputs (Init) (Storage.Disk)
    module Genesis_ledger = Genesis_ledger
    module Ledger_proof_statement = Transaction_snark.Statement
    module Snark_worker = Snark_worker
    module Transaction_validator = Transaction_validator
    module Genesis_protocol_state = Genesis_protocol_state
    module Snark_transition = Snark_transition
    module Consensus_transition = Consensus.Data.Consensus_transition
    module Consensus_state = Consensus.Data.Consensus_state
    module Blockchain_state = Blockchain_state
    module Prover_state = Consensus.Data.Prover_state
    module Filtered_external_transition =
      Auxiliary_database.Filtered_external_transition
    module External_transition_database =
      Auxiliary_database.External_transition_database
  end

  include Coda_lib.Make (Inputs)

  let request_work t =
    Inputs.request_work ~logger:t.logger ~best_staged_ledger ~seen_jobs
      ~set_seen_jobs ~snark_pool t (snark_work_fee t)
end
