[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Coda_state
open Coda_transition
open Signature_lib
open Pipe_lib

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

  val prover : Prover.t

  val verifier : Verifier.t

  val genesis_proof : Proof.t
end

module type Main_intf = sig
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

  val best_staged_ledger : t -> Staged_ledger.t Participating_state.t

  val best_ledger : t -> Ledger.t Participating_state.t

  val root_length : t -> int Participating_state.t

  val best_protocol_state : t -> Protocol_state.Value.t Participating_state.t

  val best_tip : t -> Transition_frontier.Breadcrumb.t Participating_state.t

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
    t -> Transition_frontier.Diff.Root_diff.view Strict_pipe.Reader.t

  val transaction_pool : t -> Network_pool.Transaction_pool.t

  val transaction_database : t -> Auxiliary_database.Transaction_database.t

  val external_transition_database :
    t -> Auxiliary_database.External_transition_database.t

  val snark_pool : t -> Network_pool.Snark_pool.t

  val create : Coda_lib.Config.t -> t Deferred.t

  val staged_ledger_ledger_proof : t -> Ledger_proof.t option

  val transition_frontier :
    t -> Transition_frontier.t option Broadcast_pipe.Reader.t

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
  let%bind prover = Prover.create () in
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

    let prover = prover

    let verifier = verifier
  end in
  (module Init : Init_intf)

module Make_coda (Init : Init_intf) = struct
  module Work_selector = Init.Make_work_selector (struct
    module Transaction_witness = Transaction_witness
    module Ledger_proof_statement = Transaction_snark.Statement
    module Sparse_ledger = Sparse_ledger
    module Transaction = Transaction
    module Ledger_hash = Ledger_hash
    module Ledger_proof = Ledger_proof
    module Staged_ledger = Staged_ledger
    module Snark_pool = Network_pool.Snark_pool
    module Fee = Currency.Fee

    module Transaction_snark_work = struct
      type t = Transaction_snark_work.Checked.t

      let fee t =
        let {Transaction_snark_work.fee; _} =
          Transaction_snark_work.forget t
        in
        fee
    end
  end)

  include Coda_lib.Make (Work_selector)

  let request_work t =
    let open Option.Let_syntax in
    let%bind sl =
      match best_staged_ledger t with
      | `Active staged_ledger ->
          Some staged_ledger
      | `Bootstrapping ->
          Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
            "Could not retrieve staged_ledger due to bootstrapping" ;
          None
    in
    let fee = snark_work_fee t in
    let instances, seen_jobs =
      Work_selector.work ~fee ~snark_pool:(snark_pool t) sl (seen_jobs t)
    in
    set_seen_jobs t seen_jobs ;
    if List.is_empty instances then None
    else Some {Snark_work_lib.Work.Spec.instances; fee}
end
