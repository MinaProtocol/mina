open Core_kernel
open Async_kernel
open Signature_lib
open Coda_base

module type Staged_ledger_pre_diff_info_generalized_intf = sig
  type transaction_snark_work

  type staged_ledger_diff

  type valid_staged_ledger_diff

  module Error : sig
    type t =
      | Bad_signature of User_command.t
      | Coinbase_error of string
      | Insufficient_fee of Currency.Fee.t * Currency.Fee.t
      | Unexpected of Error.t
    [@@deriving sexp]

    val to_string : t -> string

    val to_error : t -> Error.t
  end

  val get :
       staged_ledger_diff
    -> ( Transaction.t list
         * transaction_snark_work list
         * int
         * Currency.Amount.t list
       , Error.t )
       result

  val get_unchecked :
       valid_staged_ledger_diff
    -> Transaction.t list
       * transaction_snark_work list
       * Currency.Amount.t list

  val get_transactions :
    staged_ledger_diff -> (Transaction.t list, Error.t) result
end

(* TODO: this is temporarily required due to staged ledger test stubs *)
module type Staged_ledger_diff_generalized_intf = sig
  type fee_transfer_single

  type user_command

  type user_command_with_valid_signature

  type compressed_public_key

  type staged_ledger_hash

  type transaction_snark_work

  type transaction_snark_work_checked

  module At_most_two : sig
    type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
    [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type 'a t [@@deriving sexp, to_yojson, bin_io, version]
        end
      end
      with type 'a V1.t = 'a t

    val increase : 'a t -> 'a list -> 'a t Or_error.t
  end

  module At_most_one : sig
    type 'a t = Zero | One of 'a option [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type 'a t [@@deriving sexp, to_yojson, bin_io, version]
        end
      end
      with type 'a V1.t = 'a t

    val increase : 'a t -> 'a list -> 'a t Or_error.t
  end

  module Pre_diff_with_at_most_two_coinbase : sig
    type t =
      { completed_works: transaction_snark_work list
      ; user_commands: user_command list
      ; coinbase: fee_transfer_single At_most_two.Stable.V1.t }
    [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, to_yojson, bin_io, version]
        end
      end
      with type V1.t = t
  end

  module Pre_diff_with_at_most_one_coinbase : sig
    type t =
      { completed_works: transaction_snark_work list
      ; user_commands: user_command list
      ; coinbase: fee_transfer_single At_most_one.t }
    [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, to_yojson, bin_io, version]
        end
      end
      with type V1.t = t
  end

  module Diff : sig
    type t =
      Pre_diff_with_at_most_two_coinbase.Stable.V1.t
      * Pre_diff_with_at_most_one_coinbase.Stable.V1.t option
    [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, to_yojson, version]
        end
      end
      with type V1.t = t
  end

  type t = {diff: Diff.t; creator: compressed_public_key}
  [@@deriving sexp, to_yojson, fields]

  module Stable :
    sig
      module V1 : sig
        type t = {diff: Diff.t; creator: compressed_public_key}
        [@@deriving sexp, to_yojson, bin_io, version]
      end

      module Latest = V1
    end
    with type V1.t = t

  module With_valid_signatures_and_proofs : sig
    type pre_diff_with_at_most_two_coinbase =
      { completed_works: transaction_snark_work_checked list
      ; user_commands: user_command_with_valid_signature list
      ; coinbase: fee_transfer_single At_most_two.t }
    [@@deriving sexp]

    type pre_diff_with_at_most_one_coinbase =
      { completed_works: transaction_snark_work_checked list
      ; user_commands: user_command_with_valid_signature list
      ; coinbase: fee_transfer_single At_most_one.t }
    [@@deriving sexp]

    type diff =
      pre_diff_with_at_most_two_coinbase
      * pre_diff_with_at_most_one_coinbase option
    [@@deriving sexp]

    type t = {diff: diff; creator: compressed_public_key} [@@deriving sexp]

    val user_commands : t -> user_command_with_valid_signature list
  end

  val forget : With_valid_signatures_and_proofs.t -> t

  val user_commands : t -> user_command list

  val completed_works : t -> transaction_snark_work list

  val coinbase : t -> Currency.Amount.t
end

module type Staged_ledger_diff_intf =
  Staged_ledger_diff_generalized_intf
  with type fee_transfer_single := Fee_transfer.Single.t
   and type user_command := User_command.Stable.V1.t
   and type user_command_with_valid_signature :=
              User_command.With_valid_signature.t
   and type compressed_public_key := Public_key.Compressed.t
   and type staged_ledger_hash := Staged_ledger_hash.t

(* TODO: this is temporarily required due to staged ledger test stubs *)
module type Transaction_snark_scan_state_generalized_intf = sig
  type sok_message

  type transaction_snark_statement

  type frozen_ledger_hash

  type ledger_proof

  type ledger_undo

  type transaction

  type transaction_snark_work

  type staged_ledger_aux_hash

  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, version]

        val hash : t -> staged_ledger_aux_hash
      end

      module Latest = V1
    end
    with type V1.t = t

  module Transaction_with_witness : sig
    (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
    type t =
      { transaction_with_info: ledger_undo
      ; statement: transaction_snark_statement
      ; witness: Transaction_witness.t }
    [@@deriving sexp]
  end

  module Ledger_proof_with_sok_message : sig
    type t = ledger_proof * sok_message
  end

  module Available_job : sig
    type t [@@deriving sexp]
  end

  module Space_partition : sig
    type t = {first: int; second: int option} [@@deriving sexp]
  end

  module Job_view : sig
    type t [@@deriving sexp, to_yojson]
  end

  module type Monad_with_Or_error_intf = sig
    type 'a t

    include Monad.S with type 'a t := 'a t

    module Or_error : sig
      type nonrec 'a t = 'a Or_error.t t

      include Monad.S with type 'a t := 'a t
    end
  end

  module Make_statement_scanner
      (M : Monad_with_Or_error_intf) (Verifier : sig
          type t

          val verify :
               verifier:t
            -> proof:ledger_proof
            -> statement:transaction_snark_statement
            -> message:sok_message
            -> sexp_bool M.t
      end) : sig
    val scan_statement :
         t
      -> verifier:Verifier.t
      -> (transaction_snark_statement, [`Empty | `Error of Error.t]) result M.t

    val check_invariants :
         t
      -> verifier:Verifier.t
      -> error_prefix:string
      -> ledger_hash_end:frozen_ledger_hash
      -> ledger_hash_begin:frozen_ledger_hash sexp_option
      -> (unit, Error.t) result M.t
  end

  val empty : unit -> t

  val capacity : t -> int

  val fill_work_and_enqueue_transactions :
       t
    -> Transaction_with_witness.t list
    -> transaction_snark_work list
    -> (ledger_proof * transaction list) option Or_error.t

  val latest_ledger_proof :
    t -> (Ledger_proof_with_sok_message.t * transaction list) option

  val free_space : t -> int

  val next_k_jobs : t -> k:int -> Available_job.t list Or_error.t

  val next_jobs : t -> Available_job.t list Or_error.t

  val next_jobs_sequence : t -> Available_job.t Sequence.t Or_error.t

  val base_jobs_on_latest_tree : t -> Transaction_with_witness.t list

  val is_valid : t -> bool

  val hash : t -> staged_ledger_aux_hash

  val staged_transactions : t -> ledger_undo list

  val all_transactions : t -> transaction list Or_error.t

  val extract_from_job :
       Available_job.t
    -> ( ledger_undo * transaction_snark_statement * Transaction_witness.t
       , ledger_proof * ledger_proof )
       Either.t

  val copy : t -> t

  val partition_if_overflowing : t -> Space_partition.t

  val statement_of_job : Available_job.t -> transaction_snark_statement option

  val current_job_sequence_number : t -> int

  val snark_job_list_json : t -> string

  val all_work_to_do :
    t -> transaction_snark_statement list Sequence.t Or_error.t

  val current_job_count : t -> int

  val work_capacity : int

  val next_on_new_tree : t -> bool Or_error.t
end

module type Transaction_snark_scan_state_intf =
  Transaction_snark_scan_state_generalized_intf
  with type transaction_snark_statement := Transaction_snark.Statement.t
   and type sok_message := Sok_message.t
   and type frozen_ledger_hash := Frozen_ledger_hash.t
   and type ledger_undo := Ledger.Undo.t
   and type transaction := Transaction.t
   and type staged_ledger_aux_hash := Staged_ledger_hash.Aux_hash.t

module type Staged_ledger_generalized_intf = sig
  type t [@@deriving sexp]

  type diff

  type valid_diff

  type ledger_proof

  type verifier

  type transaction_snark_work

  type transaction_snark_work_statement

  type transaction_snark_work_checked

  type staged_ledger_hash

  type staged_ledger_aux_hash

  type transaction_snark_statement

  module Pre_diff_info :
    Staged_ledger_pre_diff_info_generalized_intf
    with type transaction_snark_work := transaction_snark_work
     and type staged_ledger_diff := diff
     and type valid_staged_ledger_diff := valid_diff

  module Scan_state : sig
    type t [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, version]

          val hash : t -> staged_ledger_aux_hash
        end

        module Latest = V1
      end
      with type V1.t = t

    module Job_view : sig
      type t [@@deriving sexp, to_yojson]
    end

    module Space_partition : sig
      type t = {first: int; second: int option} [@@deriving sexp]
    end

    val hash : t -> staged_ledger_aux_hash

    val is_valid : t -> bool

    val empty : unit -> t

    val snark_job_list_json : t -> string

    val partition_if_overflowing : t -> Space_partition.t

    val all_work_to_do :
      t -> transaction_snark_statement list Sequence.t Or_error.t

    val all_transactions : t -> Transaction.t list Or_error.t

    val work_capacity : int

    val current_job_count : t -> int
  end

  module Staged_ledger_error : sig
    type t =
      | Non_zero_fee_excess of
          Scan_state.Space_partition.t * Transaction.t list
      | Invalid_proof of
          ledger_proof * transaction_snark_statement * Public_key.Compressed.t
      | Pre_diff of Pre_diff_info.Error.t
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
    -> verifier:verifier
    -> snarked_ledger_hash:Frozen_ledger_hash.t
    -> ledger:Ledger.t
    -> scan_state:Scan_state.t
    -> pending_coinbase_collection:Pending_coinbase.t
    -> t Or_error.t Deferred.t

  val replace_ledger_exn : t -> Ledger.t -> t

  val proof_txns : t -> Transaction.t Non_empty_list.t option

  val copy : t -> t

  val hash : t -> staged_ledger_hash

  val apply :
       t
    -> diff
    -> logger:Logger.t
    -> verifier:verifier
    -> ( [`Hash_after_applying of staged_ledger_hash]
         * [`Ledger_proof of (ledger_proof * Transaction.t list) option]
         * [`Staged_ledger of t]
         * [`Pending_coinbase_data of bool * Currency.Amount.t]
       , Staged_ledger_error.t )
       Deferred.Result.t

  val apply_diff_unchecked :
       t
    -> valid_diff
    -> ( [`Hash_after_applying of staged_ledger_hash]
       * [`Ledger_proof of (ledger_proof * Transaction.t list) option]
       * [`Staged_ledger of t]
       * [`Pending_coinbase_data of bool * Currency.Amount.t] )
       Deferred.Or_error.t

  module For_tests : sig
    val materialized_snarked_ledger_hash :
         t
      -> expected_target:Frozen_ledger_hash.t
      -> Frozen_ledger_hash.t Or_error.t
  end

  val current_ledger_proof : t -> ledger_proof option

  (* This should memoize the snark verifications *)

  val create_diff :
       t
    -> self:Public_key.Compressed.t
    -> logger:Logger.t
    -> transactions_by_fee:User_command.With_valid_signature.t Sequence.t
    -> get_completed_work:(   transaction_snark_work_statement
                           -> transaction_snark_work_checked option)
    -> valid_diff

  val all_work_pairs_exn :
       t
    -> ( ( Transaction.t
         , Transaction_witness.t
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
       * ( Transaction.t
         , Transaction_witness.t
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
         option )
       list

  val statement_exn : t -> [`Non_empty of transaction_snark_statement | `Empty]

  val of_scan_state_pending_coinbases_and_snarked_ledger :
       logger:Logger.t
    -> verifier:verifier
    -> scan_state:Scan_state.t
    -> snarked_ledger:Ledger.t
    -> expected_merkle_root:Ledger_hash.t
    -> pending_coinbases:Pending_coinbase.t
    -> t Or_error.t Deferred.t
end

module type Staged_ledger_intf =
  Staged_ledger_generalized_intf
  with type staged_ledger_hash := Staged_ledger_hash.t
   and type staged_ledger_aux_hash := Staged_ledger_hash.Aux_hash.t
   and type transaction_snark_statement := Transaction_snark.Statement.t
