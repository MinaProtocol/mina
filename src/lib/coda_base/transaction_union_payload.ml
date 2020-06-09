(* transaction_union_payload.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Signature_lib
open Currency

[%%else]

open Signature_lib_nonconsensus
module Currency = Currency_nonconsensus.Currency
open Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Tag = Transaction_union_tag

module Body = struct
  type ('tag, 'public_key, 'token_id, 'amount) t_ =
    { tag: 'tag
    ; source_pk: 'public_key
    ; receiver_pk: 'public_key
    ; token_id: 'token_id
    ; amount: 'amount }
  [@@deriving sexp]

  type t = (Tag.t, Public_key.Compressed.t, Token_id.t, Currency.Amount.t) t_
  [@@deriving sexp]

  let of_user_command_payload_body = function
    | User_command_payload.Body.Payment
        {source_pk; receiver_pk; token_id; amount} ->
        {tag= Tag.Payment; source_pk; receiver_pk; token_id; amount}
    | Stake_delegation (Set_delegate {delegator; new_delegate}) ->
        { tag= Tag.Stake_delegation
        ; source_pk= delegator
        ; receiver_pk= new_delegate
        ; token_id= Token_id.default
        ; amount= Currency.Amount.zero }

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
            (Amount.zero, max_amount_without_overflow)
        | Fee_transfer ->
            (Amount.zero, max_amount_without_overflow)
        | Coinbase ->
            (* In this case,
             amount - fee should be defined. In other words,
             amount >= fee *)
            (Amount.of_fee fee, Amount.max_int)
      in
      Amount.gen_incl min max
    and source_pk = Public_key.Compressed.gen
    and receiver_pk = Public_key.Compressed.gen
    and token_id =
      match tag with Payment -> Token_id.gen | _ -> return Token_id.default
    in
    {tag; source_pk; receiver_pk; token_id; amount}

  [%%ifdef
  consensus_mechanism]

  type var =
    ( Tag.Unpacked.var
    , Public_key.Compressed.var
    , Token_id.var
    , Currency.Amount.var )
    t_

  let to_hlist {tag; source_pk; receiver_pk; token_id; amount} =
    H_list.[tag; source_pk; receiver_pk; token_id; amount]

  let spec =
    Data_spec.
      [ Tag.unpacked_typ
      ; Public_key.Compressed.typ
      ; Public_key.Compressed.typ
      ; Token_id.typ
      ; Currency.Amount.typ ]

  let typ =
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~value_to_hlist:to_hlist
      ~var_of_hlist:
        (fun H_list.[tag; source_pk; receiver_pk; token_id; amount] ->
        {tag; source_pk; receiver_pk; token_id; amount} )
      ~value_of_hlist:
        (fun H_list.[tag; source_pk; receiver_pk; token_id; amount] ->
        {tag; source_pk; receiver_pk; token_id; amount} )

  module Checked = struct
    let constant ({tag; source_pk; receiver_pk; token_id; amount} : t) : var =
      { tag= Tag.unpacked_of_t tag
      ; source_pk= Public_key.Compressed.var_of_t source_pk
      ; receiver_pk= Public_key.Compressed.var_of_t receiver_pk
      ; token_id= Token_id.var_of_t token_id
      ; amount= Currency.Amount.var_of_t amount }

    let to_input {tag; source_pk; receiver_pk; token_id; amount} =
      Array.reduce_exn ~f:Random_oracle.Input.append
        [| Tag.Unpacked.to_input tag
         ; Public_key.Compressed.Checked.to_input source_pk
         ; Public_key.Compressed.Checked.to_input receiver_pk
         ; Token_id.Checked.to_input token_id
         ; Currency.Amount.var_to_input amount |]
  end

  [%%endif]

  let to_input {tag; source_pk; receiver_pk; token_id; amount} =
    Array.reduce_exn ~f:Random_oracle.Input.append
      [| Tag.to_input tag
       ; Public_key.Compressed.to_input source_pk
       ; Public_key.Compressed.to_input receiver_pk
       ; Token_id.to_input token_id
       ; Currency.Amount.to_input amount |]
end

type t = (User_command_payload.Common.t, Body.t) User_command_payload.Poly.t
[@@deriving sexp]

type payload = t [@@deriving sexp]

let of_user_command_payload ({common; body} : User_command_payload.t) : t =
  {common; body= Body.of_user_command_payload_body body}

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind common =
    User_command_payload.Common.gen ~fee_token_id:Token_id.default ()
  in
  let%map body = Body.gen ~fee:common.fee in
  User_command_payload.Poly.{common; body}

[%%ifdef
consensus_mechanism]

type var =
  (User_command_payload.Common.var, Body.var) User_command_payload.Poly.t

type payload_var = var

let to_hlist ({common; body} : (_, _) User_command_payload.Poly.t) =
  H_list.[common; body]

let of_hlist : type c v.
    (unit, c -> v -> unit) H_list.t -> (c, v) User_command_payload.Poly.t =
 fun H_list.[common; body] -> {common; body}

let typ : (var, t) Typ.t =
  Typ.of_hlistable
    [User_command_payload.Common.typ; Body.typ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

let payload_typ = typ

module Checked = struct
  let to_input ({common; body} : var) =
    let%map common = User_command_payload.Common.Checked.to_input common in
    Random_oracle.Input.append common (Body.Checked.to_input body)

  let constant ({common; body} : t) : var =
    { common= User_command_payload.Common.Checked.constant common
    ; body= Body.Checked.constant body }
end

[%%endif]

let to_input ({common; body} : t) =
  Random_oracle.Input.append
    (User_command_payload.Common.to_input common)
    (Body.to_input body)

let excess (payload : t) : Amount.Signed.t =
  let tag = payload.body.tag in
  let fee = payload.common.fee in
  let amount = payload.body.amount in
  match tag with
  | Payment ->
      Amount.Signed.of_unsigned (Amount.of_fee fee)
  | Stake_delegation ->
      Amount.Signed.of_unsigned (Amount.of_fee fee)
  | Fee_transfer ->
      Option.value_exn (Amount.add_fee amount fee)
      |> Amount.Signed.of_unsigned |> Amount.Signed.negate
  | Coinbase ->
      Amount.Signed.zero

let fee_excess (payload : t) =
  match payload.body.tag with
  | Payment | Stake_delegation ->
      Fee_excess.of_single
        (payload.common.fee_token, Fee.Signed.of_unsigned payload.common.fee)
  | Fee_transfer ->
      Fee_excess.of_single
        ( payload.common.fee_token
        , Fee.Signed.of_unsigned payload.common.fee |> Fee.Signed.negate )
  | Coinbase ->
      Fee_excess.of_single (Token_id.default, Fee.Signed.zero)

let supply_increase (payload : payload) =
  let tag = payload.body.tag in
  match tag with
  | Coinbase ->
      payload.body.amount
  | Payment | Stake_delegation | Fee_transfer ->
      Amount.zero
