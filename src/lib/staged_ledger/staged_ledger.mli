open Core_kernel
open Async_kernel
open Coda_base
open Signature_lib

type t [@@deriving sexp]

module Scan_state : sig
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

  module Job_view : sig
    type t [@@deriving sexp, to_yojson]
  end

  module Space_partition : sig
    type t = {first: int * int; second: (int * int) option} [@@deriving sexp]
  end

  val hash : t -> Staged_ledger_hash.Aux_hash.t

  val empty : unit -> t

  val snark_job_list_json : t -> string

  val partition_if_overflowing : t -> Space_partition.t

  val all_work_statements : t -> Transaction_snark_work.Statement.t list

  val work_statements_for_new_diff :
    t -> Transaction_snark_work.Statement.t list
end

module Pre_diff_info : Pre_diff_info.S

module Staged_ledger_error : sig
  type t =
    | Non_zero_fee_excess of Scan_state.Space_partition.t * Transaction.t list
    | Invalid_proof of
        Ledger_proof.t
        * Transaction_snark.Statement.t
        * Public_key.Compressed.t
    | Pre_diff of Pre_diff_info.Error.t
    | Insufficient_work of string
    | Unexpected of Error.t
  [@@deriving sexp]

  val to_string : t -> string

  val to_error : t -> Error.t
end

val ledger : t -> Ledger.t

val scan_state : t -> Scan_state.t

val pending_coinbase_collection : t -> Pending_coinbase.t

val create_exn : ledger:Ledger.t -> t

val of_scan_state_and_ledger :
     logger:Logger.t
  -> verifier:Verifier.t
  -> snarked_ledger_hash:Frozen_ledger_hash.t
  -> ledger:Ledger.t
  -> scan_state:Scan_state.t
  -> pending_coinbase_collection:Pending_coinbase.t
  -> t Or_error.t Deferred.t

val replace_ledger_exn : t -> Ledger.t -> t

val proof_txns : t -> Transaction.t Non_empty_list.t option

val copy : t -> t

val hash : t -> Staged_ledger_hash.t

val apply :
     t
  -> Staged_ledger_diff.t
  -> logger:Logger.t
  -> verifier:Verifier.t
  -> ( [`Hash_after_applying of Staged_ledger_hash.t]
       * [`Ledger_proof of (Ledger_proof.t * Transaction.t list) option]
       * [`Staged_ledger of t]
       * [`Pending_coinbase_data of bool * Currency.Amount.t]
     , Staged_ledger_error.t )
     Deferred.Result.t

val apply_diff_unchecked :
     t
  -> Staged_ledger_diff.With_valid_signatures_and_proofs.t
  -> ( [`Hash_after_applying of Staged_ledger_hash.t]
       * [`Ledger_proof of (Ledger_proof.t * Transaction.t list) option]
       * [`Staged_ledger of t]
       * [`Pending_coinbase_data of bool * Currency.Amount.t]
     , Staged_ledger_error.t )
     Deferred.Result.t

module For_tests : sig
  val materialized_snarked_ledger_hash :
       t
    -> expected_target:Frozen_ledger_hash.t
    -> Frozen_ledger_hash.t Or_error.t
end

val current_ledger_proof : t -> Ledger_proof.t option

(* This should memoize the snark verifications *)

val create_diff :
     t
  -> self:Public_key.Compressed.t
  -> logger:Logger.t
  -> transactions_by_fee:User_command.With_valid_signature.t Sequence.t
  -> get_completed_work:(   Transaction_snark_work.Statement.t
                         -> Transaction_snark_work.Checked.t option)
  -> Staged_ledger_diff.With_valid_signatures_and_proofs.t

val statement_exn : t -> [`Non_empty of Transaction_snark.Statement.t | `Empty]

val of_scan_state_pending_coinbases_and_snarked_ledger :
     logger:Logger.t
  -> verifier:Verifier.t
  -> scan_state:Scan_state.t
  -> snarked_ledger:Ledger.t
  -> expected_merkle_root:Ledger_hash.t
  -> pending_coinbases:Pending_coinbase.t
  -> t Or_error.t Deferred.t

val all_work_pairs_exn :
     t
  -> ( Transaction.t
     , Transaction_witness.t
     , Ledger_proof.t )
     Snark_work_lib.Work.Single.Spec.t
     One_or_two.t
     list
