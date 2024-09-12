open Core_kernel
open Async_kernel
open Mina_base
open Mina_transaction
open Signature_lib
module Ledger = Mina_ledger.Ledger

type t [@@deriving sexp]

module Scan_state : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t [@@deriving sexp]

      val hash : t -> Staged_ledger_hash.Aux_hash.t
    end
  end]

  module Job_view : sig
    type t [@@deriving sexp, to_yojson]
  end

  (** Space available and number of jobs required to enqueue transactions in the scan state.

  first = space on the latest tree and number of proofs required

  second = If the space on the latest tree is less than max size (defined at compile time) then remaining number of slots for a new tree and the corresponding number of proofs required *)
  module Space_partition : sig
    type t = { first : int * int; second : (int * int) option }
    [@@deriving sexp]
  end

  module Transactions_ordered : sig
    module Poly : sig
      type 'a t =
        { first_pass : 'a list
        ; second_pass : 'a list
        ; previous_incomplete : 'a list
        ; current_incomplete : 'a list
        }
      [@@deriving sexp, to_yojson]
    end

    type t = Transaction_snark_scan_state.Transaction_with_witness.t Poly.t
    [@@deriving sexp, to_yojson]
  end

  val hash : t -> Staged_ledger_hash.Aux_hash.t

  val empty :
    constraint_constants:Genesis_constants.Constraint_constants.t -> unit -> t

  (** Statements of the required snark work *)
  val snark_job_list_json : t -> string

  (** All the transactions with hash of the parent block in which they were included in the order in which they were applied*)
  val staged_transactions_with_state_hash :
       t
    -> ( Transaction.t With_status.t
       * State_hash.t
       * Mina_numbers.Global_slot_since_genesis.t )
       Transactions_ordered.Poly.t
       list

  (** Statements of all the pending work. Fails if there are any invalid statements in the scan state [t] *)
  val all_work_statements_exn : t -> Transaction_snark_work.Statement.t list

  (** Hashes of the protocol states required for proving pending transactions*)
  val required_state_hashes : t -> State_hash.Set.t

  (** Validate protocol states required for proving the transactions. Returns an association list of state_hash and the corresponding state*)
  val check_required_protocol_states :
       t
    -> protocol_states:
         Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
    -> Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
       Or_error.t

  (** Apply transactions corresponding to the last emitted proof based on the 
    two-pass system to get snarked ledger- first pass includes legacy transactions and zkapp payments and the second pass includes account updates. This ignores any account updates if a blocks transactions were split among two trees.
    *)
  val get_snarked_ledger_sync :
       ledger:Ledger.t
    -> get_protocol_state:
         (State_hash.t -> Mina_state.Protocol_state.Value.t Or_error.t)
    -> apply_first_pass:
         (   global_slot:Mina_numbers.Global_slot_since_genesis.t
          -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
          -> Ledger.t
          -> Transaction.t
          -> Ledger.Transaction_partially_applied.t Or_error.t )
    -> apply_second_pass:
         (   Ledger.t
          -> Ledger.Transaction_partially_applied.t
          -> Ledger.Transaction_applied.t Or_error.t )
    -> apply_first_pass_sparse_ledger:
         (   global_slot:Mina_numbers.Global_slot_since_genesis.t
          -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
          -> Mina_ledger.Sparse_ledger.t
          -> Mina_transaction.Transaction.t
          -> Mina_ledger.Sparse_ledger.T.Transaction_partially_applied.t
             Or_error.t )
    -> t
    -> unit Or_error.t

  (** Apply transactions corresponding to the last emitted proof based on the 
    two-pass system to get snarked ledger- first pass includes legacy transactions and zkapp payments and the second pass includes account updates. This ignores any account updates if a blocks transactions were split among two trees.
    *)
  val get_snarked_ledger_async :
       ?async_batch_size:int
    -> ledger:Ledger.t
    -> get_protocol_state:
         (State_hash.t -> Mina_state.Protocol_state.Value.t Or_error.t)
    -> apply_first_pass:
         (   global_slot:Mina_numbers.Global_slot_since_genesis.t
          -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
          -> Ledger.t
          -> Transaction.t
          -> Ledger.Transaction_partially_applied.t Or_error.t )
    -> apply_second_pass:
         (   Ledger.t
          -> Ledger.Transaction_partially_applied.t
          -> Ledger.Transaction_applied.t Or_error.t )
    -> apply_first_pass_sparse_ledger:
         (   global_slot:Mina_numbers.Global_slot_since_genesis.t
          -> txn_state_view:Mina_base.Zkapp_precondition.Protocol_state.View.t
          -> Mina_ledger.Sparse_ledger.t
          -> Mina_transaction.Transaction.t
          -> Mina_ledger.Sparse_ledger.T.Transaction_partially_applied.t
             Or_error.t )
    -> t
    -> unit Deferred.Or_error.t
end

module Pre_diff_info : Pre_diff_info.S

module Staged_ledger_error : sig
  type t =
    | Non_zero_fee_excess of
        Scan_state.Space_partition.t * Transaction.t With_status.t list
    | Invalid_proofs of
        ( Ledger_proof.t
        * Transaction_snark.Statement.t
        * Mina_base.Sok_message.t )
        list
        * Error.t
    | Couldn't_reach_verifier of Error.t
    | Pre_diff of Pre_diff_info.Error.t
    | Insufficient_work of string
    | Mismatched_statuses of Transaction.t With_status.t * Transaction_status.t
    | Invalid_public_key of Public_key.Compressed.t
    | ZkApps_exceed_limit of int * int
    | Unexpected of Error.t
  [@@deriving sexp]

  val to_string : t -> string

  val to_error : t -> Error.t
end

val ledger : t -> Ledger.t

val scan_state : t -> Scan_state.t

val pending_coinbase_collection : t -> Pending_coinbase.t

val create_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> ledger:Ledger.t
  -> t

val replace_ledger_exn : t -> Ledger.t -> t

(** Transactions corresponding to the most recent ledger proof in t *)
val proof_txns_with_state_hashes :
     t
  -> ( Transaction.t With_status.t
     * State_hash.t
     * Mina_numbers.Global_slot_since_genesis.t )
     Scan_state.Transactions_ordered.Poly.t
     Mina_stdlib.Nonempty_list.t
     option

val copy : t -> t

val hash : t -> Staged_ledger_hash.t

val apply :
     ?skip_verification:[ `Proofs | `All ]
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> t
  -> get_completed_work:
       (   Transaction_snark_work.Statement.t
        -> Transaction_snark_work.Checked.t option )
  -> Staged_ledger_diff.t
  -> logger:Logger.t
  -> verifier:Verifier.t
  -> current_state_view:Zkapp_precondition.Protocol_state.View.t
  -> state_and_body_hash:State_hash.t * State_body_hash.t
  -> coinbase_receiver:Public_key.Compressed.t
  -> supercharge_coinbase:bool
  -> zkapp_cmd_limit_hardcap:int
  -> ( [ `Hash_after_applying of Staged_ledger_hash.t ]
       * [ `Ledger_proof of
           ( Ledger_proof.t
           * ( Transaction.t With_status.t
             * State_hash.t
             * Mina_numbers.Global_slot_since_genesis.t )
             Scan_state.Transactions_ordered.Poly.t
             list )
           option ]
       * [ `Staged_ledger of t ]
       * [ `Pending_coinbase_update of bool * Pending_coinbase.Update.t ]
     , Staged_ledger_error.t )
     Deferred.Result.t

val apply_diff_unchecked :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> t
  -> Staged_ledger_diff.With_valid_signatures_and_proofs.t
  -> logger:Logger.t
  -> current_state_view:Zkapp_precondition.Protocol_state.View.t
  -> state_and_body_hash:State_hash.t * State_body_hash.t
  -> coinbase_receiver:Public_key.Compressed.t
  -> supercharge_coinbase:bool
  -> zkapp_cmd_limit_hardcap:int
  -> ( [ `Hash_after_applying of Staged_ledger_hash.t ]
       * [ `Ledger_proof of
           ( Ledger_proof.t
           * ( Transaction.t With_status.t
             * State_hash.t
             * Mina_numbers.Global_slot_since_genesis.t )
             Scan_state.Transactions_ordered.Poly.t
             list )
           option ]
       * [ `Staged_ledger of t ]
       * [ `Pending_coinbase_update of bool * Pending_coinbase.Update.t ]
     , Staged_ledger_error.t )
     Deferred.Result.t

(** Most recent ledger proof in t *)
val current_ledger_proof : t -> Ledger_proof.t option

(* Internals of the txn application. This is only exposed to facilitate
   writing unit tests. *)
module Application_state : sig
  type txn =
    ( Signed_command.With_valid_signature.t
    , Zkapp_command.Valid.t )
    User_command.t_

  type t =
    { valid_seq : txn Sequence.t
    ; invalid : (txn * Error.t) list
    ; skipped_by_fee_payer : txn list Account_id.Map.t
    ; zkapp_space_remaining : int option
    ; total_space_remaining : int
    }

  val init : ?zkapp_limit:int -> total_limit:int -> t

  val try_applying_txn :
       ?logger:Logger.t
    -> apply:(User_command.t Transaction.t_ -> ('a, Error.t) Result.t)
    -> t
    -> txn
    -> (t, txn Sequence.t * (txn * Error.t) list) Continue_or_stop.t
end

(* This should memoize the snark verifications *)

val create_diff :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> ?log_block_creation:bool
  -> t
  -> coinbase_receiver:Public_key.Compressed.t
  -> logger:Logger.t
  -> current_state_view:Zkapp_precondition.Protocol_state.View.t
  -> zkapp_cmd_limit:int option
  -> transactions_by_fee:User_command.Valid.t Sequence.t
  -> get_completed_work:
       (   Transaction_snark_work.Statement.t
        -> Transaction_snark_work.Checked.t option )
  -> supercharge_coinbase:bool
  -> ( Staged_ledger_diff.With_valid_signatures_and_proofs.t
       * (User_command.Valid.t * Error.t) list
     , Pre_diff_info.Error.t )
     Result.t

(** A block producer is eligible if the account won the slot [winner] has no unlocked tokens at slot [global_slot] in the staking ledger [epoch_ledger] *)
val can_apply_supercharged_coinbase_exn :
     winner:Public_key.Compressed.t
  -> epoch_ledger:Mina_ledger.Sparse_ledger.t
  -> global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> bool

val of_scan_state_pending_coinbases_and_snarked_ledger :
     logger:Logger.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> verifier:Verifier.t
  -> scan_state:Scan_state.t
  -> snarked_ledger:Ledger.t
  -> snarked_local_state:Mina_state.Local_state.t
  -> expected_merkle_root:Ledger_hash.t
  -> pending_coinbases:Pending_coinbase.t
  -> get_state:(State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
  -> t Or_error.t Deferred.t

val of_scan_state_pending_coinbases_and_snarked_ledger_unchecked :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> scan_state:Scan_state.t
  -> snarked_ledger:Ledger.t
  -> snarked_local_state:Mina_state.Local_state.t
  -> expected_merkle_root:Ledger_hash.t
  -> pending_coinbases:Pending_coinbase.t
  -> get_state:(State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
  -> t Or_error.t Deferred.t

(** All the pending work in t and the data required to generate proofs. *)
val all_work_pairs :
     t
  -> get_state:(State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
  -> (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t
     One_or_two.t
     list
     Or_error.t

(** Statements of all the pending work in t*)
val all_work_statements_exn : t -> Transaction_snark_work.Statement.t list

val check_commands :
     Ledger.t
  -> verifier:Verifier.t
  -> User_command.t With_status.t list
  -> (User_command.Valid.t list, Verifier.Failure.t) Result.t
     Deferred.Or_error.t

(** account ids created in the latest block, taken from the new_accounts
    in the latest and next-to-latest trees of the scan state
*)
val latest_block_accounts_created :
  t -> previous_block_state_hash:State_hash.t -> Account_id.t list

module Test_helpers : sig
  val dummy_state_and_view :
       ?global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> unit
    -> Mina_state.Protocol_state.value
       * Zkapp_precondition.Protocol_state.View.t

  val dummy_state_view :
       ?global_slot:Mina_numbers.Global_slot_since_genesis.t
    -> unit
    -> Zkapp_precondition.Protocol_state.View.t
end
