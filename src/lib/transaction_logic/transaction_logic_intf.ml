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

module type Verification_key_hash_intf = sig
  type t

  type bool

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

  type valid_while_precondition

  type public_key

  type token_id

  type account_id

  type account

  type nonce

  type verification_key_hash

  type _ or_ignore

  val balance_change : t -> signed_amount

  val protocol_state_precondition : t -> protocol_state_precondition

  val valid_while_precondition : t -> valid_while_precondition

  val public_key : t -> public_key

  val token_id : t -> token_id

  val account_id : t -> account_id

  val may_use_parents_own_token : t -> bool

  val may_use_token_inherited_from_parent : t -> bool

  val use_full_commitment : t -> bool

  val increment_nonce : t -> bool

  val implicit_account_creation_fee : t -> bool

  val check_authorization :
       will_succeed:bool
    -> commitment:transaction_commitment
    -> calls:call_forest
    -> t
    -> [ `Proof_verifies of bool ] * [ `Signature_verifies of bool ]

  val is_signed : t -> bool

  val is_proved : t -> bool

  val verification_key_hash : t -> verification_key_hash

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

    val set_timing : t -> controller

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

  (** Fill the zkapp field of the account if it's currently [None] *)
  val make_zkapp : t -> t

  (** If the current account has no zkApp fields set, reset its zkapp field to
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

  type verification_key_hash

  val verification_key_hash : t -> verification_key_hash

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

module type Valid_while_precondition_intf = sig
  type t
end

module type Inputs_intf = sig
  val with_label : label:string -> (unit -> 'a) -> 'a

  module Bool : Bool_intf

  module Field : Iffable with type bool := Bool.t

  module Amount : Amount_intf with type bool := Bool.t

  module Balance :
    Balance_intf
      with type bool := Bool.t
       and type amount := Amount.t
       and type signed_amount := Amount.Signed.t

  module Public_key : Iffable with type bool := Bool.t

  module Token_id : Token_id_intf with type bool := Bool.t

  module Account_id :
    Account_id_intf
      with type bool := Bool.t
       and type public_key := Public_key.t
       and type token_id := Token_id.t

  module Set_or_keep : Set_or_keep_intf with type bool := Bool.t

  module Protocol_state_precondition : Protocol_state_precondition_intf

  module Valid_while_precondition : Valid_while_precondition_intf

  module Controller : Controller_intf with type bool := Bool.t

  module Global_slot : Global_slot_intf with type bool := Bool.t

  module Nonce : sig
    include Iffable with type bool := Bool.t

    val succ : t -> t
  end

  module State_hash : Iffable with type bool := Bool.t

  module Timing :
    Timing_intf with type bool := Bool.t and type global_slot := Global_slot.t

  module Zkapp_uri : Iffable with type bool := Bool.t

  module Token_symbol : Iffable with type bool := Bool.t

  module Opt : Opt_intf with type bool := Bool.t

  module rec Receipt_chain_hash :
    (Receipt_chain_hash_intf
      with type bool := Bool.t
       and type transaction_commitment := Transaction_commitment.t
       and type index := Index.t)

  and Verification_key : (Iffable with type bool := Bool.t)
  and Verification_key_hash :
    (Verification_key_hash_intf with type bool := Bool.t)

  and Account :
    (Account_intf
      with type Permissions.controller := Controller.t
       and type timing := Timing.t
       and type balance := Balance.t
       and type receipt_chain_hash := Receipt_chain_hash.t
       and type bool := Bool.t
       and type global_slot := Global_slot.t
       and type field := Field.t
       and type verification_key := Verification_key.t
       and type verification_key_hash := Verification_key_hash.t
       and type zkapp_uri := Zkapp_uri.t
       and type token_symbol := Token_symbol.t
       and type public_key := Public_key.t
       and type nonce := Nonce.t
       and type state_hash := State_hash.t
       and type token_id := Token_id.t
       and type account_id := Account_id.t)

  and Actions :
    (Actions_intf with type bool := Bool.t and type field := Field.t)

  and Account_update :
    (Account_update_intf
      with type signed_amount := Amount.Signed.t
       and type protocol_state_precondition := Protocol_state_precondition.t
       and type valid_while_precondition := Valid_while_precondition.t
       and type token_id := Token_id.t
       and type bool := Bool.t
       and type account := Account.t
       and type public_key := Public_key.t
       and type nonce := Nonce.t
       and type account_id := Account_id.t
       and type verification_key_hash := Verification_key_hash.t
       and type Update.timing := Timing.t
       and type 'a Update.set_or_keep := 'a Set_or_keep.t
       and type Update.field := Field.t
       and type Update.verification_key := Verification_key.t
       and type Update.actions := Actions.t
       and type Update.zkapp_uri := Zkapp_uri.t
       and type Update.token_symbol := Token_symbol.t
       and type Update.state_hash := State_hash.t
       and type Update.permissions := Account.Permissions.t)

  and Nonce_precondition : sig
    val is_constant :
         Nonce.t Zkapp_precondition.Closed_interval.t Account_update.or_ignore
      -> Bool.t
  end

  and Ledger :
    (Ledger_intf
      with type bool := Bool.t
       and type account := Account.t
       and type account_update := Account_update.t
       and type token_id := Token_id.t
       and type public_key := Public_key.t)

  and Call_forest :
    (Call_forest_intf
      with type t = Account_update.call_forest
       and type bool := Bool.t
       and type account_update := Account_update.t
       and module Opt := Opt)

  and Stack_frame :
    (Stack_frame_intf
      with type bool := Bool.t
       and type call_forest := Call_forest.t
       and type caller := Token_id.t)

  and Call_stack :
    (Call_stack_intf
      with type stack_frame := Stack_frame.t
       and type bool := Bool.t
       and module Opt := Opt)

  and Transaction_commitment : sig
    include
      Iffable
        with type bool := Bool.t
         and type t = Account_update.transaction_commitment

    val empty : t

    val commitment : account_updates:Call_forest.t -> t

    val full_commitment :
      account_update:Account_update.t -> memo_hash:Field.t -> commitment:t -> t
  end

  and Index : sig
    include Iffable with type bool := Bool.t

    val zero : t

    val succ : t -> t
  end

  module Local_state : sig
    type t =
      ( Stack_frame.t
      , Call_stack.t
      , Token_id.t
      , Amount.Signed.t
      , Ledger.t
      , Bool.t
      , Transaction_commitment.t
      , Index.t
      , Bool.failure_status_tbl )
      Local_state.t

    val add_check : t -> Transaction_status.Failure.t -> Bool.t -> t

    val update_failure_status_tbl : t -> Bool.failure_status -> Bool.t -> t

    val add_new_failure_status_bucket : t -> t
  end

  module Global_state : sig
    type t

    val ledger : t -> Ledger.t

    val set_ledger : should_update:Bool.t -> t -> Ledger.t -> t

    val fee_excess : t -> Amount.Signed.t

    val set_fee_excess : t -> Amount.Signed.t -> t

    val supply_increase : t -> Amount.Signed.t

    val set_supply_increase : t -> Amount.Signed.t -> t

    val block_global_slot : t -> Global_slot.t
  end
end
