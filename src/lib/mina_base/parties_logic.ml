(* parties_logic.ml *)

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

  val assert_ : t -> unit
end

module type Amount_intf = sig
  include Iffable

  type unsigned = t

  module Signed : sig
    include Iffable with type bool := bool

    val is_pos : t -> bool

    val negate : t -> t

    val add_flagged : t -> t -> t * [ `Overflow of bool ]

    val of_unsigned : unsigned -> t
  end

  val zero : t

  val add_flagged : t -> t -> t * [ `Overflow of bool ]

  val add_signed_flagged : t -> Signed.t -> t * [ `Overflow of bool ]
end

module type Token_id_intf = sig
  include Iffable

  val equal : t -> t -> bool

  val invalid : t

  val default : t
end

module Local_state = struct
  open Core_kernel

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ( 'parties
           , 'token_id
           , 'excess
           , 'ledger
           , 'bool
           , 'comm
           , 'failure_status )
           t =
        { parties : 'parties
        ; call_stack : 'parties
        ; transaction_commitment : 'comm
        ; token_id : 'token_id
        ; excess : 'excess
        ; ledger : 'ledger
        ; success : 'bool
        ; failure_status : 'failure_status
        }
      [@@deriving compare, equal, hash, sexp, yojson, fields, hlist]
    end
  end]

  let typ parties token_id excess ledger bool comm failure_status =
    Pickles.Impls.Step.Typ.of_hlistable
      [ parties; parties; comm; token_id; excess; ledger; bool; failure_status ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Value = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Parties.Digest.Stable.V1.t
          , Token_id.Stable.V1.t
          , Currency.Amount.Stable.V1.t
          , Ledger_hash.Stable.V1.t
          , bool
          , Parties.Transaction_commitment.Stable.V1.t
          , Transaction_status.Failure.Stable.V1.t option )
          Stable.V1.t
        [@@deriving compare, equal, hash, sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Checked = struct
    open Pickles.Impls.Step

    type t =
      ( Field.t
      , Token_id.Checked.t
      , Currency.Amount.Checked.t
      , Ledger_hash.var
      , Boolean.var
      , Parties.Transaction_commitment.Checked.t
      , unit )
      Stable.Latest.t
  end
end

module type Party_intf = sig
  type t

  type signed_amount

  val delta : t -> signed_amount
end

module type Parties_intf = sig
  include Iffable

  module Opt : sig
    type 'a t

    val is_some : 'a t -> bool

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val or_default :
      if_:(bool -> then_:'a -> else_:'a -> 'a) -> 'a t -> default:'a -> 'a

    val or_exn : 'a t -> 'a
  end

  type party_or_stack

  type party

  val empty : t

  val is_empty : t -> bool

  val pop_exn : t -> party_or_stack * t

  val as_stack : party_or_stack -> t Opt.t

  val pop_party_exn : t -> party * t

  val pop_stack : t -> (t * t) Opt.t

  val push_stack : t -> onto:t -> t
end

module type Ledger_intf = sig
  include Iffable

  val empty : depth:int -> unit -> t
end

module Eff = struct
  type (_, _) t =
    | Get_account :
        'party * 'ledger
        -> ( 'account * 'inclusion_proof
           , < party : 'party
             ; account : 'account
             ; inclusion_proof : 'inclusion_proof
             ; ledger : 'ledger
             ; .. > )
           t
    | Check_inclusion :
        'ledger * 'account * 'inclusion_proof
        -> ( unit
           , < ledger : 'ledger
             ; inclusion_proof : 'inclusion_proof
             ; account : 'account
             ; .. > )
           t
    | Check_predicate :
        'bool * 'party * 'account * 'global_state
        -> ( 'bool
           , < bool : 'bool
             ; party : 'party
             ; account : 'account
             ; global_state : 'global_state
             ; .. > )
           t
    | Check_protocol_state_predicate :
        'protocol_state_pred * 'global_state
        -> ( 'bool
           , < bool : 'bool
             ; global_state : 'global_state
             ; protocol_state_predicate : 'protocol_state_pred
             ; .. > )
           t
    | Set_account :
        'ledger * 'account * 'inclusion_proof
        -> ( 'ledger
           , < ledger : 'ledger
             ; inclusion_proof : 'inclusion_proof
             ; account : 'account
             ; .. > )
           t
    | Get_global_ledger :
        'global_state
        -> ('ledger, < global_state : 'global_state ; ledger : 'ledger ; .. >) t
    | Modify_global_excess :
        'global_state * ('signed_amount -> 'signed_amount)
        -> ( 'global_state
           , < global_state : 'global_state
             ; signed_amount : 'signed_amount
             ; .. > )
           t
    | Modify_global_ledger :
        { global_state : 'global_state
        ; ledger : 'ledger
        ; should_update : 'bool
        }
        -> ( 'global_state
           , < bool : 'bool
             ; global_state : 'global_state
             ; ledger : 'ledger
             ; .. > )
           t
    | Party_token_id :
        'party
        -> ('token_id, < party : 'party ; token_id : 'token_id ; .. >) t
    | Check_auth_and_update_account :
        { is_start : 'bool
        ; party : 'party
        ; account : 'account
        ; transaction_commitment : 'transaction_commitment
        ; at_party : 'parties
        ; global_state : 'global_state
        ; inclusion_proof : 'ip
        }
        -> ( 'account * 'bool * 'failure
           , < inclusion_proof : 'ip
             ; bool : 'bool
             ; party : 'party
             ; parties : 'parties
             ; transaction_commitment : 'transaction_commitment
             ; account : 'account
             ; global_state : 'global_state
             ; failure : 'failure
             ; .. > )
           t
    | Balance :
        'account
        -> ('amount, < account : 'account ; amount : 'amount ; .. >) t
    | Transaction_commitment_on_start :
        { protocol_state_predicate : 'protocol_state_pred
        ; other_parties : 'parties
        ; memo_hash : 'field
        }
        -> ( 'transaction_commitment
           , < party : 'party
             ; parties : 'parties
             ; bool : 'bool
             ; protocol_state_predicate : 'protocol_state_pred
             ; transaction_commitment : 'transaction_commitment
             ; field : 'field
             ; .. > )
           t
end

type 'e handler = { perform : 'r. ('r, 'e) Eff.t -> 'r }

module type Inputs_intf = sig
  module Bool : Bool_intf

  module Ledger : Ledger_intf with type bool := Bool.t

  module Account : sig
    type t
  end

  module Amount : Amount_intf with type bool := Bool.t

  module Token_id : Token_id_intf with type bool := Bool.t

  module Party : Party_intf with type signed_amount := Amount.Signed.t

  module Parties :
    Parties_intf with type bool := Bool.t and type party := Party.t

  module Transaction_commitment : sig
    include Iffable with type bool := Bool.t

    val empty : t
  end
end

module Start_data = struct
  open Core_kernel

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('parties, 'protocol_state_pred, 'field) t =
        { parties : 'parties
        ; protocol_state_predicate : 'protocol_state_pred
        ; memo_hash : 'field
        }
      [@@deriving sexp, yojson]
    end
  end]
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Ps = Inputs.Parties

  let get_next_party
      (current_stack : Ps.t) (* The stack for the most recent snapp *)
      (call_stack : Ps.t) (* The partially-completed parent stacks *) =
    (* Invariant: [call_stack] only contains stacks. *)
    let next_stack, next_call_stack =
      let res = Ps.pop_stack call_stack in
      let next_stack =
        Ps.Opt.or_default ~if_:Ps.if_ ~default:Ps.empty (Ps.Opt.map ~f:fst res)
      in
      let next_call_stack =
        Ps.Opt.or_default ~if_:Ps.if_ ~default:Ps.empty (Ps.Opt.map ~f:snd res)
      in
      (next_stack, next_call_stack)
    in
    (* If the current stack is complete, 'return' to the previous
       partially-completed one.
    *)
    let current_stack, call_stack =
      let current_is_empty = Ps.is_empty current_stack in
      ( Ps.if_ current_is_empty ~then_:next_stack ~else_:current_stack
      , Ps.if_ current_is_empty ~then_:next_call_stack ~else_:call_stack )
    in
    let stack_or_party, next_stack = Ps.pop_exn current_stack in
    let party, remaining_stack =
      let as_stack = Ps.as_stack stack_or_party in
      let stack =
        Ps.Opt.or_default ~if_:Ps.if_ ~default:current_stack as_stack
      in
      let popped_value, remaining_stack = Ps.pop_party_exn stack in
      ( popped_value
      , Ps.if_ (Ps.Opt.is_some as_stack) ~then_:remaining_stack ~else_:Ps.empty
      )
    in
    let current_stack, next_stack =
      let is_empty = Ps.is_empty remaining_stack in
      ( Ps.if_ is_empty ~then_:next_stack ~else_:remaining_stack
      , Ps.if_ is_empty ~then_:Ps.empty ~else_:next_stack )
    in
    let call_stack =
      let is_empty = Ps.is_empty next_stack in
      Ps.if_ is_empty ~then_:call_stack
        ~else_:(Ps.push_stack next_stack ~onto:call_stack)
    in
    (party, current_stack, call_stack)

  let apply (type global_state failure_status)
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(is_start :
         [ `Yes of _ Start_data.t | `No | `Compute of _ Start_data.t ])
      (h :
        (< global_state : global_state
         ; transaction_commitment : Transaction_commitment.t
         ; amount : Amount.t
         ; bool : Bool.t
         ; failure : failure_status
         ; .. >
         as
         'env)
        handler) ((global_state : global_state), (local_state : _ Local_state.t))
      =
    let open Inputs in
    let is_start' =
      let is_start' = Ps.is_empty local_state.parties in
      ( match is_start with
      | `Compute _ ->
          ()
      | `Yes _ ->
          Bool.assert_ is_start'
      | `No ->
          Bool.assert_ (Bool.not is_start') ) ;
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
            ~then_:(h.perform (Get_global_ledger global_state))
            ~else_:local_state.ledger
      }
    in
    let protocol_state_predicate_satisfied =
      match is_start with
      | `Yes start_data | `Compute start_data ->
          h.perform
            (Check_protocol_state_predicate
               (start_data.protocol_state_predicate, global_state))
      | `No ->
          Bool.true_
    in
    let (party, remaining, call_stack), at_party, local_state =
      let to_pop, call_stack =
        match is_start with
        | `Compute start_data ->
            ( Ps.if_ is_start' ~then_:start_data.parties
                ~else_:local_state.parties
            , Ps.if_ is_start' ~then_:Ps.empty ~else_:local_state.call_stack )
        | `Yes start_data ->
            (start_data.parties, Ps.empty)
        | `No ->
            (local_state.parties, local_state.call_stack)
      in
      let party, remaining, call_stack = get_next_party to_pop call_stack in
      let transaction_commitment =
        match is_start with
        | `No ->
            local_state.transaction_commitment
        | `Yes start_data | `Compute start_data ->
            let on_start =
              h.perform
                (Transaction_commitment_on_start
                   { protocol_state_predicate =
                       start_data.protocol_state_predicate
                   ; other_parties = remaining
                   ; memo_hash = start_data.memo_hash
                   })
            in
            Transaction_commitment.if_ is_start' ~then_:on_start
              ~else_:local_state.transaction_commitment
      in
      let local_state =
        { local_state with
          transaction_commitment
        ; token_id =
            Token_id.if_ is_start' ~then_:Token_id.default
              ~else_:local_state.token_id
        }
      in
      ((party, remaining, call_stack), to_pop, local_state)
    in
    let local_state = { local_state with parties = remaining; call_stack } in
    let a, inclusion_proof =
      h.perform (Get_account (party, local_state.ledger))
    in
    h.perform (Check_inclusion (local_state.ledger, a, inclusion_proof)) ;
    let predicate_satisfied : Bool.t =
      h.perform (Check_predicate (is_start', party, a, global_state))
    in
    let a', update_permitted, failure_status =
      h.perform
        (Check_auth_and_update_account
           { is_start = is_start'
           ; at_party
           ; global_state
           ; party
           ; account = a
           ; transaction_commitment = local_state.transaction_commitment
           ; inclusion_proof
           })
    in
    let party_succeeded =
      Bool.(
        protocol_state_predicate_satisfied &&& predicate_satisfied
        &&& update_permitted)
    in
    (* The first party must succeed. *)
    Bool.(assert_ ((not is_start') ||| party_succeeded)) ;
    let local_state =
      { local_state with
        success = Bool.( &&& ) local_state.success party_succeeded
      }
    in
    let local_delta =
      (* NOTE: It is *not* correct to use the actual change in balance here.
         Indeed, if the account creation fee is paid, using that amount would
         be equivalent to paying it out to the block producer.
         In the case of a failure that prevents any updates from being applied,
         every other party in this transaction will also fail, and the excess
         will never be promoted to the global excess, so this amount is
         irrelevant.
      *)
      Amount.Signed.negate (Party.delta party)
    in
    let party_token = h.perform (Party_token_id party) in
    Bool.(assert_ (not (Token_id.(equal invalid) party_token))) ;
    let new_local_fee_excess, `Overflow overflowed =
      let curr_token : Token_id.t = local_state.token_id in
      let curr_is_default = Token_id.(equal default) curr_token in
      let party_is_default = Token_id.(equal default) party_token in
      Bool.(
        assert_
          ( (not is_start')
          ||| (party_is_default &&& Amount.Signed.is_pos local_delta) )) ;
      (* FIXME: Allow non-default tokens again. *)
      Bool.(assert_ (party_is_default &&& curr_is_default)) ;
      Amount.add_signed_flagged local_state.excess local_delta
    in
    (* The first party must succeed. *)
    Bool.(assert_ (not (is_start' &&& overflowed))) ;
    let local_state =
      { local_state with
        excess = new_local_fee_excess
      ; success = Bool.(local_state.success &&& not overflowed)
      ; failure_status
      }
    in

    (* If a's token ID differs from that in the local state, then
       the local state excess gets moved into the execution state's fee excess.

       If there are more parties to execute after this one, then the local delta gets
       accumulated in the local state.

       If there are no more parties to execute, then we do the same as if we switch tokens.
       The local state excess (plus the local delta) gets moved to the fee excess if it is default token.
    *)
    let new_ledger =
      h.perform (Set_account (local_state.ledger, a', inclusion_proof))
    in
    let is_last_party = Ps.is_empty remaining in
    let local_state =
      { local_state with
        ledger = new_ledger
      ; transaction_commitment =
          Transaction_commitment.if_ is_last_party
            ~then_:Transaction_commitment.empty
            ~else_:local_state.transaction_commitment
      }
    in
    let update_local_excess = Bool.(is_start' ||| is_last_party) in
    let update_global_state =
      ref Bool.(update_local_excess &&& local_state.success)
    in
    let global_excess_update_failed = ref Bool.true_ in
    let global_state, local_state =
      ( h.perform
          (Modify_global_excess
             ( global_state
             , fun amt ->
                 let res, `Overflow overflow =
                   Amount.Signed.add_flagged amt
                     (Amount.Signed.of_unsigned local_state.excess)
                 in
                 (global_excess_update_failed :=
                    Bool.(!update_global_state &&& overflow)) ;
                 (update_global_state :=
                    Bool.(!update_global_state &&& not overflow)) ;
                 Amount.Signed.if_ !update_global_state ~then_:res ~else_:amt ))
      , { local_state with
          excess =
            Amount.if_ update_local_excess ~then_:Amount.zero
              ~else_:local_state.excess
        } )
    in
    Bool.(assert_ (not (is_start' &&& !global_excess_update_failed))) ;
    let local_state =
      { local_state with
        success =
          Bool.(local_state.success &&& not !global_excess_update_failed)
      }
    in
    let global_state =
      h.perform
        (Modify_global_ledger
           { global_state
           ; ledger = local_state.ledger
           ; should_update = !update_global_state
           })
    in
    let local_state =
      (* Make sure to reset the local_state at the end of a transaction.
         The following fields are already reset
         - parties
         - transaction_commitment
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
