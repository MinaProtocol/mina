open Mina_base

module type Iffable = sig
  type bool

  type t

  val if_ : bool -> then_:t -> else_:t -> t
end

module type Bool_intf = sig
  type t

  include Iffable with type t := t and type bool := t

  val true_ : t

  val false_ : t

  val equal : t -> t -> t

  val not : t -> t

  val ( ||| ) : t -> t -> t

  val ( &&& ) : t -> t -> t

  module Assert : sig
    (* [pos] is file,line,col,endcol from __POS__ *)
    val is_true : pos:string * int * int * int -> t -> unit

    (* [pos] is file,line,col,endcol from __POS__ *)
    val any : pos:string * int * int * int -> t list -> unit
  end

  val display : t -> label:string -> string

  val all : t list -> t

  type failure_status

  type failure_status_tbl

  (* [pos] is file,line,col,endcol from __POS__ *)
  val assert_with_failure_status_tbl :
    pos:string * int * int * int -> t -> failure_status_tbl -> unit
end

module type Balance_intf = sig
  include Iffable

  type amount

  type signed_amount

  val sub_amount_flagged : t -> amount -> t * [ `Underflow of bool ]

  val add_signed_amount_flagged : t -> signed_amount -> t * [ `Overflow of bool ]
end

module type Receipt_chain_hash_intf = sig
  include Iffable

  type transaction_commitment

  type index

  module Elt : sig
    type t

    val of_transaction_commitment : transaction_commitment -> t
  end

  val cons_zkapp_command_commitment : index -> Elt.t -> t -> t
end

module type Amount_intf = sig
  include Iffable

  type unsigned = t

  module Signed : sig
    include Iffable with type bool := bool

    val equal : t -> t -> bool

    val is_pos : t -> bool

    val is_neg : t -> bool

    val negate : t -> t

    val add_flagged : t -> t -> t * [ `Overflow of bool ]

    val of_unsigned : unsigned -> t
  end

  val zero : t

  val equal : t -> t -> bool

  val add_flagged : t -> t -> t * [ `Overflow of bool ]

  val add_signed_flagged : t -> Signed.t -> t * [ `Overflow of bool ]

  val of_constant_fee : Currency.Fee.t -> t
end

module type Account_id_intf = sig
  include Iffable

  type public_key

  type token_id

  val invalid : t

  val equal : t -> t -> bool

  val create : public_key -> token_id -> t

  val derive_token_id : owner:t -> token_id
end

module type Global_slot_intf = sig
  include Iffable

  val zero : t

  val ( > ) : t -> t -> bool

  val equal : t -> t -> bool
end

module type Timing_intf = sig
  include Iffable

  type global_slot

  val vesting_period : t -> global_slot
end

module type Token_id_intf = sig
  include Iffable

  val equal : t -> t -> bool

  val default : t
end

module type Actions_intf = sig
  type t

  type bool

  type field

  val is_empty : t -> bool

  val push_events : field -> t -> field
end

module type Protocol_state_precondition_intf = sig
  type t
end

module type Set_or_keep_intf = sig
  type _ t

  type bool

  val is_set : _ t -> bool

  val is_keep : _ t -> bool

  val set_or_keep : if_:(bool -> then_:'a -> else_:'a -> 'a) -> 'a t -> 'a -> 'a
end

module type Account_update_intf = sig
  type t

  type bool

  type call_forest

  type signed_amount

  type transaction_commitment

  type protocol_state_precondition

  type public_key

  type token_id

  type account_id

  type account

  type nonce

  type _ or_ignore

  val balance_change : t -> signed_amount

  val protocol_state_precondition : t -> protocol_state_precondition

  val public_key : t -> public_key

  val token_id : t -> token_id

  val account_id : t -> account_id

  val is_delegate_call : t -> bool

  val use_full_commitment : t -> bool

  val increment_nonce : t -> bool

  val implicit_account_creation_fee : t -> bool

  val check_authorization :
       commitment:transaction_commitment
    -> calls:call_forest
    -> t
    -> [ `Proof_verifies of bool ] * [ `Signature_verifies of bool ]

  val is_signed : t -> bool

  val is_proved : t -> bool

  module Update : sig
    type _ set_or_keep

    type timing

    val timing : t -> timing set_or_keep

    type field

    val app_state : t -> field set_or_keep Zkapp_state.V.t

    type verification_key

    val verification_key : t -> verification_key set_or_keep

    type actions

    val actions : t -> actions

    type zkapp_uri

    val zkapp_uri : t -> zkapp_uri set_or_keep

    type token_symbol

    val token_symbol : t -> token_symbol set_or_keep

    val delegate : t -> public_key set_or_keep

    type state_hash

    val voting_for : t -> state_hash set_or_keep

    type permissions

    val permissions : t -> permissions set_or_keep
  end

  module Account_precondition : sig
    val nonce : t -> nonce Zkapp_precondition.Closed_interval.t or_ignore
  end
end

module type Opt_intf = sig
  type bool

  type 'a t

  val is_some : 'a t -> bool

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val or_default :
    if_:(bool -> then_:'a -> else_:'a -> 'a) -> 'a t -> default:'a -> 'a

  val or_exn : 'a t -> 'a
end

module type Stack_intf = sig
  include Iffable

  module Opt : Opt_intf with type bool := bool

  type elt

  val empty : unit -> t

  val is_empty : t -> bool

  val pop_exn : t -> elt * t

  val pop : t -> (elt * t) Opt.t

  val push : elt -> onto:t -> t
end

module type Call_forest_intf = sig
  include Iffable

  type account_update

  module Opt : Opt_intf with type bool := bool

  val empty : unit -> t

  val is_empty : t -> bool

  val pop_exn : t -> (account_update * t) * t
end

module type Stack_frame_intf = sig
  type caller

  type call_forest

  include Iffable

  val caller : t -> caller

  val caller_caller : t -> caller

  val calls : t -> call_forest

  val make : caller:caller -> caller_caller:caller -> calls:call_forest -> t
end

module type Call_stack_intf = sig
  type stack_frame

  include Stack_intf with type elt := stack_frame
end

module type Ledger_intf = sig
  include Iffable

  type public_key

  type token_id

  type account_update

  type account

  type inclusion_proof

  val empty : depth:int -> unit -> t

  val get_account : account_update -> t -> account * inclusion_proof

  val set_account : t -> account * inclusion_proof -> t

  val check_inclusion : t -> account * inclusion_proof -> unit

  val check_account :
    public_key -> token_id -> account * inclusion_proof -> [ `Is_new of bool ]
end

module type Controller_intf = sig
  include Iffable

  val check : proof_verifies:bool -> signature_verifies:bool -> t -> bool
end

module type Account_intf = sig
  type t

  type bool

  type public_key

  type account_id

  module Permissions : sig
    type controller

    val access : t -> controller

    val edit_state : t -> controller

    val send : t -> controller

    val receive : t -> controller

    val set_delegate : t -> controller

    val set_permissions : t -> controller

    val set_verification_key : t -> controller

    val set_zkapp_uri : t -> controller

    val edit_sequence_state : t -> controller

    val set_token_symbol : t -> controller

    val increment_nonce : t -> controller

    val set_voting_for : t -> controller

    include Iffable with type bool := bool
  end

  type timing

  type token_id

  type receipt_chain_hash

  val timing : t -> timing

  val set_timing : t -> timing -> t

  val is_timed : t -> bool

  val set_token_id : t -> token_id -> t

  type balance

  val balance : t -> balance

  val set_balance : balance -> t -> t

  type global_slot

  val check_timing :
       txn_global_slot:global_slot
    -> t
    -> [ `Invalid_timing of bool | `Insufficient_balance of bool ] * timing

  val receipt_chain_hash : t -> receipt_chain_hash

  val set_receipt_chain_hash : t -> receipt_chain_hash -> t

  (** Fill the snapp field of the account if it's currently [None] *)
  val make_zkapp : t -> t

  (** If the current account has no snapp fields set, reset its snapp field to
      [None].
  *)
  val unmake_zkapp : t -> t

  val proved_state : t -> bool

  val set_proved_state : bool -> t -> t

  type field

  val app_state : t -> field Zkapp_state.V.t

  val set_app_state : field Zkapp_state.V.t -> t -> t

  val register_verification_key : t -> unit

  type verification_key

  val verification_key : t -> verification_key

  val set_verification_key : verification_key -> t -> t

  val last_sequence_slot : t -> global_slot

  val set_last_sequence_slot : global_slot -> t -> t

  val sequence_state : t -> field Pickles_types.Vector.Vector_5.t

  val set_sequence_state : field Pickles_types.Vector.Vector_5.t -> t -> t

  type zkapp_uri

  val zkapp_uri : t -> zkapp_uri

  val set_zkapp_uri : zkapp_uri -> t -> t

  type token_symbol

  val token_symbol : t -> token_symbol

  val set_token_symbol : token_symbol -> t -> t

  val public_key : t -> public_key

  val set_public_key : public_key -> t -> t

  val delegate : t -> public_key

  val set_delegate : public_key -> t -> t

  type nonce

  val nonce : t -> nonce

  val set_nonce : nonce -> t -> t

  type state_hash

  val voting_for : t -> state_hash

  val set_voting_for : state_hash -> t -> t

  val permissions : t -> Permissions.t

  val set_permissions : Permissions.t -> t -> t
end
