open Core_kernel
open Async_kernel
open Pipe_lib
include Coda_transition_frontier

module type Verifier_intf = sig
  type t
end

module type Security_intf = sig
  (** In production we set this to (hopefully a prefix of) k for our consensus
   * mechanism; infinite is for tests *)
  val max_depth : [`Infinity | `Finite of int]
end

module type Time_controller_intf = sig
  type t

  val create : t -> t

  val basic : t
end

module type Sok_message_intf = sig
  type public_key_compressed

  module Digest : sig
    type t

    module Checked : sig
      type t
    end
  end

  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, bin_io, version]
    end

    module Latest = V1
  end

  (* bin_io intentionally omitted *)
  type t = Stable.Latest.t [@@deriving sexp]

  val create : fee:Currency.Fee.t -> prover:public_key_compressed -> t
end

module type Hash_intf = sig
  include Equal.S

  include Hashable.S_binable with type t := t
end

module type Time_intf = sig
  module Controller : Time_controller_intf

  type t [@@deriving sexp]

  type t0 = t

  module Unpacked : sig
    type var
  end

  module Span : sig
    type t [@@deriving compare]

    val of_time_span : Core_kernel.Time.Span.t -> t

    val to_ms : t -> Int64.t

    val of_ms : Int64.t -> t

    val ( < ) : t -> t -> bool

    val ( > ) : t -> t -> bool

    val ( >= ) : t -> t -> bool

    val ( <= ) : t -> t -> bool

    val ( = ) : t -> t -> bool
  end

  module Timeout : sig
    type 'a t

    val create : Controller.t -> Span.t -> f:(t0 -> 'a) -> 'a t

    val to_deferred : 'a t -> 'a Deferred.t

    val peek : 'a t -> 'a option

    val cancel : Controller.t -> 'a t -> 'a -> unit

    val remaining_time : 'a t -> Span.t
  end

  val to_span_since_epoch : t -> Span.t

  val of_span_since_epoch : Span.t -> t

  val diff : t -> t -> Span.t

  val sub : t -> Span.t -> t

  val add : t -> Span.t -> t

  val modulus : t -> Span.t -> Span.t

  val now : Controller.t -> t

  val to_string : t -> string

  val of_string_exn : string -> t
end

module type Ledger_hash_intf = sig
  type t [@@deriving eq, sexp, compare, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving eq, sexp, compare, bin_io, version, yojson]
      end

      module Latest = V1
    end
    with type V1.t = t

  val to_bytes : t -> string

  include Hashable.S with type t := t
end

module type Pending_coinbase_hash_intf = sig
  type t [@@deriving eq, sexp, compare, hash]

  val to_bytes : t -> string

  val empty_hash : t
end

module type Pending_coinbase_intf = sig
  type t [@@deriving sexp, bin_io]

  type pending_coinbase_hash

  type coinbase

  module Coinbase_data : sig
    type t [@@deriving bin_io, sexp]

    val empty : t

    val of_coinbase : coinbase -> t
  end

  module Stack : sig
    type t [@@deriving sexp, eq]

    val push : t -> coinbase -> t

    val empty : t
  end

  val merkle_root : t -> pending_coinbase_hash

  val update_coinbase_stack : t -> Stack.t -> is_new_stack:bool -> t Or_error.t

  val remove_coinbase_stack : t -> (Stack.t * t) Or_error.t

  val create : unit -> t Or_error.t

  val latest_stack : t -> is_new_stack:bool -> Stack.t Or_error.t

  val oldest_stack : t -> Stack.t Or_error.t

  val hash_extra : t -> string
end

module type Frozen_ledger_hash_intf = sig
  type ledger_hash

  include Ledger_hash_intf

  val of_ledger_hash : ledger_hash -> t

  val to_ledger_hash : t -> ledger_hash
end

module type Transaction_witness_intf = sig
  type sparse_ledger

  type t = {ledger: sparse_ledger} [@@deriving sexp]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, version]
    end
  end
end

module type Protocol_state_hash_intf = sig
  type t [@@deriving bin_io, sexp, eq, to_yojson]

  type var

  include Hashable.S_binable with type t := t
end

module type Protocol_state_proof_intf = sig
  type t

  val dummy : t
end

module type Staged_ledger_aux_hash_intf = sig
  type t [@@deriving bin_io, sexp, eq]

  val of_bytes : string -> t

  val to_bytes : t -> string
end

module type Staged_ledger_hash_intf = sig
  type t [@@deriving sexp, eq, compare]

  type var

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving bin_io, sexp, eq, compare, version]

        include Hashable.S_binable with type t := t
      end
    end
    with type V1.t = t

  type ledger_hash

  type staged_ledger_aux_hash

  type pending_coinbase

  type pending_coinbase_hash

  val ledger_hash : t -> ledger_hash

  val aux_hash : t -> staged_ledger_aux_hash

  val pending_coinbase_hash : t -> pending_coinbase_hash

  val of_aux_ledger_and_coinbase_hash :
    staged_ledger_aux_hash -> ledger_hash -> pending_coinbase -> t
end

module type Proof_intf = sig
  type input

  type t

  val verify : t -> input -> bool Deferred.t
end

module type Mask_intf = sig
  type t [@@deriving bin_io]

  val create : unit -> t
end

module type Mask_serializable_intf = sig
  type t

  type unattached_mask

  type serializable [@@deriving bin_io]

  val unattached_mask_of_serializable : serializable -> unattached_mask

  val serializable_of_t : t -> serializable
end

module type Ledger_creatable_intf = sig
  type t

  val create : ?directory_name:string -> unit -> t
end

module type Ledger_transfer_intf = sig
  type src

  type dest

  val transfer_accounts : src:src -> dest:dest -> dest
end

module type Ledger_intf = sig
  include Ledger_creatable_intf

  module Mask : Mask_intf

  type attached_mask = t

  type unattached_mask = Mask.t

  type maskable_ledger = t

  type transaction

  type valid_user_command

  type ledger_hash

  type account

  (* for masks, serializable is same as t *)
  include
    Mask_serializable_intf
    with type t := t
     and type unattached_mask := unattached_mask

  module Undo : sig
    type t [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, version]
        end

        module Latest = V1
      end
      with type V1.t = t

    val transaction : t -> transaction Or_error.t
  end

  val create : ?directory_name:string -> unit -> t

  val copy : t -> t

  val commit : attached_mask -> unit

  val num_accounts : t -> int

  val merkle_root : t -> ledger_hash

  val to_list : t -> account list

  val apply_transaction : t -> transaction -> Undo.t Or_error.t

  val undo : t -> Undo.t -> unit Or_error.t

  val register_mask : maskable_ledger -> unattached_mask -> attached_mask

  val unregister_mask_exn : maskable_ledger -> attached_mask -> unattached_mask

  val remove_and_reparent_exn :
    t -> attached_mask -> children:attached_mask list -> unit
end

module Fee = struct
  module Unsigned = struct
    include Currency.Fee

    include (
      Currency.Fee.Stable.V1 :
        module type of Currency.Fee.Stable.Latest with type t := t )
  end

  module Signed = struct
    include Currency.Fee.Signed

    include (
      Currency.Fee.Signed.Stable.V1 :
        module type of Currency.Fee.Signed.Stable.Latest with type t := t )
  end
end

module type Snark_pool_proof_intf = sig
  module Statement : sig
    type t [@@deriving sexp, bin_io, yojson]
  end

  type t [@@deriving sexp, bin_io, yojson]
end

module type User_command_intf = sig
  type t [@@deriving sexp, eq, yojson]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, eq, yojson, version]
    end
  end

  type public_key

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp, eq, yojson]
  end

  val check : t -> With_valid_signature.t option

  val fee : t -> Fee.Unsigned.t

  val sender : t -> public_key

  val accounts_accessed : t -> public_key list
end

module type Private_key_intf = sig
  type t
end

module type Compressed_public_key_intf = sig
  type t [@@deriving sexp, compare, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, compare, yojson, version]
      end
    end
    with type V1.t = t

  include Comparable.S with type t := t

  type var

  val empty : t
end

module type Public_key_intf = sig
  module Private_key : Private_key_intf

  type t [@@deriving sexp, yojson]

  module Compressed : Compressed_public_key_intf

  val of_private_key_exn : Private_key.t -> t

  val compress : t -> Compressed.t
end

module type Keypair_intf = sig
  type private_key

  type public_key

  type t = {public_key: public_key; private_key: private_key}
end

module type Fee_transfer_intf = sig
  type t [@@deriving sexp, compare, eq, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, compare, eq, yojson]
      end
    end
    with type V1.t = t

  type public_key

  module Single : sig
    type t = public_key * Fee.Unsigned.t [@@deriving sexp, yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, yojson, version]
        end
      end
      with type V1.t = t
  end

  val of_single : Single.t -> t

  val of_single_list : Single.t list -> t list

  val receivers : t -> public_key list
end

module type Coinbase_intf = sig
  type public_key

  type fee_transfer

  type t = private
    { proposer: public_key
    ; amount: Currency.Amount.t
    ; fee_transfer: fee_transfer option }
  [@@deriving sexp, compare, eq]

  val create :
       amount:Currency.Amount.t
    -> proposer:public_key
    -> fee_transfer:fee_transfer option
    -> t Or_error.t
end

module type Transaction_intf = sig
  type valid_user_command

  type fee_transfer

  type coinbase

  type t =
    | User_command of valid_user_command
    | Fee_transfer of fee_transfer
    | Coinbase of coinbase
  [@@deriving sexp, compare, eq, bin_io]

  val fee_excess : t -> Fee.Signed.t Or_error.t

  val supply_increase : t -> Currency.Amount.t Or_error.t
end

module type Pending_coinbase_stack_state_intf = sig
  type pending_coinbase_stack

  type t = {source: pending_coinbase_stack; target: pending_coinbase_stack}
  [@@deriving sexp, compare]
end

module type Ledger_proof_statement_intf = sig
  type ledger_hash

  type pending_coinbase_stack_state

  type t =
    { source: ledger_hash
    ; target: ledger_hash
    ; supply_increase: Currency.Amount.t
    ; pending_coinbase_stack_state: pending_coinbase_stack_state
    ; fee_excess: Fee.Signed.t
    ; proof_type: [`Base | `Merge] }
  [@@deriving sexp, compare]

  module Stable :
    sig
      module V1 : sig
        type t =
          { source: ledger_hash
          ; target: ledger_hash
          ; supply_increase: Currency.Amount.t
          ; pending_coinbase_stack_state: pending_coinbase_stack_state
          ; fee_excess: Fee.Signed.t
          ; proof_type: [`Base | `Merge] }
        [@@deriving sexp, bin_io, compare, version]
      end
    end
    with type V1.t = t

  val merge : t -> t -> t Or_error.t

  include Comparable.S with type t := t
end

module type Ledger_proof_intf = sig
  type ledger_hash

  type statement

  type proof

  type sok_digest

  (* bin_io omitted intentionally *)
  type t [@@deriving sexp, yojson]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, yojson, version]
      end

      module Latest = V1
    end
    with type V1.t = t

  val create : statement:statement -> sok_digest:sok_digest -> proof:proof -> t

  val statement_target : statement -> ledger_hash

  val statement : t -> statement

  val sok_digest : t -> sok_digest

  val underlying_proof : t -> proof
end

module type Ledger_proof_verifier_intf = sig
  type t

  type ledger_proof

  type message

  val verify_transaction_snark :
    t -> ledger_proof -> message:message -> bool Deferred.Or_error.t
end

module Work_selection = struct
  type t = Seq | Random [@@deriving bin_io]
end

module type Transaction_snark_work_intf = sig
  type proof

  type statement

  type public_key

  module Statement : sig
    type t = statement list [@@deriving yojson]

    include Sexpable.S with type t := t

    include Hashable.S with type t := t

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving yojson, version]

          include Sexpable.S with type t := t

          include Binable.S with type t := t

          include Hashable.S_binable with type t := t
        end
      end
      with type V1.t = t

    val gen : t Quickcheck.Generator.t
  end

  (* TODO: The SOK message actually should bind the SNARK to
     be in this particular bundle. The easiest way would be to
     SOK with
     H(all_statements_in_bundle || fee || public_key)
  *)

  type t =
    {fee: Fee.Unsigned.Stable.V1.t; proofs: proof list; prover: public_key}
  [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io, version]
      end
    end
    with type V1.t = t

  type unchecked = t

  module Checked : sig
    type nonrec t = t =
      {fee: Fee.Unsigned.t; proofs: proof list; prover: public_key}
    [@@deriving sexp]

    module Stable : module type of Stable

    val create_unsafe : unchecked -> t
  end

  val forget : Checked.t -> t

  val proofs_length : int
end

module type Staged_ledger_diff_intf = sig
  type user_command

  type user_command_with_valid_signature

  type staged_ledger_hash

  type public_key

  type completed_work

  type completed_work_checked

  type fee_transfer_single = public_key * Fee.Unsigned.t

  module At_most_two : sig
    type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type 'a t [@@deriving sexp, bin_io, version]
        end
      end
      with type 'a V1.t = 'a t

    val increase : 'a t -> 'a list -> 'a t Or_error.t
  end

  module At_most_one : sig
    type 'a t = Zero | One of 'a option [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type 'a t [@@deriving sexp, bin_io, version]
        end
      end
      with type 'a V1.t = 'a t

    val increase : 'a t -> 'a list -> 'a t Or_error.t
  end

  module Pre_diff_with_at_most_two_coinbase : sig
    type t =
      { completed_works: completed_work list
      ; user_commands: user_command list
      ; coinbase: fee_transfer_single At_most_two.Stable.V1.t }
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, version]
        end
      end
      with type V1.t = t
  end

  module Pre_diff_with_at_most_one_coinbase : sig
    type t =
      { completed_works: completed_work list
      ; user_commands: user_command list
      ; coinbase: fee_transfer_single At_most_one.t }
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, version]
        end
      end
      with type V1.t = t
  end

  module Diff : sig
    type t =
      Pre_diff_with_at_most_two_coinbase.Stable.V1.t
      * Pre_diff_with_at_most_one_coinbase.Stable.V1.t option
    [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, version]
        end
      end
      with type V1.t = t
  end

  type t = {diff: Diff.t; prev_hash: staged_ledger_hash; creator: public_key}
  [@@deriving sexp, fields]

  module Stable :
    sig
      module V1 : sig
        type t =
          {diff: Diff.t; prev_hash: staged_ledger_hash; creator: public_key}
        [@@deriving sexp, bin_io, version]
      end

      module Latest = V1
    end
    with type V1.t = t

  module With_valid_signatures_and_proofs : sig
    type pre_diff_with_at_most_two_coinbase =
      { completed_works: completed_work_checked list
      ; user_commands: user_command_with_valid_signature list
      ; coinbase: fee_transfer_single At_most_two.t }
    [@@deriving sexp]

    type pre_diff_with_at_most_one_coinbase =
      { completed_works: completed_work_checked list
      ; user_commands: user_command_with_valid_signature list
      ; coinbase: fee_transfer_single At_most_one.t }
    [@@deriving sexp]

    type diff =
      pre_diff_with_at_most_two_coinbase
      * pre_diff_with_at_most_one_coinbase option
    [@@deriving sexp]

    type t = {diff: diff; prev_hash: staged_ledger_hash; creator: public_key}
    [@@deriving sexp]

    val user_commands : t -> user_command_with_valid_signature list
  end

  val forget : With_valid_signatures_and_proofs.t -> t

  val user_commands : t -> user_command list

  val completed_works : t -> completed_work list

  val coinbase : t -> Currency.Amount.t
end

module type Staged_ledger_transition_intf = sig
  type staged_ledger

  type diff

  type diff_with_valid_signatures_and_proofs

  type t = {old: staged_ledger; diff: diff}

  module With_valid_signatures_and_proofs : sig
    type t = {old: staged_ledger; diff: diff_with_valid_signatures_and_proofs}
  end

  val forget : With_valid_signatures_and_proofs.t -> t
end

module type Monad_with_Or_error_intf = sig
  type 'a t

  include Monad.S with type 'a t := 'a t

  module Or_error : sig
    type nonrec 'a t = 'a Or_error.t t

    include Monad.S with type 'a t := 'a t
  end
end

module type Transaction_snark_scan_state_intf = sig
  type ledger

  type ledger_proof_statement

  type sparse_ledger

  type sok_message

  type transaction

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

  type ledger_proof

  type transaction_snark_work

  type transaction_snark_work_statement

  type transaction_with_info

  type frozen_ledger_hash

  type transaction_witness

  module Transaction_with_witness : sig
    (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
    type t =
      { transaction_with_info: transaction_with_info
      ; statement: ledger_proof_statement
      ; witness: transaction_witness }
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

  module Make_statement_scanner
      (M : Monad_with_Or_error_intf) (Verifier : sig
          type t

          val verify :
               verifier:t
            -> proof:ledger_proof
            -> statement:ledger_proof_statement
            -> message:sok_message
            -> sexp_bool M.t
      end) : sig
    val scan_statement :
         t
      -> verifier:Verifier.t
      -> (ledger_proof_statement, [`Empty | `Error of Error.t]) result M.t

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

  val staged_transactions : t -> transaction_with_info list

  val all_transactions : t -> transaction list Or_error.t

  val extract_from_job :
       Available_job.t
    -> ( transaction_with_info * ledger_proof_statement * transaction_witness
       , ledger_proof * ledger_proof )
       Either.t

  val copy : t -> t

  val partition_if_overflowing : t -> Space_partition.t

  val statement_of_job : Available_job.t -> ledger_proof_statement option

  val current_job_sequence_number : t -> int

  val snark_job_list_json : t -> string

  val all_work_to_do :
    t -> transaction_snark_work_statement Sequence.t Or_error.t

  val current_job_count : t -> int

  val work_capacity : int

  val next_on_new_tree : t -> bool Or_error.t
end

module Pre_diff_error = struct
  type 'user_command t =
    | Bad_signature of 'user_command
    | Coinbase_error of string
    | Insufficient_fee of Currency.Fee.t * Currency.Fee.t
    | Unexpected of Error.t
  [@@deriving sexp]

  let to_string user_command_to_sexp = function
    | Bad_signature t ->
        Format.asprintf
          !"Bad signature of the user command: %{sexp: Sexp.t} \n"
          (user_command_to_sexp t)
    | Coinbase_error err ->
        Format.asprintf !"Coinbase error: %s \n" err
    | Insufficient_fee (f1, f2) ->
        Format.asprintf
          !"Transaction fee %{sexp: Currency.Fee.t} does not suffice proof \
            fee %{sexp: Currency.Fee.t} \n"
          f1 f2
    | Unexpected e ->
        Error.to_string_hum e

  let to_error user_command_to_sexp =
    Fn.compose Error.of_string (to_string user_command_to_sexp)
end

module type Staged_ledger_base_intf = sig
  type t [@@deriving sexp]

  type diff

  type valid_diff

  type staged_ledger_aux_hash

  type staged_ledger_hash

  type frozen_ledger_hash

  type ledger_proof

  type user_command

  type statement

  type transaction

  type transaction_witness

  (** The ledger in a staged ledger is always a mask *)
  type ledger

  type ledger_proof_statement

  type public_key

  type verifier

  type pending_coinbase_collection

  type serializable [@@deriving bin_io]

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

    val all_work_to_do : t -> statement Sequence.t Or_error.t

    val all_transactions : t -> transaction list Or_error.t

    val work_capacity : int

    val current_job_count : t -> int
  end

  module Staged_ledger_error : sig
    type t =
      | Bad_prev_hash of staged_ledger_hash * staged_ledger_hash
      | Non_zero_fee_excess of Scan_state.Space_partition.t * transaction list
      | Invalid_proof of ledger_proof * ledger_proof_statement * public_key
      | Pre_diff of user_command Pre_diff_error.t
      | Unexpected of Error.t
    [@@deriving sexp]

    val to_string : t -> string

    val to_error : t -> Error.t
  end

  val ledger : t -> ledger

  val scan_state : t -> Scan_state.t

  val pending_coinbase_collection : t -> pending_coinbase_collection

  val create_exn : ledger:ledger -> t

  val of_scan_state_and_ledger :
       logger:Logger.t
    -> verifier:verifier
    -> snarked_ledger_hash:frozen_ledger_hash
    -> ledger:ledger
    -> scan_state:Scan_state.t
    -> pending_coinbase_collection:pending_coinbase_collection
    -> t Or_error.t Deferred.t

  val of_serialized_and_unserialized :
    serialized:serializable -> unserialized:ledger -> t

  val replace_ledger_exn : t -> ledger -> t

  val proof_txns : t -> transaction Non_empty_list.t option

  val copy : t -> t

  val hash : t -> staged_ledger_hash

  val serializable_of_t : t -> serializable

  val apply :
       t
    -> diff
    -> logger:Logger.t
    -> verifier:verifier
    -> ( [`Hash_after_applying of staged_ledger_hash]
         * [`Ledger_proof of (ledger_proof * transaction list) option]
         * [`Staged_ledger of t]
         * [`Pending_coinbase_data of bool * Currency.Amount.t]
       , Staged_ledger_error.t )
       Deferred.Result.t

  val apply_diff_unchecked :
       t
    -> valid_diff
    -> ( [`Hash_after_applying of staged_ledger_hash]
       * [`Ledger_proof of (ledger_proof * transaction list) option]
       * [`Staged_ledger of t]
       * [`Pending_coinbase_data of bool * Currency.Amount.t] )
       Deferred.Or_error.t

  module For_tests : sig
    val snarked_ledger :
      t -> snarked_ledger_hash:frozen_ledger_hash -> ledger Or_error.t
  end
end

module type Pre_diff_info_intf = sig
  type user_command

  type transaction

  type completed_work

  type staged_ledger_diff

  type valid_staged_ledger_diff

  val get :
       staged_ledger_diff
    -> ( transaction list * completed_work list * int * Currency.Amount.t list
       , user_command Pre_diff_error.t )
       result

  val get_unchecked :
       valid_staged_ledger_diff
    -> transaction list * completed_work list * Currency.Amount.t list

  val get_transactions :
       staged_ledger_diff
    -> (transaction list, user_command Pre_diff_error.t) result
end

module type Staged_ledger_intf = sig
  include Staged_ledger_base_intf

  type ledger_hash

  type user_command_with_valid_signature

  type ledger_proof_statement_set

  type sparse_ledger

  type completed_work_checked

  module Pre_diff_info :
    Pre_diff_info_intf
    with type user_command := user_command
     and type transaction := transaction
     and type completed_work := completed_work_checked
     and type staged_ledger_diff := diff
     and type valid_staged_ledger_diff := valid_diff

  val current_ledger_proof : t -> ledger_proof option

  (* This should memoize the snark verifications *)

  val create_diff :
       t
    -> self:public_key
    -> logger:Logger.t
    -> transactions_by_fee:user_command_with_valid_signature Sequence.t
    -> get_completed_work:(statement -> completed_work_checked option)
    -> valid_diff

  val all_work_pairs_exn :
       t
    -> ( ( ledger_proof_statement
         , transaction
         , transaction_witness
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
       * ( ledger_proof_statement
         , transaction
         , transaction_witness
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
         option )
       list

  val statement_exn : t -> [`Non_empty of ledger_proof_statement | `Empty]

  val of_scan_state_pending_coinbases_and_snarked_ledger :
       logger:Logger.t
    -> verifier:verifier
    -> scan_state:Scan_state.t
    -> snarked_ledger:ledger
    -> expected_merkle_root:ledger_hash
    -> pending_coinbases:pending_coinbase_collection
    -> t Or_error.t Deferred.t
end

module type Work_selector_intf = sig
  type staged_ledger

  type work

  type snark_pool

  type fee

  module State : sig
    type t

    val init : t
  end

  val work :
       snark_pool:snark_pool
    -> fee:fee
    -> staged_ledger
    -> State.t
    -> work list * State.t
end

module type Consensus_state_intf = sig
  module Value : sig
    type t

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving bin_io]
        end
      end
      with type V1.t = t
  end

  type var
end

module type Pending_coinbase_witness_intf = sig
  type pending_coinbases

  type t = {pending_coinbases: pending_coinbases; is_new_stack: bool}
end

module type Consensus_transition_intf = sig
  module Value : sig
    type t
  end

  type var
end

module type Blockchain_state_intf = sig
  type staged_ledger_hash

  type staged_ledger_hash_var

  type frozen_ledger_hash

  type frozen_ledger_hash_var

  type time

  type time_var

  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t
        [@@deriving sexp, bin_io]
      end
    end

    type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
      ('staged_ledger_hash, 'snarked_ledger_hash, 'time) Stable.V1.t
    [@@deriving sexp]
  end

  module Value : sig
    module Stable : sig
      module V1 : sig
        type t = (staged_ledger_hash, frozen_ledger_hash, time) Poly.t
        [@@deriving sexp, bin_io]
      end
    end

    type t = Stable.V1.t [@@deriving sexp]
  end

  type var = (staged_ledger_hash_var, frozen_ledger_hash_var, time_var) Poly.t

  val create_value :
       staged_ledger_hash:staged_ledger_hash
    -> snarked_ledger_hash:frozen_ledger_hash
    -> timestamp:time
    -> Value.t

  val staged_ledger_hash :
    ('staged_ledger_hash, _, _) Poly.t -> 'staged_ledger_hash

  val snarked_ledger_hash :
    (_, 'frozen_ledger_hash, _) Poly.t -> 'frozen_ledger_hash

  val timestamp : (_, _, 'time) Poly.t -> 'time
end

module type Protocol_state_intf = sig
  type state_hash

  type state_hash_var

  type blockchain_state

  type blockchain_state_var

  type consensus_state

  type consensus_state_var

  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('state_hash, 'body) t
        [@@deriving eq, bin_io, hash, sexp, to_yojson, version]
      end

      module Latest = V1
    end

    type ('state_hash, 'body) t = ('state_hash, 'body) Stable.Latest.t
    [@@deriving sexp]
  end

  module Body : sig
    module Poly : sig
      module Stable : sig
        module V1 : sig
          type ('blockchain_state, 'consensus_state) t
          [@@deriving bin_io, sexp]
        end

        module Latest = V1
      end

      type ('blockchain_state, 'consensus_state) t =
        ('blockchain_state, 'consensus_state) Stable.V1.t
      [@@deriving sexp]
    end

    module Value : sig
      module Stable : sig
        module V1 : sig
          type t = (blockchain_state, consensus_state) Poly.Stable.V1.t
          [@@deriving bin_io, sexp, to_yojson]
        end
      end
    end

    type var = (blockchain_state_var, consensus_state_var) Poly.Stable.V1.t
  end

  module Value : sig
    module Stable : sig
      module V1 : sig
        type t = (state_hash, Body.Value.Stable.V1.t) Poly.Stable.V1.t
        [@@deriving sexp, bin_io, eq, compare]
      end

      module Latest = V1
    end

    (* bin_io omitted *)
    type t = Stable.V1.t [@@deriving sexp, eq, compare]
  end

  type var = (state_hash_var, Body.var) Poly.t

  val create_value :
       previous_state_hash:state_hash
    -> blockchain_state:blockchain_state
    -> consensus_state:consensus_state
    -> Value.t

  val previous_state_hash : ('state_hash, _) Poly.t -> 'state_hash

  val body : (_, 'body) Poly.t -> 'body

  val blockchain_state :
    (_, ('blockchain_state, _) Body.Poly.t) Poly.t -> 'blockchain_state

  val consensus_state :
    (_, (_, 'consensus_state) Body.Poly.t) Poly.t -> 'consensus_state

  val hash : Value.t -> state_hash
end

module type Snark_transition_intf = sig
  type blockchain_state_var

  type consensus_transition_var

  type sok_digest_var

  type amount_var

  type public_key_var

  module Poly : sig
    type ( 'blockchain_state
         , 'consensus_transition
         , 'sok_digest
         , 'amount
         , 'public_key )
         t
    [@@deriving sexp]
  end

  module Value : sig
    type t [@@deriving sexp]
  end

  type var =
    ( blockchain_state_var
    , consensus_transition_var
    , sok_digest_var
    , amount_var
    , public_key_var )
    Poly.t

  val consensus_transition :
    (_, 'consensus_transition, _, _, _) Poly.t -> 'consensus_transition
end

module type Internal_transition_intf = sig
  type snark_transition

  type staged_ledger_diff

  type prover_state

  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io]
      end

      module Latest = V1
    end
    with type V1.t = t

  val create :
       snark_transition:snark_transition
    -> prover_state:prover_state
    -> staged_ledger_diff:staged_ledger_diff
    -> t

  val snark_transition : t -> snark_transition

  val prover_state : t -> prover_state

  val staged_ledger_diff : t -> staged_ledger_diff
end

module type External_transition_base_intf = sig
  type state_hash

  type compressed_public_key

  type user_command

  type consensus_state

  type protocol_state

  type proof

  type staged_ledger_diff

  (* TODO: delegate forget here *)
  type t [@@deriving sexp, compare, to_yojson]

  type external_transition = t

  include Comparable.S with type t := t

  module Stable : sig
    module V1 : sig
      type t = external_transition
      [@@deriving sexp, eq, bin_io, to_yojson, version]
    end

    module Latest = V1
  end

  val protocol_state : t -> protocol_state

  val protocol_state_proof : t -> proof

  val staged_ledger_diff : t -> staged_ledger_diff

  val parent_hash : t -> state_hash

  val consensus_state : t -> consensus_state

  val proposer : t -> compressed_public_key

  val user_commands : t -> user_command list

  val payments : t -> user_command list
end

module type External_transition_intf = sig
  type time

  type state_hash

  type compressed_public_key

  type user_command

  type consensus_state

  type protocol_state

  type proof

  type verifier

  type staged_ledger_diff

  type staged_ledger_hash

  type ledger_proof

  type transaction

  include
    External_transition_base_intf
    with type state_hash := state_hash
     and type compressed_public_key := compressed_public_key
     and type user_command := user_command
     and type consensus_state := consensus_state
     and type protocol_state := protocol_state
     and type proof := proof
     and type staged_ledger_diff := staged_ledger_diff

  module Validated : sig
    type t

    val create_unsafe :
      external_transition -> [`I_swear_this_is_safe_see_my_comment of t]

    val forget_validation : t -> external_transition

    include
      External_transition_base_intf
      with type state_hash := state_hash
       and type compressed_public_key := compressed_public_key
       and type user_command := user_command
       and type consensus_state := consensus_state
       and type protocol_state := protocol_state
       and type proof := proof
       and type staged_ledger_diff := staged_ledger_diff
       and type t := t
  end

  module Validation : sig
    type ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         t =
      'time_received * 'proof * 'frontier_dependencies * 'staged_ledger_diff
      constraint 'time_received = [`Time_received] * _ Truth.t
      constraint 'proof = [`Proof] * _ Truth.t
      constraint 'frontier_dependencies = [`Frontier_dependencies] * _ Truth.t
      constraint 'staged_ledger_diff = [`Staged_ledger_diff] * _ Truth.t

    type 'a all =
      ( [`Time_received] * 'a
      , [`Proof] * 'a
      , [`Frontier_dependencies] * 'a
      , [`Staged_ledger_diff] * 'a )
      t
      constraint 'a = _ Truth.t

    type fully_invalid = Truth.false_t all

    type fully_valid = Truth.true_t all

    type ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         with_transition =
      (external_transition, state_hash) With_hash.t
      * ('time_received, 'proof, 'frontier_dependencies, 'staged_ledger_diff) t

    val fully_valid : fully_valid

    val fully_invalid : fully_invalid

    val wrap :
         (external_transition, state_hash) With_hash.t
      -> (external_transition, state_hash) With_hash.t * fully_invalid

    val lift :
         (external_transition, state_hash) With_hash.t * fully_valid
      -> (Validated.t, state_hash) With_hash.t

    val lower :
         (Validated.t, state_hash) With_hash.t
      -> ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         t
      -> ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         with_transition
  end

  type with_initial_validation =
    ( [`Time_received] * Truth.true_t
    , [`Proof] * Truth.true_t
    , [`Frontier_dependencies] * Truth.false_t
    , [`Staged_ledger_diff] * Truth.false_t )
    Validation.with_transition

  val create :
       protocol_state:protocol_state
    -> protocol_state_proof:proof
    -> staged_ledger_diff:staged_ledger_diff
    -> t

  val timestamp : t -> time

  val skip_time_received_validation :
       [`This_transition_was_not_received_via_gossip]
    -> ( [`Time_received] * Truth.false_t
       , 'proof
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( [`Time_received] * Truth.true_t
       , 'proof
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition

  val validate_time_received :
       ( [`Time_received] * Truth.false_t
       , 'proof
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> time_received:time
    -> ( ( [`Time_received] * Truth.true_t
         , 'proof
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         Validation.with_transition
       , [`Invalid_time_received of [`Too_early | `Too_late of int64]] )
       Result.t

  val skip_proof_validation :
       [`This_transition_was_generated_internally]
    -> ( 'time_received
       , [`Proof] * Truth.false_t
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( 'time_received
       , [`Proof] * Truth.true_t
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition

  val validate_proof :
       ( 'time_received
       , [`Proof] * Truth.false_t
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> verifier:verifier
    -> ( ( 'time_received
         , [`Proof] * Truth.true_t
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         Validation.with_transition
       , [`Invalid_proof | `Verifier_error of Error.t] )
       Deferred.Result.t

  (* This functor is necessary to break the dependency cycle between the Transition_fronter and the External_transition *)
  module Transition_frontier_validation (Transition_frontier : sig
    type t

    module Breadcrumb : sig
      type t

      val transition_with_hash : t -> (Validated.t, state_hash) With_hash.t
    end

    val root : t -> Breadcrumb.t

    val find : t -> state_hash -> Breadcrumb.t option
  end) : sig
    val validate_frontier_dependencies :
         ( 'time_received
         , 'proof
         , [`Frontier_dependencies] * Truth.false_t
         , 'staged_ledger_diff )
         Validation.with_transition
      -> logger:Logger.t
      -> frontier:Transition_frontier.t
      -> ( ( 'time_received
           , 'proof
           , [`Frontier_dependencies] * Truth.true_t
           , 'staged_ledger_diff )
           Validation.with_transition
         , [ `Already_in_frontier
           | `Parent_missing_from_frontier
           | `Not_selected_over_frontier_root ] )
         Result.t
  end

  val skip_frontier_dependencies_validation :
       [`This_transition_belongs_to_a_detached_subtree]
    -> ( 'time_received
       , 'proof
       , [`Frontier_dependencies] * Truth.false_t
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( 'time_received
       , 'proof
       , [`Frontier_dependencies] * Truth.true_t
       , 'staged_ledger_diff )
       Validation.with_transition

  (* TODO: this functor can be killed once Staged_ledger is defunctor *)
  module Staged_ledger_validation (Staged_ledger : sig
    type t

    module Staged_ledger_error : sig
      type t
    end

    val apply :
         t
      -> staged_ledger_diff
      -> logger:Logger.t
      -> verifier:verifier
      -> ( [`Hash_after_applying of staged_ledger_hash]
           * [`Ledger_proof of (ledger_proof * transaction list) option]
           * [`Staged_ledger of t]
           * [`Pending_coinbase_data of bool * Currency.Amount.t]
         , Staged_ledger_error.t )
         Deferred.Result.t

    val current_ledger_proof : t -> ledger_proof option
  end) : sig
    val validate_staged_ledger_diff :
         ( 'time_received
         , 'proof
         , 'frontier_dependencies
         , [`Staged_ledger_diff] * Truth.false_t )
         Validation.with_transition
      -> logger:Logger.t
      -> verifier:verifier
      -> parent_staged_ledger:Staged_ledger.t
      -> ( [`Just_emitted_a_proof of bool]
           * [ `External_transition_with_validation of
               ( 'time_received
               , 'proof
               , 'frontier_dependencies
               , [`Staged_ledger_diff] * Truth.true_t )
               Validation.with_transition ]
           * [`Staged_ledger of Staged_ledger.t]
         , [ `Invalid_staged_ledger_diff of
             [ `Incorrect_target_staged_ledger_hash
             | `Incorrect_target_snarked_ledger_hash ]
             list
           | `Staged_ledger_application_failed of
             Staged_ledger.Staged_ledger_error.t ] )
         Deferred.Result.t
  end
end

module type Prover_state_intf = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io]
    end

    module Latest : module type of V1
  end

  type t = Stable.V1.t
end

module type Time_close_validator_intf = sig
  type time

  val validate : time -> bool
end

module type Machine_intf = sig
  type t

  type state

  type transition

  type staged_ledger_transition

  module Event : sig
    type e = Found of transition | New_state of state

    type t = e * staged_ledger_transition
  end

  val current_state : t -> state

  val create : initial:state -> t

  val step : t -> transition -> t

  val drive :
       t
    -> scan:(   init:t
             -> f:(t -> Event.t -> t Deferred.t)
             -> t Linear_pipe.Reader.t)
    -> t Linear_pipe.Reader.t
end

module type Block_state_transition_proof_intf = sig
  type protocol_state

  type protocol_state_proof

  type internal_transition

  module Witness : sig
    type t =
      { old_state: protocol_state
      ; old_proof: protocol_state_proof
      ; transition: internal_transition }
  end

  (*
Blockchain_snark ~old ~nonce ~ledger_snark ~ledger_hash ~timestamp ~new_hash
  Input:
    old : Blockchain.t
    old_snark : proof
    nonce : int
    work_snark : proof
    ledger_hash : Ledger_hash.t
    timestamp : Time.t
    new_hash : State_hash.t
  Witness:
    transition : Transition.t
  such that
    the old_snark verifies against old
    new = update_with_asserts(old, nonce, timestamp, ledger_hash)
    hash(new) = new_hash
    the work_snark verifies against the old.ledger_hash and new_ledger_hash
    new.timestamp > old.timestamp
    hash(new_hash||nonce) < target(old.next_difficulty)
  *)
  (* TODO: Why is this taking new_state? *)

  val prove_zk_state_valid :
    Witness.t -> new_state:protocol_state -> protocol_state_proof Deferred.t
end

module type Transaction_validator_intf = sig
  type ledger

  type outer_ledger

  type transaction

  type user_command_with_valid_signature

  type ledger_hash

  val create : outer_ledger -> ledger

  val apply_user_command :
    ledger -> user_command_with_valid_signature -> unit Or_error.t

  val apply_transaction : ledger -> transaction -> unit Or_error.t
end

module type Inputs_intf = sig
  module Time : Time_intf

  module Verifier : Verifier_intf

  module Private_key : Private_key_intf

  module Compressed_public_key : Compressed_public_key_intf

  module Public_key :
    Public_key_intf
    with module Private_key := Private_key
     and module Compressed = Compressed_public_key

  module Keypair :
    Keypair_intf
    with type private_key := Private_key.t
     and type public_key := Public_key.t

  module User_command :
    User_command_intf with type public_key := Public_key.Compressed.t

  module Fee_transfer :
    Fee_transfer_intf with type public_key := Public_key.Compressed.t

  module Coinbase :
    Coinbase_intf
    with type public_key := Public_key.Compressed.t
     and type fee_transfer := Fee_transfer.Single.t

  module Transaction :
    Transaction_intf
    with type valid_user_command := User_command.With_valid_signature.t
     and type fee_transfer := Fee_transfer.t
     and type coinbase := Coinbase.t

  module Ledger_hash : Ledger_hash_intf

  module Frozen_ledger_hash : sig
    include Ledger_hash_intf

    type var

    val of_ledger_hash : Ledger_hash.t -> t
  end

  module Pending_coinbase_hash : Pending_coinbase_hash_intf

  module Pending_coinbase :
    Pending_coinbase_intf
    with type pending_coinbase_hash := Pending_coinbase_hash.t
     and type coinbase := Coinbase.t

  module Proof : sig
    type t
  end

  module Sok_message :
    Sok_message_intf with type public_key_compressed := Public_key.Compressed.t

  module Pending_coinbase_stack_state :
    Pending_coinbase_stack_state_intf
    with type pending_coinbase_stack := Pending_coinbase.Stack.t

  module Ledger_proof_statement :
    Ledger_proof_statement_intf
    with type ledger_hash := Frozen_ledger_hash.t
     and type pending_coinbase_stack_state := Pending_coinbase_stack_state.t

  module Ledger_proof :
    Ledger_proof_intf
    with type ledger_hash := Frozen_ledger_hash.t
     and type statement := Ledger_proof_statement.t
     and type proof := Proof.t
     and type sok_digest := Sok_message.Digest.t

  module Ledger_proof_verifier :
    Ledger_proof_verifier_intf
    with type message := Sok_message.t
     and type ledger_proof := Ledger_proof.t

  module Account : sig
    type t

    val public_key : t -> Public_key.Compressed.t
  end

  module Ledger :
    Ledger_intf
    with type valid_user_command := User_command.With_valid_signature.t
     and type transaction := Transaction.t
     and type ledger_hash := Ledger_hash.t
     and type account := Account.t

  module Genesis_ledger : sig
    val t : Ledger.t

    val accounts : (Private_key.t option * Account.t) list
  end

  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Staged_ledger_hash :
    Staged_ledger_hash_intf
    with type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type ledger_hash := Ledger_hash.t
     and type pending_coinbase := Pending_coinbase.t
     and type pending_coinbase_hash := Pending_coinbase_hash.t

  (*
Bundle Snark:
   Input:
      l1 : Ledger_hash.t,
      l2 : Ledger_hash.t,
      fee_excess : Amount.Signed.t,
   Witness:
      t : Tagged_transaction.t
   such that
     applying [t] to ledger with merkle hash [l1] results in ledger with merkle hash [l2].

Merge Snark:
    Input:
      s1 : state
      s3 : state
      fee_excess_total : Amount.Signed.t
    Witness:
      s2 : state
      p12 : proof
      p23 : proof
      fee_excess12 : Amount.Signed.t
      fee_excess23 : Amount.Signed.t
    s.t.
      p12 verifies s1 -> s2 is a valid transition with fee_excess12
      p23 verifies s2 -> s3 is a valid transition with fee_excess23
      fee_excess_total = fee_excess12 + fee_excess23
  *)
  module Time_close_validator :
    Time_close_validator_intf with type time := Time.t

  module Transaction_snark_work :
    Transaction_snark_work_intf
    with type proof := Ledger_proof.t
     and type statement := Ledger_proof_statement.t
     and type public_key := Public_key.Compressed.t

  module Staged_ledger_diff :
    Staged_ledger_diff_intf
    with type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type completed_work := Transaction_snark_work.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type fee_transfer_single := Fee_transfer.Single.t

  module Sparse_ledger : sig
    type t
  end

  module Transaction_witness :
    Transaction_witness_intf with type sparse_ledger := Sparse_ledger.t

  module Staged_ledger :
    Staged_ledger_intf
    with type diff := Staged_ledger_diff.t
     and type valid_diff :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type ledger_hash := Ledger_hash.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type ledger := Ledger.t
     and type ledger_proof := Ledger_proof.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type statement := Transaction_snark_work.Statement.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type sparse_ledger := Sparse_ledger.t
     and type ledger_proof_statement := Ledger_proof_statement.t
     and type ledger_proof_statement_set := Ledger_proof_statement.Set.t
     and type transaction := Transaction.t
     and type user_command := User_command.t
     and type transaction_witness := Transaction_witness.t
     and type pending_coinbase_collection := Pending_coinbase.t
     and type verifier := Verifier.t

  module Staged_ledger_transition :
    Staged_ledger_transition_intf
    with type diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type diff_with_valid_signatures_and_proofs :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t

  module Protocol_state_hash : Protocol_state_hash_intf

  module Protocol_state_proof : Protocol_state_proof_intf

  module Prover_state : Prover_state_intf

  module Blockchain_state :
    Blockchain_state_intf
    with type staged_ledger_hash := Staged_ledger_hash.t
     and type staged_ledger_hash_var := Staged_ledger_hash.var
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type frozen_ledger_hash_var := Frozen_ledger_hash.var
     and type time := Time.t
     and type time_var := Time.Unpacked.var

  module Consensus_state : Consensus_state_intf

  module Protocol_state :
    Protocol_state_intf
    with type state_hash := Protocol_state_hash.t
     and type state_hash_var := Protocol_state_hash.var
     and type blockchain_state := Blockchain_state.Value.t
     and type blockchain_state_var := Blockchain_state.var
     and type consensus_state := Consensus_state.Value.t
     and type consensus_state_var := Consensus_state.var

  module Consensus_transition : Consensus_transition_intf

  module Snark_transition :
    Snark_transition_intf
    with type blockchain_state_var := Blockchain_state.var
     and type consensus_transition_var := Consensus_transition.var
     and type sok_digest_var := Sok_message.Digest.Checked.t
     and type amount_var := Currency.Amount.var
     and type public_key_var := Public_key.Compressed.var

  module Internal_transition :
    Internal_transition_intf
    with type snark_transition := Snark_transition.Value.t
     and type prover_state := Prover_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t

  module External_transition :
    External_transition_intf
    with type state_hash := Protocol_state_hash.t
     and type compressed_public_key := Compressed_public_key.t
     and type user_command := User_command.t
     and type consensus_state := Consensus_state.Value.t
     and type protocol_state := Protocol_state.Value.t
     and type proof := Protocol_state_proof.t
     and type verifier := Verifier.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type ledger_proof := Ledger_proof.t
     and type transaction := Transaction.t
     and type time := Time.t

  module Transaction_validator :
    Transaction_validator_intf
    with type outer_ledger := Ledger.t
     and type transaction := Transaction.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type ledger_hash := Ledger_hash.t
end

module Make
    (Inputs : Inputs_intf)
    (Block_state_transition_proof : Block_state_transition_proof_intf
                                    with type protocol_state :=
                                                Inputs.Protocol_state.Value.t
                                     and type protocol_state_proof :=
                                                Inputs.Protocol_state_proof.t
                                     and type internal_transition :=
                                                Inputs.Internal_transition.t) =
struct
  open Inputs

  module Proof_carrying_state = struct
    type t =
      (Protocol_state.Value.t, Protocol_state_proof.t) Proof_carrying_data.t
  end

  module Event = struct
    type t =
      | Found of Internal_transition.t
      | New_state of Proof_carrying_state.t * Staged_ledger_transition.t
  end

  type t = {state: Proof_carrying_state.t} [@@deriving fields]
end
