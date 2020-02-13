open Async_kernel
open Core_kernel
open Coda_base

type t [@@deriving sexp]

module Stable :
  sig
    module V1 : sig
      type t [@@deriving sexp, bin_io, version]

      val hash : t -> Staged_ledger_hash.Aux_hash.t
    end

    module Latest = V1
  end
  with type V1.t = t

module Transaction_with_witness : sig
  (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
  type t =
    { transaction_with_info: Ledger.Undo.t Transaction_protocol_state.t
    ; statement: Transaction_snark.Statement.t
    ; witness: Transaction_witness.t }
  [@@deriving sexp]
end

module Ledger_proof_with_sok_message : sig
  type t = Ledger_proof.t * Sok_message.t
end

module Available_job : sig
  type t [@@deriving sexp]
end

module Space_partition : sig
  type t = {first: int * int; second: (int * int) option} [@@deriving sexp]
end

module Job_view : sig
  type t [@@deriving sexp, to_yojson]
end

(** Validates and merges statements in the scan state chronologically,
  * returning an error if the statements are not correctly ordered, and
  * otherwise returning a statement which represents the full statement of the
  * entire scan state (all the way from the earliest source to the latest
  * target)
  *)
val scan_statement :
  t -> (Transaction_snark.Statement.t, [`Empty | `Error of Error.t]) Result.t

(** Checks structural invariants of the scan state. Does not verify proofs
  * contained in statements.
  *)
val check_invariants :
     t
  -> error_prefix:string
  -> ledger_hash_end:Frozen_ledger_hash.t
  -> ledger_hash_begin:Frozen_ledger_hash.t option
  -> unit Or_error.t

(** Verify all the proofs contained in the the scan state. Throws an
  * exception if the Verifier returns an error (not if verification
  * fails).
  *)
val verify_proofs_exn :
  t -> logger:Logger.t -> verifier:Verifier.t -> bool Deferred.t

(*All the transactions with undos*)
module Staged_undos : sig
  type t

  val apply : t -> Ledger.t -> unit Or_error.t
end

val staged_undos : t -> Staged_undos.t

val empty : unit -> t

val fill_work_and_enqueue_transactions :
     t
  -> Transaction_with_witness.t list
  -> Transaction_snark_work.t list
  -> ((Ledger_proof.t * Transaction.t list) option * t) Or_error.t

val latest_ledger_proof :
  t -> (Ledger_proof_with_sok_message.t * Transaction.t list) option

val free_space : t -> int

val base_jobs_on_latest_tree : t -> Transaction_with_witness.t list

val hash : t -> Staged_ledger_hash.Aux_hash.t

val target_merkle_root : t -> Frozen_ledger_hash.t option

(** All the transactions in the order in which they were applied*)
val staged_transactions : t -> Transaction.t list Or_error.t

(** Available space and the corresponding required work-count in one and/or two trees (if the slots to be occupied are in two different trees)*)
val partition_if_overflowing : t -> Space_partition.t

val statement_of_job : Available_job.t -> Transaction_snark.Statement.t option

val snark_job_list_json : t -> string

(** All the proof bundles *)
val all_work_statements : t -> Transaction_snark.Statement.t One_or_two.t list

(** Required proof bundles for a certain number of slots *)
val required_work_pairs : t -> slots:int -> Available_job.t One_or_two.t list

(**K proof bundles*)
val k_work_pairs_for_new_diff : t -> k:int -> Available_job.t One_or_two.t list

(** All the proof bundles for 2**transaction_capacity_log2 slots that can be used up in one diff *)
val work_statements_for_new_diff :
  t -> Transaction_snark.Statement.t One_or_two.t list

(** True if the latest tree is full and transactions would be added on to a new tree *)
val next_on_new_tree : t -> bool

(**update scan state metrics*)
val update_metrics : t -> unit Or_error.t

(** All the proof bundles for snark workers*)
val all_work_pairs_exn :
     t
  -> ( Transaction.t Transaction_protocol_state.t
     , Transaction_witness.t
     , Ledger_proof.t )
     Snark_work_lib.Work.Single.Spec.t
     One_or_two.t
     list

module Constants : Snark_params.Scan_state_constants.S
