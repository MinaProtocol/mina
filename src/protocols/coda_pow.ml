open Core_kernel
open Async_kernel
open Pipe_lib
include Coda_transition_frontier

module type Security_intf = sig
  val max_depth : [`Infinity | `Finite of int]
  (** In production we set this to (hopefully a prefix of) k for our consensus
   * mechanism; infinite is for tests *)
end

module type Time_controller_intf = sig
  type t

  val create : unit -> t
end

module type Sok_message_intf = sig
  type public_key_compressed

  module Digest : sig
    type t
  end

  type t [@@deriving bin_io, sexp]

  val create : fee:Currency.Fee.t -> prover:public_key_compressed -> t
end

module type Hash_intf = sig
  include Equal.S

  include Hashable.S_binable with type t := t
end

module type Time_intf = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, bin_io]
    end
  end

  module Controller : Time_controller_intf

  type t [@@deriving sexp]

  type t0 = t

  module Span : sig
    type t

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
  end

  val to_span_since_epoch : t -> Span.t

  val of_span_since_epoch : Span.t -> t

  val diff : t -> t -> Span.t

  val sub : t -> Span.t -> t

  val add : t -> Span.t -> t

  val modulus : t -> Span.t -> Span.t

  val now : Controller.t -> t
end

module type Ledger_hash_intf = sig
  type t [@@deriving bin_io, eq, sexp, compare]

  val to_bytes : t -> string

  include Hashable.S_binable with type t := t
end

module type Frozen_ledger_hash_intf = sig
  type ledger_hash

  include Ledger_hash_intf

  val of_ledger_hash : ledger_hash -> t

  val to_ledger_hash : t -> ledger_hash
end

module type Protocol_state_hash_intf = sig
  type t [@@deriving bin_io, sexp, eq]

  include Hashable.S_binable with type t := t
end

module type Protocol_state_proof_intf = sig
  type t

  val dummy : t
end

module type Staged_ledger_aux_hash_intf = sig
  type t [@@deriving bin_io, sexp, eq]

  val of_bytes : string -> t
end

module type Staged_ledger_hash_intf = sig
  type t [@@deriving bin_io, sexp, eq, compare]

  type ledger_hash

  type staged_ledger_aux_hash

  val ledger_hash : t -> ledger_hash

  val aux_hash : t -> staged_ledger_aux_hash

  val of_aux_and_ledger_hash : staged_ledger_aux_hash -> ledger_hash -> t

  include Hashable.S_binable with type t := t
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
    type t [@@deriving sexp, bin_io]

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
end

module Fee = struct
  module Unsigned = struct
    include Currency.Fee

    include (
      Currency.Fee.Stable.V1 :
        module type of Currency.Fee.Stable.V1 with type t := t )
  end

  module Signed = struct
    include Currency.Fee.Signed

    include (
      Currency.Fee.Signed.Stable.V1 :
        module type of Currency.Fee.Signed.Stable.V1
        with type t := t
         and type ('a, 'b) t_ := ('a, 'b) t_ )
  end
end

module type Snark_pool_proof_intf = sig
  module Statement : sig
    type t [@@deriving sexp, bin_io]
  end

  type t [@@deriving sexp, bin_io]
end

module type User_command_intf = sig
  type t [@@deriving sexp, eq, bin_io]

  type public_key

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp, eq]
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
  type t [@@deriving sexp, bin_io, compare]

  include Comparable.S with type t := t
end

module type Public_key_intf = sig
  module Private_key : Private_key_intf

  type t [@@deriving sexp]

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
  type t [@@deriving sexp, compare, eq]

  type public_key

  type single = public_key * Fee.Unsigned.t

  val of_single : public_key * Fee.Unsigned.t -> t

  val of_single_list : (public_key * Fee.Unsigned.t) list -> t list

  val receivers : t -> public_key list
end

module type Coinbase_intf = sig
  type public_key

  type fee_transfer

  type t = private
    { proposer: public_key
    ; amount: Currency.Amount.t
    ; fee_transfer: fee_transfer option }
  [@@deriving sexp, bin_io, compare, eq]

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

module type Ledger_proof_statement_intf = sig
  type ledger_hash

  type t =
    { source: ledger_hash
    ; target: ledger_hash
    ; supply_increase: Currency.Amount.t
    ; fee_excess: Fee.Signed.t
    ; proof_type: [`Base | `Merge] }
  [@@deriving sexp, bin_io, compare]

  val merge : t -> t -> t Or_error.t

  include Comparable.S with type t := t
end

module type Ledger_proof_intf = sig
  type ledger_hash

  type statement

  type proof

  type sok_digest

  type t [@@deriving sexp, bin_io]

  val create : statement:statement -> sok_digest:sok_digest -> proof:proof -> t

  val statement_target : statement -> ledger_hash

  val statement : t -> statement

  val sok_digest : t -> sok_digest

  val underlying_proof : t -> proof
end

module type Ledger_proof_verifier_intf = sig
  type ledger_proof

  type message

  type statement

  val verify : ledger_proof -> statement -> message:message -> bool Deferred.t
end

module Work_selection = struct
  type t = Seq | Random [@@deriving bin_io]
end

module type Transaction_snark_work_intf = sig
  type proof

  type statement

  type public_key

  module Statement : sig
    type t = statement list

    include Sexpable.S with type t := t

    include Binable.S with type t := t

    include Hashable.S_binable with type t := t

    val gen : t Quickcheck.Generator.t
  end

  (* TODO: The SOK message actually should bind the SNARK to
   be in this particular bundle. The easiest way would be to
   SOK with
   H(all_statements_in_bundle || fee || public_key)
*)

  type t = {fee: Fee.Unsigned.t; proofs: proof list; prover: public_key}
  [@@deriving sexp, bin_io]

  type unchecked = t

  module Checked : sig
    type t = {fee: Fee.Unsigned.t; proofs: proof list; prover: public_key}
    [@@deriving sexp, bin_io]

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

  module At_most_two : sig
    type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
    [@@deriving sexp, bin_io]

    val increase : 'a t -> 'a list -> 'a t Or_error.t
  end

  module At_most_one : sig
    type 'a t = Zero | One of 'a option [@@deriving sexp, bin_io]

    val increase : 'a t -> 'a list -> 'a t Or_error.t
  end

  type diff =
    {completed_works: completed_work list; user_commands: user_command list}
  [@@deriving sexp, bin_io]

  type diff_with_at_most_two_coinbase =
    {diff: diff; coinbase_parts: completed_work At_most_two.t}
  [@@deriving sexp, bin_io]

  type diff_with_at_most_one_coinbase =
    {diff: diff; coinbase_added: completed_work At_most_one.t}
  [@@deriving sexp, bin_io]

  type pre_diffs =
    ( diff_with_at_most_one_coinbase
    , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
    Either.t
  [@@deriving sexp, bin_io]

  type t =
    {pre_diffs: pre_diffs; prev_hash: staged_ledger_hash; creator: public_key}
  [@@deriving sexp, bin_io]

  module Verified : sig
    type diff =
      { completed_works: completed_work_checked list
      ; user_commands: user_command list }
    [@@deriving sexp, bin_io]

    type diff_with_at_most_two_coinbase =
      {diff: diff; coinbase_parts: completed_work_checked At_most_two.t}
    [@@deriving sexp, bin_io]

    type diff_with_at_most_one_coinbase =
      {diff: diff; coinbase_added: completed_work_checked At_most_one.t}
    [@@deriving sexp, bin_io]

    type pre_diffs =
      ( diff_with_at_most_one_coinbase
      , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
      Either.t
    [@@deriving sexp, bin_io]

    type t =
      {pre_diffs: pre_diffs; prev_hash: staged_ledger_hash; creator: public_key}
    [@@deriving sexp, bin_io]
  end

  val forget_verified : Verified.t -> t

  module With_valid_signatures_and_proofs : sig
    type diff =
      { completed_works: completed_work_checked list
      ; user_commands: user_command_with_valid_signature list }
    [@@deriving sexp]

    type diff_with_at_most_two_coinbase =
      {diff: diff; coinbase_parts: completed_work_checked At_most_two.t}
    [@@deriving sexp]

    type diff_with_at_most_one_coinbase =
      {diff: diff; coinbase_added: completed_work_checked At_most_one.t}
    [@@deriving sexp]

    type pre_diffs =
      ( diff_with_at_most_one_coinbase
      , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
      Either.t
    [@@deriving sexp]

    type t =
      {pre_diffs: pre_diffs; prev_hash: staged_ledger_hash; creator: public_key}
    [@@deriving sexp]

    val user_commands : t -> user_command_with_valid_signature list
  end

  val forget_validated : With_valid_signatures_and_proofs.t -> t

  val user_commands : t -> user_command list
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

  type t [@@deriving sexp, bin_io]

  type ledger_proof

  type transaction_snark_work

  type transaction_with_info

  type frozen_ledger_hash

  type staged_ledger_aux_hash

  module Transaction_with_witness : sig
    (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
    type t =
      { transaction_with_info: transaction_with_info
      ; statement: ledger_proof_statement
      ; witness: sparse_ledger }
  end

  module Ledger_proof_with_sok_message : sig
    type t = ledger_proof * sok_message
  end

  module Available_job : sig
    type t
  end

  module Make_statement_scanner
      (M : Monad_with_Or_error_intf) (Verifier : sig
          val verify :
               ledger_proof
            -> ledger_proof_statement
            -> message:sok_message
            -> sexp_bool M.t
      end) : sig
    val scan_statement :
      t -> (ledger_proof_statement, [`Empty | `Error of Error.t]) result M.t

    val check_invariants :
         t
      -> error_prefix:string
      -> ledger
      -> frozen_ledger_hash sexp_option
      -> (unit, Error.t) result M.t
  end

  val empty : unit -> t

  val enqueue_transactions :
    t -> Transaction_with_witness.t list -> unit Or_error.t

  val fill_in_transaction_snark_work :
    t -> transaction_snark_work list -> ledger_proof option Or_error.t

  val latest_ledger_proof : t -> Ledger_proof_with_sok_message.t option

  val free_space : t -> int

  val next_k_jobs : t -> k:int -> Available_job.t list Or_error.t

  val next_jobs : t -> Available_job.t list

  val next_jobs_sequence : t -> Available_job.t Sequence.t

  val is_valid : t -> bool

  val hash : t -> staged_ledger_aux_hash

  val staged_transactions : t -> transaction_with_info list

  val extract_from_job :
       Available_job.t
    -> ( transaction_with_info * ledger_proof_statement * sparse_ledger
       , ledger_proof * ledger_proof )
       Either.t

  val copy : t -> t

  val partition_if_overflowing :
    t -> max_slots:int -> [`One of int | `Two of int * int]

  val statement_of_job : Available_job.t -> ledger_proof_statement option
end

module type Staged_ledger_base_intf = sig
  type t [@@deriving sexp]

  type diff

  type verified_diff

  type valid_diff

  type staged_ledger_aux_hash

  type staged_ledger_hash

  type frozen_ledger_hash

  type ledger_proof

  (** The ledger in a ledger builder is always a mask *)
  type ledger

  type serializable [@@deriving bin_io]

  module Scan_state : sig
    type t [@@deriving bin_io]

    val hash : t -> staged_ledger_aux_hash

    val is_valid : t -> bool

    val empty : unit -> t
  end

  val ledger : t -> ledger

  val scan_state : t -> Scan_state.t

  val create : ledger:ledger -> t

  val of_scan_state_and_ledger :
       snarked_ledger_hash:frozen_ledger_hash
    -> ledger:ledger
    -> scan_state:Scan_state.t
    -> t Or_error.t Deferred.t

  val of_serialized_and_unserialized :
    serialized:serializable -> unserialized:ledger -> t

  val copy : t -> t

  val hash : t -> staged_ledger_hash

  val serializable_of_t : t -> serializable

  val apply :
       t
    -> verified_diff
    -> logger:Logger.t
    -> ( [`Hash_after_applying of staged_ledger_hash]
       * [`Ledger_proof of ledger_proof option]
       * [`Staged_ledger of t] )
       Or_error.t

  val apply_unverified :
       t
    -> diff
    -> logger:Logger.t
    -> ( [`Hash_after_applying of staged_ledger_hash]
       * [`Ledger_proof of ledger_proof option]
       * [`Staged_ledger of t] )
       Or_error.t

  val apply_diff_unchecked :
       t
    -> valid_diff
    -> [`Hash_after_applying of staged_ledger_hash]
       * [`Ledger_proof of ledger_proof option]
       * [`Staged_ledger of t]

  val snarked_ledger :
    t -> snarked_ledger_hash:frozen_ledger_hash -> ledger Or_error.t
end

module type Staged_ledger_intf = sig
  include Staged_ledger_base_intf

  type ledger_hash

  type transaction

  type user_command_with_valid_signature

  type statement

  type ledger_proof_statement

  type ledger_proof_statement_set

  type sparse_ledger

  type completed_work_checked

  type public_key

  val current_ledger_proof : t -> ledger_proof option

  (* This should memoize the snark verifications *)

  val create_diff :
       t
    -> self:public_key
    -> logger:Logger.t
    -> transactions_by_fee:user_command_with_valid_signature Sequence.t
    -> get_completed_work:(statement -> completed_work_checked option)
    -> valid_diff

  val all_work_pairs :
       t
    -> ( ( ledger_proof_statement
         , transaction
         , sparse_ledger
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
       * ( ledger_proof_statement
         , transaction
         , sparse_ledger
         , ledger_proof )
         Snark_work_lib.Work.Single.Spec.t
         option )
       list

  val statement_exn : t -> [`Non_empty of ledger_proof_statement | `Empty]

  val verified_diff_of_diff : t -> diff -> verified_diff Or_error.t Deferred.t
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

module type Tip_intf = sig
  type protocol_state

  type protocol_state_proof

  type staged_ledger

  type serializable

  type external_transition

  type external_transition_verified

  (* N.B.: can't derive bin_io for ledger builder containing persistent ledger *)
  type t =
    { state: protocol_state
    ; proof: protocol_state_proof
    ; staged_ledger: staged_ledger }
  [@@deriving sexp, fields]

  (* serializer for tip components other than the persistent database in the ledger builder *)
  val bin_tip : serializable Bin_prot.Type_class.t

  val of_verified_transition_and_staged_ledger :
    external_transition_verified -> staged_ledger -> t

  val copy : t -> t
end

module type Consensus_state_intf = sig
  type value

  type var
end

module type Blockchain_state_intf = sig
  type staged_ledger_hash

  type frozen_ledger_hash

  type time

  type value [@@deriving sexp, bin_io]

  type var

  val create_value :
       staged_ledger_hash:staged_ledger_hash
    -> ledger_hash:frozen_ledger_hash
    -> timestamp:time
    -> value

  val staged_ledger_hash : value -> staged_ledger_hash

  val ledger_hash : value -> frozen_ledger_hash

  val timestamp : value -> time
end

module type Protocol_state_intf = sig
  type state_hash

  type blockchain_state

  type consensus_state

  type value [@@deriving sexp, bin_io, eq, compare]

  type var

  val create_value :
       previous_state_hash:state_hash
    -> blockchain_state:blockchain_state
    -> consensus_state:consensus_state
    -> value

  val previous_state_hash : value -> state_hash

  val blockchain_state : value -> blockchain_state

  val consensus_state : value -> consensus_state

  val hash : value -> state_hash
end

module type Internal_transition_intf = sig
  type snark_transition

  type staged_ledger_diff

  type prover_state

  type t [@@deriving sexp, bin_io]

  val create :
       snark_transition:snark_transition
    -> prover_state:prover_state
    -> staged_ledger_diff:staged_ledger_diff
    -> t

  val snark_transition : t -> snark_transition

  val prover_state : t -> prover_state

  val staged_ledger_diff : t -> staged_ledger_diff
end

module type External_transition_intf = sig
  type protocol_state

  type protocol_state_proof

  type staged_ledger_diff

  type staged_ledger_diff_verified

  type t [@@deriving sexp, bin_io]

  val create :
       protocol_state:protocol_state
    -> protocol_state_proof:protocol_state_proof
    -> staged_ledger_diff:staged_ledger_diff
    -> t

  module Verified : sig
    type t [@@deriving sexp, bin_io]

    val create :
         protocol_state:protocol_state
      -> protocol_state_proof:protocol_state_proof
      -> staged_ledger_diff:staged_ledger_diff_verified
      -> t

    val protocol_state : t -> protocol_state

    val protocol_state_proof : t -> protocol_state_proof
  end

  val forget : Verified.t -> t

  val protocol_state : t -> protocol_state

  val protocol_state_proof : t -> protocol_state_proof

  val staged_ledger_diff : t -> staged_ledger_diff
end

module type Consensus_mechanism_intf = sig
  type proof

  type ledger

  type frozen_ledger_hash

  type staged_ledger_hash

  type staged_ledger_diff

  type protocol_state_proof

  type protocol_state_hash

  type user_command

  type sok_digest

  type keypair

  type time

  module Local_state : sig
    type t [@@deriving sexp]

    val create : keypair option -> t
  end

  module Consensus_transition_data : sig
    type value [@@deriving sexp]

    type var
  end

  module Consensus_state : Consensus_state_intf

  module Blockchain_state :
    Blockchain_state_intf
    with type staged_ledger_hash := staged_ledger_hash
     and type frozen_ledger_hash := frozen_ledger_hash
     and type time := time

  module Protocol_state :
    Protocol_state_intf
    with type state_hash := protocol_state_hash
     and type blockchain_state := Blockchain_state.value
     and type consensus_state := Consensus_state.value

  module Prover_state : sig
    type t [@@deriving bin_io]
  end

  module Proposal_data : sig
    type t

    val prover_state : t -> Prover_state.t
  end

  module Snark_transition : sig
    type value

    type var

    val create_value :
         ?sok_digest:sok_digest
      -> ?ledger_proof:proof
      -> supply_increase:Currency.Amount.t
      -> blockchain_state:Blockchain_state.value
      -> consensus_data:Consensus_transition_data.value
      -> unit
      -> value

    val blockchain_state : value -> Blockchain_state.value

    val consensus_data : value -> Consensus_transition_data.value
  end

  val generate_transition :
       previous_protocol_state:Protocol_state.value
    -> blockchain_state:Blockchain_state.value
    -> time:Int64.t
    -> proposal_data:Proposal_data.t
    -> transactions:user_command list
    -> snarked_ledger_hash:frozen_ledger_hash
    -> supply_increase:Currency.Amount.t
    -> logger:Logger.t
    -> Protocol_state.value * Consensus_transition_data.value

  val is_valid :
    Consensus_state.value -> time_received:Unix_timestamp.t -> bool

  val next_proposal :
       Int64.t
    -> Consensus_state.value
    -> local_state:Local_state.t
    -> keypair:keypair
    -> logger:Logger.t
    -> [`Check_again of Int64.t | `Propose of Int64.t * Proposal_data.t]

  val select :
       existing:Consensus_state.value
    -> candidate:Consensus_state.value
    -> logger:Logger.t
    -> time_received:Unix_timestamp.t
    -> [`Keep | `Take]

  val genesis_protocol_state :
    (Protocol_state.value, protocol_state_hash) With_hash.t
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

module Proof_carrying_data = struct
  type ('a, 'b) t = {data: 'a; proof: 'b} [@@deriving sexp, fields, bin_io]
end

module type Inputs_intf = sig
  module Time : Time_intf

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
     and type fee_transfer := Fee_transfer.single

  module Transaction :
    Transaction_intf
    with type valid_user_command := User_command.With_valid_signature.t
     and type fee_transfer := Fee_transfer.t
     and type coinbase := Coinbase.t

  module Ledger_hash : Ledger_hash_intf

  module Frozen_ledger_hash : sig
    include Ledger_hash_intf

    val of_ledger_hash : Ledger_hash.t -> t
  end

  module Proof : sig
    type t
  end

  module Sok_message :
    Sok_message_intf with type public_key_compressed := Public_key.Compressed.t

  module Ledger_proof_statement :
    Ledger_proof_statement_intf with type ledger_hash := Frozen_ledger_hash.t

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
     and type statement := Ledger_proof_statement.t

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

  module Sparse_ledger : sig
    type t
  end

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

  module Staged_ledger_transition :
    Staged_ledger_transition_intf
    with type diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type diff_with_valid_signatures_and_proofs :=
                Staged_ledger_diff.With_valid_signatures_and_proofs.t

  module Protocol_state_hash : Protocol_state_hash_intf

  module Protocol_state_proof : Protocol_state_proof_intf

  module Consensus_mechanism :
    Consensus_mechanism_intf
    with type proof := Proof.t
     and type protocol_state_hash := Protocol_state_hash.t
     and type protocol_state_proof := Protocol_state_proof.t
     and type frozen_ledger_hash := Frozen_ledger_hash.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type user_command := User_command.t
     and type sok_digest := Sok_message.Digest.t
     and type ledger := Ledger.t
     and type keypair := Keypair.t
     and type time := Time.t

  module Internal_transition :
    Internal_transition_intf
    with type snark_transition := Consensus_mechanism.Snark_transition.value
     and type prover_state := Consensus_mechanism.Prover_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t

  module External_transition :
    External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger_diff_verified := Staged_ledger_diff.Verified.t
     and type protocol_state_proof := Protocol_state_proof.t

  module Tip :
    Tip_intf
    with type staged_ledger := Staged_ledger.t
     and type protocol_state := Consensus_mechanism.Protocol_state.value
     and type protocol_state_proof := Protocol_state_proof.t
     and type external_transition := External_transition.t
     and type serializable :=
                Consensus_mechanism.Protocol_state.value
                * Protocol_state_proof.t
                * Staged_ledger.serializable
end

module Make
    (Inputs : Inputs_intf)
    (Block_state_transition_proof : Block_state_transition_proof_intf
                                    with type protocol_state :=
                                                Inputs.Consensus_mechanism
                                                .Protocol_state
                                                .value
                                     and type protocol_state_proof :=
                                                Inputs.Protocol_state_proof.t
                                     and type internal_transition :=
                                                Inputs.Internal_transition.t) =
struct
  open Inputs

  module Proof_carrying_state = struct
    type t =
      ( Consensus_mechanism.Protocol_state.value
      , Protocol_state_proof.t )
      Proof_carrying_data.t
  end

  module Event = struct
    type t =
      | Found of Internal_transition.t
      | New_state of Proof_carrying_state.t * Staged_ledger_transition.t
  end

  type t = {state: Proof_carrying_state.t} [@@deriving fields]
end
