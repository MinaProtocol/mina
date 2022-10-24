(* transaction_union_payload.ml *)

[%%import "/src/config.mlh"]

open Core_kernel
open Currency

[%%ifdef consensus_mechanism]

open Snark_params.Step

[%%endif]

open Signature_lib
module Tag = Transaction_union_tag

module Body = struct
  type ('tag, 'public_key, 'token_id, 'amount, 'bool) t_ =
    { tag : 'tag
    ; source_pk : 'public_key
    ; receiver_pk : 'public_key
    ; token_id : 'token_id
    ; amount : 'amount
    ; token_locked : 'bool
    }
  [@@deriving sexp, hlist]

  type t =
    (Tag.t, Public_key.Compressed.t, Token_id.t, Currency.Amount.t, bool) t_
  [@@deriving sexp]

  let of_user_command_payload_body = function
    | Signed_command_payload.Body.Payment { source_pk; receiver_pk; amount } ->
        { tag = Tag.Payment
        ; source_pk
        ; receiver_pk
        ; token_id = Token_id.default
        ; amount
        ; token_locked = false
        }
    | Stake_delegation (Set_delegate { delegator; new_delegate }) ->
        { tag = Tag.Stake_delegation
        ; source_pk = delegator
        ; receiver_pk = new_delegate
        ; token_id = Token_id.default
        ; amount = Currency.Amount.zero
        ; token_locked = false
        }

  let gen ~fee =
    let open Quickcheck.Generator.Let_syntax in
    let%bind tag = Tag.gen in
    let%map amount =
      let min, max =
        let max_amount_without_overflow =
          Amount.(sub max_int (of_fee fee))
          |> Option.value_exn ?here:None ?message:None ?error:None
        in
        match tag with
        | Payment ->
            (Amount.zero, max_amount_without_overflow)
        | Stake_delegation ->
            (Amount.zero, Amount.zero)
        | Create_account ->
            (Amount.zero, Amount.zero)
        | Fee_transfer ->
            (Amount.zero, max_amount_without_overflow)
        | Coinbase ->
            (* In this case,
               amount - fee should be defined. In other words,
               amount >= fee *)
            (Amount.of_fee fee, Amount.max_int)
        | Mint_tokens ->
            (Amount.zero, Amount.max_int)
      in
      Amount.gen_incl min max
    and token_locked =
      match tag with
      | Payment ->
          return false
      | Stake_delegation ->
          return false
      | Create_account ->
          Quickcheck.Generator.bool
      | Fee_transfer ->
          return false
      | Coinbase ->
          return false
      | Mint_tokens ->
          return false
    and source_pk = Public_key.Compressed.gen
    and receiver_pk = Public_key.Compressed.gen
    and token_id =
      match tag with
      | Payment ->
          Token_id.gen
      | Stake_delegation ->
          return Token_id.default
      | Create_account ->
          Token_id.gen
      | Mint_tokens ->
          Token_id.gen
      | Fee_transfer ->
          return Token_id.default
      | Coinbase ->
          return Token_id.default
    in
    { tag; source_pk; receiver_pk; token_id; amount; token_locked }

  [%%ifdef consensus_mechanism]

  type var =
    ( Tag.Unpacked.var
    , Public_key.Compressed.var
    , Token_id.Checked.t
    , Currency.Amount.var
    , Boolean.var )
    t_

  let typ =
    Typ.of_hlistable
      [ Tag.unpacked_typ
      ; Public_key.Compressed.typ
      ; Public_key.Compressed.typ
      ; Token_id.typ
      ; Currency.Amount.typ
      ; Boolean.typ
      ]
      ~var_to_hlist:t__to_hlist ~value_to_hlist:t__to_hlist
      ~var_of_hlist:t__of_hlist ~value_of_hlist:t__of_hlist

  module Checked = struct
    let constant
        ({ tag; source_pk; receiver_pk; token_id; amount; token_locked } : t) :
        var =
      { tag = Tag.unpacked_of_t tag
      ; source_pk = Public_key.Compressed.var_of_t source_pk
      ; receiver_pk = Public_key.Compressed.var_of_t receiver_pk
      ; token_id = Token_id.Checked.constant token_id
      ; amount = Currency.Amount.var_of_t amount
      ; token_locked = Boolean.var_of_value token_locked
      }

    let to_input_legacy
        { tag; source_pk; receiver_pk; token_id; amount; token_locked } =
      let%map amount = Currency.Amount.var_to_input_legacy amount
      and () =
        make_checked (fun () ->
            Token_id.Checked.Assert.equal token_id
              (Token_id.Checked.constant Token_id.default) )
      in
      let token_id = Signed_command_payload.Legacy_token_id.default_checked in
      Array.reduce_exn ~f:Random_oracle.Input.Legacy.append
        [| Tag.Unpacked.to_input_legacy tag
         ; Public_key.Compressed.Checked.to_input_legacy source_pk
         ; Public_key.Compressed.Checked.to_input_legacy receiver_pk
         ; token_id
         ; amount
         ; Random_oracle.Input.Legacy.bitstring [ token_locked ]
        |]
  end

  [%%endif]

  let to_input_legacy
      { tag; source_pk; receiver_pk; token_id; amount; token_locked } =
    assert (Token_id.equal token_id Token_id.default) ;
    Array.reduce_exn ~f:Random_oracle.Input.Legacy.append
      [| Tag.to_input_legacy tag
       ; Public_key.Compressed.to_input_legacy source_pk
       ; Public_key.Compressed.to_input_legacy receiver_pk
       ; Signed_command_payload.Legacy_token_id.default
       ; Currency.Amount.to_input_legacy amount
       ; Random_oracle.Input.Legacy.bitstring [ token_locked ]
      |]
end

module Payload_common = struct
  module Poly = struct
    type ('fee, 'public_key, 'token_id, 'nonce, 'global_slot, 'memo) t =
      { fee : 'fee
      ; fee_token : 'token_id
      ; fee_payer_pk : 'public_key
      ; nonce : 'nonce
      ; valid_until : 'global_slot
      ; memo : 'memo
      }
    [@@deriving sexp, hlist]
  end

  let to_signed_command_payload_common
      { Poly.fee; fee_payer_pk; nonce; valid_until; memo; fee_token = _ } =
    { Signed_command_payload.Common.Poly.fee
    ; fee_payer_pk
    ; nonce
    ; valid_until
    ; memo
    }

  type t =
    ( Currency.Fee.t
    , Public_key.Compressed.t
    , Token_id.t
    , Mina_numbers.Account_nonce.t
    , Mina_numbers.Global_slot.t
    , Signed_command_memo.t )
    Poly.t
  [@@deriving sexp]

  [%%ifdef consensus_mechanism]

  module Checked = struct
    type value = t

    type t =
      ( Currency.Fee.Checked.t
      , Public_key.Compressed.var
      , Token_id.Checked.t
      , Mina_numbers.Account_nonce.Checked.t
      , Mina_numbers.Global_slot.Checked.t
      , Signed_command_memo.Checked.t )
      Poly.t

    let constant
        ({ fee; fee_payer_pk; nonce; valid_until; memo; fee_token } : value) : t
        =
      { fee = Currency.Fee.var_of_t fee
      ; fee_payer_pk = Public_key.Compressed.var_of_t fee_payer_pk
      ; fee_token = Token_id.Checked.constant fee_token
      ; nonce = Mina_numbers.Account_nonce.Checked.constant nonce
      ; memo = Signed_command_memo.Checked.constant memo
      ; valid_until = Mina_numbers.Global_slot.Checked.constant valid_until
      }
  end

  let typ : (Checked.t, t) Typ.t =
    let open Poly in
    Typ.of_hlistable
      [ Currency.Fee.typ
      ; Token_id.typ
      ; Public_key.Compressed.typ
      ; Mina_numbers.Account_nonce.typ
      ; Mina_numbers.Global_slot.typ
      ; Signed_command_memo.typ
      ]
      ~var_to_hlist:to_hlist ~value_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_of_hlist:of_hlist

  [%%endif]
end

type t = (Payload_common.t, Body.t) Signed_command_payload.Poly.t
[@@deriving sexp]

type payload = t [@@deriving sexp]

let of_user_command_payload
    ({ common = { memo; fee; fee_payer_pk; nonce; valid_until }; body } :
      Signed_command_payload.t ) : t =
  { common =
      { fee
      ; fee_token = Token_id.default
      ; fee_payer_pk
      ; nonce
      ; valid_until
      ; memo
      }
  ; body = Body.of_user_command_payload_body body
  }

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind common = Signed_command_payload.Common.gen in
  let%map body = Body.gen ~fee:common.fee in
  Signed_command_payload.Poly.{ common; body }

[%%ifdef consensus_mechanism]

type var = (Payload_common.Checked.t, Body.var) Signed_command_payload.Poly.t

type payload_var = var

let typ : (var, t) Typ.t =
  let to_hlist = Signed_command_payload.Poly.to_hlist in
  let of_hlist = Signed_command_payload.Poly.of_hlist in
  Typ.of_hlistable
    [ Payload_common.typ; Body.typ ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

let payload_typ = typ

module Checked = struct
  let to_input_legacy ({ common; body } : var) =
    let%map common =
      Signed_command_payload.Common.Checked.to_input_legacy
        (Payload_common.to_signed_command_payload_common common)
    and body = Body.Checked.to_input_legacy body in
    Random_oracle.Input.Legacy.append common body

  let constant ({ common; body } : t) : var =
    { common = Payload_common.Checked.constant common
    ; body = Body.Checked.constant body
    }
end

[%%endif]

let to_input_legacy ({ common; body } : t) =
  Random_oracle.Input.Legacy.append
    (Signed_command_payload.Common.to_input_legacy
       (Payload_common.to_signed_command_payload_common common) )
    (Body.to_input_legacy body)

let excess (payload : t) : Amount.Signed.t =
  let tag = payload.body.tag in
  let fee = payload.common.fee in
  let amount = payload.body.amount in
  match tag with
  | Payment | Stake_delegation | Create_account | Mint_tokens ->
      (* For all user commands, the fee excess is just the fee. *)
      Amount.Signed.of_unsigned (Amount.of_fee fee)
  | Fee_transfer ->
      Option.value_exn (Amount.add_fee amount fee)
      |> Amount.Signed.of_unsigned |> Amount.Signed.negate
  | Coinbase ->
      Amount.Signed.zero

let fee_excess ({ body = { tag; amount; _ }; common = { fee; _ } } : t) =
  match tag with
  | Payment | Stake_delegation | Create_account | Mint_tokens ->
      (* For all user commands, the fee excess is just the fee. *)
      Fee_excess.of_single (Token_id.default, Fee.Signed.of_unsigned fee)
  | Fee_transfer ->
      let excess =
        Option.value_exn (Amount.add_fee amount fee)
        |> Amount.to_fee |> Fee.Signed.of_unsigned |> Fee.Signed.negate
      in
      Fee_excess.of_single (Token_id.default, excess)
  | Coinbase ->
      Fee_excess.of_single (Token_id.default, Fee.Signed.zero)

let expected_supply_increase (payload : payload) =
  let tag = payload.body.tag in
  match tag with
  | Coinbase ->
      payload.body.amount
  | Payment | Stake_delegation | Create_account | Mint_tokens | Fee_transfer ->
      Amount.zero
