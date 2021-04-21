module type Bool_intf = sig
  type t

  val true_ : t

  val equal : t -> t -> t

  val not : t -> t

  val ( || ) : t -> t -> t

  val ( && ) : t -> t -> t

  val assert_ : t -> unit
end

module type Iffable = sig
  type bool

  type t

  val if_ : bool -> then_:t -> else_:t -> t
end

module type Amount_intf = sig
  include Iffable

  module Signed : sig
    type t
  end

  val zero : t

  val ( - ) : t -> t -> Signed.t

  val ( + ) : t -> t -> t

  val add_signed : t -> Signed.t -> t
end

module type Token_id_intf = sig
  include Iffable

  val equal : t -> t -> bool

  val default : t
end

module Local_state = struct
  type ('parties, 'token_id, 'excess, 'ledger, 'bool) t =
    { parties: 'parties
    ; all_parties: 'parties
    ; token_id: 'token_id
    ; excess: 'excess
    ; ledger: 'ledger
    ; success: 'bool
    ; will_succeed: 'bool }
  [@@deriving fields]
end

module type Parties_intf = sig
  include Iffable

  type party

  val empty : t

  val is_empty : t -> bool

  val pop : t -> party * t
end

module type Ledger_intf = sig
  include Iffable
end

module Eff = struct
  type (_, _) t =
    | Get_account :
        'party * 'ledger
        -> ( 'account * 'inclusion_proof
           , < party: 'party
             ; account: 'account
             ; inclusion_proof: 'inclusion_proof
             ; ledger: 'ledger
             ; .. > )
           t
    | Check_inclusion :
        'ledger * 'account * 'inclusion_proof
        -> ( unit
           , < ledger: 'ledger ; inclusion_proof: 'inclusion_proof ; .. > )
           t
    | Check_predicate :
        'party * 'account * 'global_state * 'protocol_state_predicate option
        -> ( 'bool
           , < bool: 'bool
             ; party: 'party
             ; account: 'account
             ; global_state: 'global_state
             ; protocol_state_predicate: 'protocol_state_predicate
             ; .. > )
           t
    | Set_account_if :
        'bool * 'ledger * 'account * 'inclusion_proof
        -> ( 'ledger
           , < bool: 'bool
             ; ledger: 'ledger
             ; inclusion_proof: 'inclusion_proof
             ; account: 'account
             ; .. > )
           t
    | Modify_global_excess :
        'global_state * ('amount -> 'amount)
        -> ( 'global_state
           , < global_state: 'global_state ; amount: 'amount ; .. > )
           t
    | Modify_global_ledger :
        'global_state * ('ledger -> 'ledger)
        -> ( 'global_state
           , < global_state: 'global_state ; ledger: 'ledger ; .. > )
           t
    | Party_token_id :
        'party
        -> ('token_id, < party: 'party ; token_id: 'token_id ; .. >) t
    | Check_auth_and_update_account :
        { is_start: 'bool
        ; protocol_state_predicate: 'protocol_state_predicate option
        ; party: 'party
        ; account: 'account
        ; all_parties: 'all_parties
        ; inclusion_proof: 'ip }
        -> ( 'account * 'bool
           , < inclusion_proof: 'ip
             ; bool: 'bool
             ; party: 'party
             ; all_parties: 'all_parties
             ; account: 'account
             ; protocol_state_predicate: 'protocol_state_predicate
             ; .. > )
           t
    | Balance :
        'account
        -> ('amount, < account: 'account ; amount: 'amount ; .. >) t
    | Finalize_local_state :
        'bool * 'local_state
        -> (unit, < local_state: 'local_state ; bool: 'bool ; .. >) t
end

type 'e handler = {perform: 'r. ('r, 'e) Eff.t -> 'r}

module type Inputs_intf = sig
  module Bool : Bool_intf

  module Ledger : Ledger_intf with type bool := Bool.t

  module Account : Iffable with type bool := Bool.t

  module Amount : Amount_intf with type bool := Bool.t

  module Token_id : Token_id_intf with type bool := Bool.t

  module Parties : Parties_intf with type bool := Bool.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  module Ps = Inputs.Parties

  let apply (type global_state)
      (* (step_or_start : [`Start of Inputs.Parties.t | `Step]) *)
      start_parties protocol_state_predicate
      (h :
        (< global_state: global_state
         ; all_parties: Ps.t
         ; amount: Amount.t
         ; bool: Bool.t
         ; .. >
         as
         'env)
        handler)
      ((global_state : global_state), (local_state : _ Local_state.t)) =
    let open Inputs in
    let is_start = Ps.is_empty local_state.parties in
    let (party, remaining), local_state =
      let to_pop =
        Ps.if_ is_start ~then_:start_parties ~else_:local_state.parties
      in
      let party, remaining = Ps.pop to_pop in
      let local_state =
        { local_state with
          all_parties=
            Ps.if_ is_start ~then_:remaining ~else_:local_state.parties
        ; token_id=
            Token_id.if_ is_start ~then_:Token_id.default
              ~else_:local_state.token_id }
      in
      ((party, remaining), local_state)
    in
    let local_state = {local_state with parties= remaining} in
    let a, inclusion_proof =
      (* Also checks the inclusion proof. *)
      h.perform (Get_account (party, local_state.ledger))
    in
    h.perform (Check_inclusion (local_state.ledger, a, inclusion_proof)) ;
    let predicate_satisfied : Bool.t =
      h.perform
        (Check_predicate (party, a, global_state, protocol_state_predicate))
    in
    let a', update_permitted =
      let parties_for_auth =
        Ps.if_ is_start ~then_:start_parties ~else_:local_state.all_parties
      in
      h.perform
        (Check_auth_and_update_account
           { is_start
           ; party
           ; account= a
           ; all_parties= parties_for_auth
           ; protocol_state_predicate
           ; inclusion_proof })
    in
    let party_succeeded = Bool.( && ) predicate_satisfied update_permitted in
    let local_state =
      { local_state with
        success= Bool.( && ) local_state.success party_succeeded }
    in
    let local_delta =
      Amount.(h.perform (Balance a) - h.perform (Balance a'))
    in
    let party_token = h.perform (Party_token_id party) in
    let fee_excess_change0, new_local_fee_excess =
      let curr_token : Token_id.t = local_state.token_id in
      let same_token = Token_id.equal curr_token party_token in
      let curr_is_default = Token_id.(equal default) curr_token in
      let should_merge = Bool.( && ) (Bool.not same_token) curr_is_default in
      let to_merge_amount =
        Amount.if_ should_merge ~then_:local_state.excess ~else_:Amount.zero
      in
      let new_local =
        let base =
          Amount.if_ same_token ~then_:local_state.excess ~else_:Amount.zero
        in
        Amount.add_signed base local_delta
      in
      (to_merge_amount, new_local)
    in
    let local_state = {local_state with excess= new_local_fee_excess} in
    let global_state =
      (* TODO: Maybe overflows should be possible and cause a transaction failure? *)
      h.perform
        (Modify_global_excess (global_state, Amount.( + ) fee_excess_change0))
    in
    (* If a's token ID differs from that in the local state, then
      the local state excess gets moved into the execution state's fee excess.

      If there are more parties to execute after this one, then the local delta gets
      accumulated in the local state (unless there is a token

      If there are no more parties to execute, then we do the same as if we switch tokens.
      The local state excess (plus the local delta) gets moved to the fee excess if it is default token.
    *)
    let new_ledger =
      let should_apply = Bool.( || ) is_start local_state.will_succeed in
      h.perform
        (Set_account_if (should_apply, local_state.ledger, a', inclusion_proof))
    in
    let local_state = {local_state with ledger= new_ledger} in
    let is_last_party = Ps.is_empty remaining in
    h.perform (Finalize_local_state (is_last_party, local_state)) ;
    (*
       In the SNARK, this will be
    Bool.(assert_
            (not is_last_party ||
            equal local_state.will_succeed local_state.success)) ;
       *)
    let global_state =
      let curr_is_default = Token_id.(equal default) local_state.token_id in
      let should_perform_second_excess_merge =
        Bool.( && ) curr_is_default is_last_party
      in
      h.perform
        (Modify_global_excess
           ( global_state
           , fun amt ->
               Amount.if_ should_perform_second_excess_merge
                 ~then_:Amount.(amt + local_state.excess)
                 ~else_:amt ))
    in
    let global_state =
      h.perform
        (Modify_global_ledger
           ( global_state
           , fun curr ->
               Inputs.Ledger.if_ is_last_party ~then_:local_state.ledger
                 ~else_:curr ))
    in
    (global_state, local_state)

  let step h state = apply Ps.empty None h state

  let start ~protocol_state parties h state =
    apply parties (Some protocol_state) h state
end
