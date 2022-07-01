(* parties_logic.ml *)

open Core_kernel
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
    val is_true : t -> unit

    val any : t list -> unit
  end

  val display : t -> label:string -> string

  val all : t list -> t

  type failure_status

  type failure_status_tbl

  val assert_with_failure_status_tbl : t -> failure_status_tbl -> unit
end

module type Balance_intf = sig
  include Iffable

  type amount

  type signed_amount

  val sub_amount_flagged : t -> amount -> t * [ `Underflow of bool ]

  val add_signed_amount_flagged : t -> signed_amount -> t * [ `Overflow of bool ]
end

module type Amount_intf = sig
  include Iffable

  type unsigned = t

  module Signed : sig
    include Iffable with type bool := bool

    val equal : t -> t -> bool

    val is_pos : t -> bool

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

module type Events_intf = sig
  type t

  type bool

  type field

  val is_empty : t -> bool

  val push_events : field -> t -> field
end

module type Protocol_state_precondition_intf = sig
  type t
end

module Local_state = struct
  open Core_kernel

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ( 'stack_frame
           , 'call_stack
           , 'token_id
           , 'excess
           , 'ledger
           , 'bool
           , 'comm
           , 'failure_status_tbl )
           t =
        { stack_frame : 'stack_frame
        ; call_stack : 'call_stack
        ; transaction_commitment : 'comm
        ; full_transaction_commitment : 'comm
        ; token_id : 'token_id
        ; excess : 'excess
        ; ledger : 'ledger
        ; success : 'bool
        ; failure_status_tbl : 'failure_status_tbl
        }
      [@@deriving compare, equal, hash, sexp, yojson, fields, hlist]
    end
  end]

  let typ stack_frame call_stack token_id excess ledger bool comm
      failure_status_tbl =
    Pickles.Impls.Step.Typ.of_hlistable
      [ stack_frame
      ; call_stack
      ; comm
      ; comm
      ; token_id
      ; excess
      ; ledger
      ; bool
      ; failure_status_tbl
      ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Value = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Mina_base.Stack_frame.Digest.Stable.V1.t
          , Mina_base.Call_stack_digest.Stable.V1.t
          , Token_id.Stable.V1.t
          , ( Currency.Amount.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
          , Ledger_hash.Stable.V1.t
          , bool
          , Parties.Transaction_commitment.Stable.V1.t
          , Transaction_status.Failure.Collection.Stable.V1.t )
          Stable.V1.t
        [@@deriving equal, compare, hash, yojson, sexp]

        let to_latest = Fn.id
      end
    end]
  end

  module Checked = struct
    open Pickles.Impls.Step

    type t =
      ( Stack_frame.Digest.Checked.t
      , Call_stack_digest.Checked.t
      , Token_id.Checked.t
      , Currency.Amount.Signed.Checked.t
      , Ledger_hash.var
      , Boolean.var
      , Parties.Transaction_commitment.Checked.t
      , unit )
      Stable.Latest.t
  end
end

module type Set_or_keep_intf = sig
  type _ t

  type bool

  val is_set : _ t -> bool

  val is_keep : _ t -> bool

  val set_or_keep : if_:(bool -> then_:'a -> else_:'a -> 'a) -> 'a t -> 'a -> 'a
end

module type Party_intf = sig
  type t

  type bool

  type parties

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

  val caller : t -> token_id

  val use_full_commitment : t -> bool

  val increment_nonce : t -> bool

  val check_authorization :
       commitment:transaction_commitment
    -> at_party:parties
    -> t
    -> [ `Proof_verifies of bool ] * [ `Signature_verifies of bool ]

  module Update : sig
    type _ set_or_keep

    type timing

    val timing : t -> timing set_or_keep

    type field

    val app_state : t -> field set_or_keep Zkapp_state.V.t

    type verification_key

    val verification_key : t -> verification_key set_or_keep

    type events

    val sequence_events : t -> events

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

module type Parties_intf = sig
  include Iffable

  type party

  module Opt : Opt_intf with type bool := bool

  val empty : unit -> t

  val is_empty : t -> bool

  val pop_exn : t -> (party * t) * t
end

module type Stack_frame_intf = sig
  type caller

  type parties

  include Iffable

  val caller : t -> caller

  val caller_caller : t -> caller

  val calls : t -> parties

  val make : caller:caller -> caller_caller:caller -> calls:parties -> t
end

module type Call_stack_intf = sig
  type stack_frame

  include Stack_intf with type elt := stack_frame
end

module type Ledger_intf = sig
  include Iffable

  type public_key

  type token_id

  type party

  type account

  type inclusion_proof

  val empty : depth:int -> unit -> t

  val get_account : party -> t -> account * inclusion_proof

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
  type bool

  type t

  type public_key

  module Permissions : sig
    type controller

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

module Eff = struct
  type (_, _) t =
    | Check_account_precondition :
        'party * 'account * 'local_state
        -> ( 'local_state
           , < bool : 'bool
             ; party : 'party
             ; account : 'account
             ; local_state : 'local_state
             ; .. > )
           t
    | Check_protocol_state_precondition :
        'protocol_state_pred * 'global_state
        -> ( 'bool
           , < bool : 'bool
             ; global_state : 'global_state
             ; protocol_state_precondition : 'protocol_state_pred
             ; .. > )
           t
    | Init_account :
        { party : 'party; account : 'account }
        -> ('account, < party : 'party ; account : 'account ; .. >) t
end

type 'e handler = { perform : 'r. ('r, 'e) Eff.t -> 'r }

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

  module Controller : Controller_intf with type bool := Bool.t

  module Global_slot : Global_slot_intf with type bool := Bool.t

  module Nonce : sig
    include Iffable with type bool := Bool.t

    val succ : t -> t
  end

  module State_hash : Iffable with type bool := Bool.t

  module Timing :
    Timing_intf with type bool := Bool.t and type global_slot := Global_slot.t

  module Verification_key : Iffable with type bool := Bool.t

  module Zkapp_uri : Iffable with type bool := Bool.t

  module Token_symbol : Iffable with type bool := Bool.t

  module Account :
    Account_intf
      with type Permissions.controller := Controller.t
       and type timing := Timing.t
       and type balance := Balance.t
       and type bool := Bool.t
       and type global_slot := Global_slot.t
       and type field := Field.t
       and type verification_key := Verification_key.t
       and type zkapp_uri := Zkapp_uri.t
       and type token_symbol := Token_symbol.t
       and type public_key := Public_key.t
       and type nonce := Nonce.t
       and type state_hash := State_hash.t
       and type token_id := Token_id.t

  module Events : Events_intf with type bool := Bool.t and type field := Field.t

  module Party :
    Party_intf
      with type signed_amount := Amount.Signed.t
       and type protocol_state_precondition := Protocol_state_precondition.t
       and type token_id := Token_id.t
       and type bool := Bool.t
       and type account := Account.t
       and type public_key := Public_key.t
       and type nonce := Nonce.t
       and type account_id := Account_id.t
       and type Update.timing := Timing.t
       and type 'a Update.set_or_keep := 'a Set_or_keep.t
       and type Update.field := Field.t
       and type Update.verification_key := Verification_key.t
       and type Update.events := Events.t
       and type Update.zkapp_uri := Zkapp_uri.t
       and type Update.token_symbol := Token_symbol.t
       and type Update.state_hash := State_hash.t
       and type Update.permissions := Account.Permissions.t

  module Nonce_precondition : sig
    val is_constant :
      Nonce.t Zkapp_precondition.Closed_interval.t Party.or_ignore -> Bool.t
  end

  module Ledger :
    Ledger_intf
      with type bool := Bool.t
       and type account := Account.t
       and type party := Party.t
       and type token_id := Token_id.t
       and type public_key := Public_key.t

  module Opt : Opt_intf with type bool := Bool.t

  module Parties :
    Parties_intf
      with type t = Party.parties
       and type bool := Bool.t
       and type party := Party.t
       and module Opt := Opt

  module Stack_frame :
    Stack_frame_intf
      with type bool := Bool.t
       and type parties := Parties.t
       and type caller := Token_id.t

  module Call_stack :
    Call_stack_intf
      with type stack_frame := Stack_frame.t
       and type bool := Bool.t
       and module Opt := Opt

  module Transaction_commitment : sig
    include
      Iffable with type bool := Bool.t and type t = Party.transaction_commitment

    val empty : t

    val commitment : other_parties:Parties.t -> t

    val full_commitment :
      party:Party.t -> memo_hash:Field.t -> commitment:t -> t
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

    val global_slot_since_genesis : t -> Global_slot.t
  end
end

module Start_data = struct
  open Core_kernel

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('parties, 'field) t = { parties : 'parties; memo_hash : 'field }
      [@@deriving sexp, yojson]
    end
  end]
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Ps = Inputs.Parties

  let default_caller = Token_id.default

  let stack_frame_default () =
    Stack_frame.make ~caller:default_caller ~caller_caller:default_caller
      ~calls:(Ps.empty ())

  let assert_ = Bool.Assert.is_true

  (* Pop from the call stack, returning dummy values if the stack is empty. *)
  let pop_call_stack (s : Call_stack.t) : Stack_frame.t * Call_stack.t =
    let res = Call_stack.pop s in
    (* Split out the option returned by Call_stack.pop into two options *)
    let next_frame, next_call_stack =
      (Opt.map ~f:fst res, Opt.map ~f:snd res)
    in
    (* Handle the None cases *)
    ( Opt.or_default ~if_:Stack_frame.if_ ~default:(stack_frame_default ())
        next_frame
    , Opt.or_default ~if_:Call_stack.if_ ~default:(Call_stack.empty ())
        next_call_stack )

  type get_next_party_result =
    { party : Party.t
    ; party_forest : Ps.t
    ; new_call_stack : Call_stack.t
    ; new_frame : Stack_frame.t
    }

  let get_next_party (current_forest : Stack_frame.t)
      (* The stack for the most recent snapp *)
        (call_stack : Call_stack.t) (* The partially-completed parent stacks *)
      : get_next_party_result =
    (* If the current stack is complete, 'return' to the previous
       partially-completed one.
    *)
    let current_forest, call_stack =
      let next_forest, next_call_stack =
        (* Invariant: call_stack contains only non-empty forests. *)
        pop_call_stack call_stack
      in
      (* TODO: I believe current should only be empty for the first party in
         a transaction. *)
      let current_is_empty = Ps.is_empty (Stack_frame.calls current_forest) in
      ( Stack_frame.if_ current_is_empty ~then_:next_forest ~else_:current_forest
      , Call_stack.if_ current_is_empty ~then_:next_call_stack ~else_:call_stack
      )
    in
    let (party, party_forest), remainder_of_current_forest =
      Ps.pop_exn (Stack_frame.calls current_forest)
    in
    let party_caller = Party.caller party in
    let is_normal_call =
      Token_id.equal party_caller (Stack_frame.caller current_forest)
    in
    let () =
      with_label ~label:"check valid caller" (fun () ->
          let is_delegate_call =
            Token_id.equal party_caller
              (Stack_frame.caller_caller current_forest)
          in
          (* Check that party has a valid caller. *)
          assert_ Bool.(is_normal_call ||| is_delegate_call) )
    in
    (* Cases:
       - [party_forest] is empty, [remainder_of_current_forest] is empty.
       Pop from the call stack to get another forest, which is guaranteed to be non-empty.
       The result of popping becomes the "current forest".
       - [party_forest] is empty, [remainder_of_current_forest] is non-empty.
       Push nothing to the stack. [remainder_of_current_forest] becomes new "current forest"
       - [party_forest] is non-empty, [remainder_of_current_forest] is empty.
       Push nothing to the stack. [party_forest] becomes new "current forest"
       - [party_forest] is non-empty, [remainder_of_current_forest] is non-empty:
       Push [remainder_of_current_forest] to the stack. [party_forest] becomes new "current forest".
    *)
    let party_forest_empty = Ps.is_empty party_forest in
    let remainder_of_current_forest_empty =
      Ps.is_empty remainder_of_current_forest
    in
    let newly_popped_frame, popped_call_stack = pop_call_stack call_stack in
    let remainder_of_current_forest_frame : Stack_frame.t =
      Stack_frame.make
        ~caller:(Stack_frame.caller current_forest)
        ~caller_caller:(Stack_frame.caller_caller current_forest)
        ~calls:remainder_of_current_forest
    in
    let new_call_stack =
      Call_stack.if_ party_forest_empty
        ~then_:
          (Call_stack.if_ remainder_of_current_forest_empty
             ~then_:
               (* Don't actually need the or_default used in this case. *)
               popped_call_stack ~else_:call_stack )
        ~else_:
          (Call_stack.if_ remainder_of_current_forest_empty ~then_:call_stack
             ~else_:
               (Call_stack.push remainder_of_current_forest_frame
                  ~onto:call_stack ) )
    in
    let new_frame =
      Stack_frame.if_ party_forest_empty
        ~then_:
          (Stack_frame.if_ remainder_of_current_forest_empty
             ~then_:newly_popped_frame ~else_:remainder_of_current_forest_frame )
        ~else_:
          (let caller =
             Token_id.if_ is_normal_call
               ~then_:
                 (Account_id.derive_token_id ~owner:(Party.account_id party))
               ~else_:(Stack_frame.caller current_forest)
           and caller_caller = party_caller in
           Stack_frame.make ~calls:party_forest ~caller ~caller_caller )
    in
    { party; party_forest; new_frame; new_call_stack }

  let apply ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(is_start : [ `Yes of _ Start_data.t | `No | `Compute of _ Start_data.t ])
      (h :
        (< global_state : Global_state.t
         ; transaction_commitment : Transaction_commitment.t
         ; full_transaction_commitment : Transaction_commitment.t
         ; amount : Amount.t
         ; bool : Bool.t
         ; failure : Bool.failure_status
         ; .. >
         as
         'env )
        handler )
      ((global_state : Global_state.t), (local_state : Local_state.t)) =
    let open Inputs in
    let is_start' =
      let is_start' = Ps.is_empty (Stack_frame.calls local_state.stack_frame) in
      ( match is_start with
      | `Compute _ ->
          ()
      | `Yes _ ->
          assert_ is_start'
      | `No ->
          assert_ (Bool.not is_start') ) ;
      match is_start with
      | `Yes _ ->
          Bool.true_
      | `No ->
          Bool.false_
      | `Compute _ ->
          is_start'
    in
    let local_state =
      { local_state with
        ledger =
          Inputs.Ledger.if_ is_start'
            ~then_:(Inputs.Global_state.ledger global_state)
            ~else_:local_state.ledger
      }
    in
    let ( (party, remaining, call_stack)
        , at_party
        , local_state
        , (a, inclusion_proof) ) =
      let to_pop, call_stack =
        match is_start with
        | `Compute start_data ->
            ( Stack_frame.if_ is_start'
                ~then_:
                  (Stack_frame.make ~calls:start_data.parties
                     ~caller:default_caller ~caller_caller:default_caller )
                ~else_:local_state.stack_frame
            , Call_stack.if_ is_start' ~then_:(Call_stack.empty ())
                ~else_:local_state.call_stack )
        | `Yes start_data ->
            ( Stack_frame.make ~calls:start_data.parties ~caller:default_caller
                ~caller_caller:default_caller
            , Call_stack.empty () )
        | `No ->
            (local_state.stack_frame, local_state.call_stack)
      in
      let { party
          ; party_forest = at_party
          ; new_frame = remaining
          ; new_call_stack = call_stack
          } =
        with_label ~label:"get next party" (fun () ->
            (* TODO: Make the stack frame hashed inside of the local state *)
            get_next_party to_pop call_stack )
      in
      let local_state =
        with_label ~label:"token owner not caller" (fun () ->
            let default_token_or_token_owner_was_caller =
              (* Check that the token owner was consulted if using a non-default
                 token *)
              let party_token_id = Party.token_id party in
              Bool.( ||| )
                (Token_id.equal party_token_id Token_id.default)
                (Token_id.equal party_token_id (Party.caller party))
            in
            Local_state.add_check local_state Token_owner_not_caller
              default_token_or_token_owner_was_caller )
      in
      let ((a, inclusion_proof) as acct) =
        with_label ~label:"get account" (fun () ->
            Inputs.Ledger.get_account party local_state.ledger )
      in
      Inputs.Ledger.check_inclusion local_state.ledger (a, inclusion_proof) ;
      let transaction_commitment, full_transaction_commitment =
        match is_start with
        | `No ->
            ( local_state.transaction_commitment
            , local_state.full_transaction_commitment )
        | `Yes start_data | `Compute start_data ->
            let tx_commitment_on_start =
              Transaction_commitment.commitment
                ~other_parties:(Stack_frame.calls remaining)
            in
            let full_tx_commitment_on_start =
              Transaction_commitment.full_commitment ~party
                ~memo_hash:start_data.memo_hash
                ~commitment:tx_commitment_on_start
            in
            let tx_commitment =
              Transaction_commitment.if_ is_start' ~then_:tx_commitment_on_start
                ~else_:local_state.transaction_commitment
            in
            let full_tx_commitment =
              Transaction_commitment.if_ is_start'
                ~then_:full_tx_commitment_on_start
                ~else_:local_state.full_transaction_commitment
            in
            (tx_commitment, full_tx_commitment)
      in
      let local_state =
        { local_state with
          transaction_commitment
        ; full_transaction_commitment
        ; token_id =
            Token_id.if_ is_start' ~then_:Token_id.default
              ~else_:local_state.token_id
        }
      in
      ((party, remaining, call_stack), at_party, local_state, acct)
    in
    let local_state =
      { local_state with stack_frame = remaining; call_stack }
    in
    let local_state = Local_state.add_new_failure_status_bucket local_state in
    Inputs.Ledger.check_inclusion local_state.ledger (a, inclusion_proof) ;
    (* Register verification key, in case it needs to be 'side-loaded' to
       verify a snapp proof.
    *)
    Account.register_verification_key a ;
    let local_state =
      h.perform (Check_account_precondition (party, a, local_state))
    in
    let protocol_state_predicate_satisfied =
      h.perform
        (Check_protocol_state_precondition
           (Party.protocol_state_precondition party, global_state) )
    in
    let local_state =
      Local_state.add_check local_state Protocol_state_precondition_unsatisfied
        protocol_state_predicate_satisfied
    in
    let `Proof_verifies proof_verifies, `Signature_verifies signature_verifies =
      let commitment =
        Inputs.Transaction_commitment.if_
          (Inputs.Party.use_full_commitment party)
          ~then_:local_state.full_transaction_commitment
          ~else_:local_state.transaction_commitment
      in
      Inputs.Party.check_authorization ~commitment ~at_party party
    in
    (* The fee-payer must increment their nonce. *)
    let local_state =
      Local_state.add_check local_state Fee_payer_nonce_must_increase
        Inputs.Bool.(Inputs.Party.increment_nonce party ||| not is_start')
    in
    let local_state =
      Local_state.add_check local_state Fee_payer_must_be_signed
        Inputs.Bool.(signature_verifies ||| not is_start')
    in
    let local_state =
      let precondition_has_constant_nonce =
        Inputs.Party.Account_precondition.nonce party
        |> Inputs.Nonce_precondition.is_constant
      in
      let increments_nonce_and_constrains_its_old_value =
        Inputs.Bool.(
          Inputs.Party.increment_nonce party &&& precondition_has_constant_nonce)
      in
      let depends_on_the_fee_payers_nonce_and_isnt_the_fee_payer =
        Inputs.Bool.(Inputs.Party.use_full_commitment party &&& not is_start')
      in
      let does_not_use_a_signature = Inputs.Bool.not signature_verifies in
      Local_state.add_check local_state Parties_replay_check_failed
        Inputs.Bool.(
          increments_nonce_and_constrains_its_old_value
          ||| depends_on_the_fee_payers_nonce_and_isnt_the_fee_payer
          ||| does_not_use_a_signature)
    in
    let (`Is_new account_is_new) =
      Inputs.Ledger.check_account (Party.public_key party)
        (Party.token_id party) (a, inclusion_proof)
    in
    let a = Account.set_token_id a (Party.token_id party) in
    let party_token = Party.token_id party in
    let party_token_is_default = Token_id.(equal default) party_token in
    let account_is_untimed = Bool.not (Account.is_timed a) in
    (* Set account timing for new accounts, if specified. *)
    let a, local_state =
      let timing = Party.Update.timing party in
      let local_state =
        Local_state.add_check local_state
          Update_not_permitted_timing_existing_account
          Bool.(
            Set_or_keep.is_keep timing
            ||| (account_is_untimed &&& signature_verifies))
      in
      let timing =
        Set_or_keep.set_or_keep ~if_:Timing.if_ timing (Account.timing a)
      in
      let vesting_period = Timing.vesting_period timing in
      (* Assert that timing is valid, otherwise we may have a division by 0. *)
      assert_ Global_slot.(vesting_period > zero) ;
      let a = Account.set_timing a timing in
      (a, local_state)
    in
    (* Apply balance change. *)
    let a, local_state =
      let balance_change = Party.balance_change party in
      let balance, `Overflow failed1 =
        Balance.add_signed_amount_flagged (Account.balance a) balance_change
      in
      (* TODO: Should this report 'insufficient balance'? *)
      let local_state =
        Local_state.add_check local_state Overflow (Bool.not failed1)
      in
      let local_state =
        (* Conditionally subtract account creation fee from fee excess *)
        let account_creation_fee =
          Amount.of_constant_fee constraint_constants.account_creation_fee
        in
        let excess_minus_creation_fee, `Overflow excess_update_failed =
          Amount.Signed.add_flagged local_state.excess
            Amount.Signed.(negate (of_unsigned account_creation_fee))
        in
        let local_state =
          Local_state.add_check local_state
            Amount_insufficient_to_create_account
            Bool.(not (account_is_new &&& excess_update_failed))
        in
        { local_state with
          excess =
            Amount.Signed.if_ account_is_new ~then_:excess_minus_creation_fee
              ~else_:local_state.excess
        }
      in
      let is_receiver = Amount.Signed.is_pos balance_change in
      let local_state =
        let controller =
          Controller.if_ is_receiver
            ~then_:(Account.Permissions.receive a)
            ~else_:(Account.Permissions.send a)
        in
        let has_permission =
          Controller.check ~proof_verifies ~signature_verifies controller
        in
        Local_state.add_check local_state Update_not_permitted_balance
          Bool.(
            has_permission
            ||| Amount.Signed.(equal (of_unsigned Amount.zero) balance_change))
      in
      let a = Account.set_balance balance a in
      (a, local_state)
    in
    let txn_global_slot = Global_state.global_slot_since_genesis global_state in
    (* Check timing with current balance *)
    let a, local_state =
      let `Invalid_timing invalid_timing, timing =
        match Account.check_timing ~txn_global_slot a with
        | `Insufficient_balance _, _ ->
            failwith "Did not propose a balance change at this timing check!"
        | `Invalid_timing invalid_timing, timing ->
            (* NB: Have to destructure to remove the possibility of
               [`Insufficient_balance _] in the type.
            *)
            (`Invalid_timing invalid_timing, timing)
      in
      let positive_balance_change =
        Amount.Signed.is_pos @@ Party.balance_change party
      in
      let local_state =
        Local_state.add_check local_state Source_minimum_balance_violation
          Bool.(not (positive_balance_change &&& invalid_timing))
      in
      let a = Account.set_timing a timing in
      (a, local_state)
    in
    (* Transform into a snapp account.
       This must be done before updating snapp fields!
    *)
    let a = Account.make_zkapp a in
    (* Update app state. *)
    let a, local_state =
      let app_state = Party.Update.app_state party in
      let keeping_app_state =
        Bool.all
          (List.map ~f:Set_or_keep.is_keep
             (Pickles_types.Vector.to_list app_state) )
      in
      let changing_entire_app_state =
        Bool.all
          (List.map ~f:Set_or_keep.is_set
             (Pickles_types.Vector.to_list app_state) )
      in
      let proved_state =
        (* The [proved_state] tracks whether the app state has been entirely
           determined by proofs ([true] if so), to allow snapp authors to be
           confident that their initialization logic has been run, rather than
           some malicious deployer instantiating the snapp in an account with
           some fake non-initial state.
           The logic here is:
           * if the state is unchanged, keep the previous value;
           * if the state has been entriely replaced, and the authentication
             was a proof, the state has been 'proved' and [proved_state] is set
             to [true];
           * if the state has been partially updated by a proof, the
             [proved_state] is unchanged;
           * if the state has been changed by some authentication other than a
             proof, the state is considered to have been tampered with, and
             [proved_state] is reset to [false].
        *)
        Bool.if_ keeping_app_state ~then_:(Account.proved_state a)
          ~else_:
            (Bool.if_ proof_verifies
               ~then_:
                 (Bool.if_ changing_entire_app_state ~then_:Bool.true_
                    ~else_:(Account.proved_state a) )
               ~else_:Bool.false_ )
      in
      let a = Account.set_proved_state proved_state a in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.edit_state a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_app_state
          Bool.(keeping_app_state ||| has_permission)
      in
      let app_state =
        Pickles_types.Vector.map2 app_state (Account.app_state a)
          ~f:(Set_or_keep.set_or_keep ~if_:Field.if_)
      in
      let a = Account.set_app_state app_state a in
      (a, local_state)
    in
    (* Set verification key. *)
    let a, local_state =
      let verification_key = Party.Update.verification_key party in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_verification_key a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_verification_key
          Bool.(Set_or_keep.is_keep verification_key ||| has_permission)
      in
      let verification_key =
        Set_or_keep.set_or_keep ~if_:Verification_key.if_ verification_key
          (Account.verification_key a)
      in
      let a = Account.set_verification_key verification_key a in
      (a, local_state)
    in
    (* Update sequence state. *)
    let a, local_state =
      let sequence_events = Party.Update.sequence_events party in
      let [ s1'; s2'; s3'; s4'; s5' ] = Account.sequence_state a in
      let last_sequence_slot = Account.last_sequence_slot a in
      (* Push events to s1. *)
      let is_empty = Events.is_empty sequence_events in
      let s1_updated = Events.push_events s1' sequence_events in
      let s1 = Field.if_ is_empty ~then_:s1' ~else_:s1_updated in
      (* Shift along if last update wasn't this slot *)
      let is_this_slot = Global_slot.equal txn_global_slot last_sequence_slot in
      let is_full_and_different_slot = Bool.((not is_empty) &&& is_this_slot) in
      let s5 = Field.if_ is_full_and_different_slot ~then_:s5' ~else_:s4' in
      let s4 = Field.if_ is_full_and_different_slot ~then_:s4' ~else_:s3' in
      let s3 = Field.if_ is_full_and_different_slot ~then_:s3' ~else_:s2' in
      let s2 = Field.if_ is_full_and_different_slot ~then_:s2' ~else_:s1' in
      let last_sequence_slot =
        Global_slot.if_ is_empty ~then_:last_sequence_slot
          ~else_:txn_global_slot
      in
      let sequence_state =
        ([ s1; s2; s3; s4; s5 ] : _ Pickles_types.Vector.t)
      in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.edit_sequence_state a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_sequence_state
          Bool.(is_empty ||| has_permission)
      in
      let a =
        a
        |> Account.set_sequence_state sequence_state
        |> Account.set_last_sequence_slot last_sequence_slot
      in
      (a, local_state)
    in
    (* Reset snapp state to [None] if it is unmodified. *)
    let a = Account.unmake_zkapp a in
    (* Update snapp URI. *)
    let a, local_state =
      let zkapp_uri = Party.Update.zkapp_uri party in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_zkapp_uri a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_zkapp_uri
          Bool.(Set_or_keep.is_keep zkapp_uri ||| has_permission)
      in
      let zkapp_uri =
        Set_or_keep.set_or_keep ~if_:Zkapp_uri.if_ zkapp_uri
          (Account.zkapp_uri a)
      in
      let a = Account.set_zkapp_uri zkapp_uri a in
      (a, local_state)
    in
    (* Update token symbol. *)
    let a, local_state =
      let token_symbol = Party.Update.token_symbol party in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_token_symbol a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_token_symbol
          Bool.(Set_or_keep.is_keep token_symbol ||| has_permission)
      in
      let token_symbol =
        Set_or_keep.set_or_keep ~if_:Token_symbol.if_ token_symbol
          (Account.token_symbol a)
      in
      let a = Account.set_token_symbol token_symbol a in
      (a, local_state)
    in
    (* Update delegate. *)
    let a, local_state =
      let delegate = Party.Update.delegate party in
      let base_delegate =
        let should_set_new_account_delegate =
          (* Only accounts for the default token may delegate. *)
          Bool.(account_is_new &&& party_token_is_default)
        in
        (* New accounts should have the delegate equal to the public key of the
           account.
        *)
        Public_key.if_ should_set_new_account_delegate
          ~then_:(Party.public_key party) ~else_:(Account.delegate a)
      in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_delegate a)
      in
      let local_state =
        (* Note: only accounts for the default token can delegate. *)
        Local_state.add_check local_state Update_not_permitted_delegate
          Bool.(
            Set_or_keep.is_keep delegate
            ||| (has_permission &&& party_token_is_default))
      in
      let delegate =
        Set_or_keep.set_or_keep ~if_:Public_key.if_ delegate base_delegate
      in
      let a = Account.set_delegate delegate a in
      (a, local_state)
    in
    (* Update nonce. *)
    let a, local_state =
      let nonce = Account.nonce a in
      let increment_nonce = Party.increment_nonce party in
      let nonce =
        Nonce.if_ increment_nonce ~then_:(Nonce.succ nonce) ~else_:nonce
      in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.increment_nonce a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_nonce
          Bool.((not increment_nonce) ||| has_permission)
      in
      let a = Account.set_nonce nonce a in
      (a, local_state)
    in
    (* Update voting-for. *)
    let a, local_state =
      let voting_for = Party.Update.voting_for party in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_voting_for a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_voting_for
          Bool.(Set_or_keep.is_keep voting_for ||| has_permission)
      in
      let voting_for =
        Set_or_keep.set_or_keep ~if_:State_hash.if_ voting_for
          (Account.voting_for a)
      in
      let a = Account.set_voting_for voting_for a in
      (a, local_state)
    in
    (* Finally, update permissions.
       This should be the last update applied, to ensure that any earlier
       updates use the account's existing permissions, and not permissions that
       are specified by the party!
    *)
    let a, local_state =
      let permissions = Party.Update.permissions party in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_permissions a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_permissions
          Bool.(Set_or_keep.is_keep permissions ||| has_permission)
      in
      let permissions =
        Set_or_keep.set_or_keep ~if_:Account.Permissions.if_ permissions
          (Account.permissions a)
      in
      let a = Account.set_permissions permissions a in
      (a, local_state)
    in
    (* Initialize account's pk, in case it is new. *)
    let a = h.perform (Init_account { party; account = a }) in
    (* DO NOT ADD ANY UPDATES HERE. They must be earlier in the code.
       See comment above.
    *)
    let local_delta =
      (* NOTE: It is *not* correct to use the actual change in balance here.
         Indeed, if the account creation fee is paid, using that amount would
         be equivalent to paying it out to the block producer.
         In the case of a failure that prevents any updates from being applied,
         every other party in this transaction will also fail, and the excess
         will never be promoted to the global excess, so this amount is
         irrelevant.
      *)
      Amount.Signed.negate (Party.balance_change party)
    in
    let new_local_fee_excess, `Overflow overflowed =
      let curr_token : Token_id.t = local_state.token_id in
      let curr_is_default = Token_id.(equal default) curr_token in
      (* We only allow the default token for fees. *)
      assert_ curr_is_default ;
      Bool.(
        assert_
          ( (not is_start')
          ||| (party_token_is_default &&& Amount.Signed.is_pos local_delta) )) ;
      let new_local_fee_excess, `Overflow overflow =
        Amount.Signed.add_flagged local_state.excess local_delta
      in
      ( Amount.Signed.if_ party_token_is_default ~then_:new_local_fee_excess
          ~else_:local_state.excess
      , (* No overflow if we aren't using the result of the addition (which we don't in the case that party token is not default). *)
        `Overflow (Bool.( &&& ) party_token_is_default overflow) )
    in
    let local_state = { local_state with excess = new_local_fee_excess } in
    let local_state =
      Local_state.add_check local_state Local_excess_overflow
        (Bool.not overflowed)
    in

    (* If a's token ID differs from that in the local state, then
       the local state excess gets moved into the execution state's fee excess.

       If there are more parties to execute after this one, then the local delta gets
       accumulated in the local state.

       If there are no more parties to execute, then we do the same as if we switch tokens.
       The local state excess (plus the local delta) gets moved to the fee excess if it is default token.
    *)
    let new_ledger =
      Inputs.Ledger.set_account local_state.ledger (a, inclusion_proof)
    in
    let is_last_party = Ps.is_empty (Stack_frame.calls remaining) in
    let local_state =
      { local_state with
        ledger = new_ledger
      ; transaction_commitment =
          Transaction_commitment.if_ is_last_party
            ~then_:Transaction_commitment.empty
            ~else_:local_state.transaction_commitment
      ; full_transaction_commitment =
          Transaction_commitment.if_ is_last_party
            ~then_:Transaction_commitment.empty
            ~else_:local_state.full_transaction_commitment
      }
    in
    let valid_fee_excess =
      let delta_settled =
        Amount.Signed.equal local_state.excess Amount.(Signed.of_unsigned zero)
      in
      Bool.((not is_last_party) ||| delta_settled)
    in
    let local_state =
      Local_state.add_check local_state Invalid_fee_excess valid_fee_excess
    in
    let update_local_excess = Bool.(is_start' ||| is_last_party) in
    let update_global_state =
      Bool.(update_local_excess &&& local_state.success)
    in
    let global_state, global_excess_update_failed, update_global_state =
      let amt = Global_state.fee_excess global_state in
      let res, `Overflow overflow =
        Amount.Signed.add_flagged amt local_state.excess
      in
      let global_excess_update_failed =
        Bool.(update_global_state &&& overflow)
      in
      let update_global_state = Bool.(update_global_state &&& not overflow) in
      let new_amt =
        Amount.Signed.if_ update_global_state ~then_:res ~else_:amt
      in
      ( Global_state.set_fee_excess global_state new_amt
      , global_excess_update_failed
      , update_global_state )
    in
    let local_state =
      { local_state with
        excess =
          Amount.Signed.if_ update_local_excess
            ~then_:Amount.(Signed.of_unsigned zero)
            ~else_:local_state.excess
      }
    in
    let local_state =
      Local_state.add_check local_state Global_excess_overflow
        Bool.(not global_excess_update_failed)
    in
    (* The first party must succeed. *)
    Bool.(
      assert_with_failure_status_tbl
        ((not is_start') ||| local_state.success)
        local_state.failure_status_tbl) ;
    let global_state =
      Global_state.set_ledger ~should_update:update_global_state global_state
        local_state.ledger
    in
    let local_state =
      (* Make sure to reset the local_state at the end of a transaction.
         The following fields are already reset
         - parties
         - transaction_commitment
         - full_transaction_commitment
         - excess
         so we need to reset
         - token_id = Token_id.default
         - ledger = Frozen_ledger_hash.empty_hash
         - success = true
      *)
      { local_state with
        token_id =
          Token_id.if_ is_last_party ~then_:Token_id.default
            ~else_:local_state.token_id
      ; ledger =
          Inputs.Ledger.if_ is_last_party
            ~then_:
              (Inputs.Ledger.empty ~depth:constraint_constants.ledger_depth ())
            ~else_:local_state.ledger
      ; success =
          Bool.if_ is_last_party ~then_:Bool.true_ ~else_:local_state.success
      }
    in
    (global_state, local_state)

  let step h state = apply ~is_start:`No h state

  let start start_data h state = apply ~is_start:(`Yes start_data) h state
end
