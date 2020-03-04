(* transaction_union_payload.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Currency

[%%else]

module Currency = Currency_nonconsensus.Currency
open Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Tag = Transaction_union_tag

module Body = struct
  type ('tag, 'account_id, 'amount, 'bool) t_ =
    {tag: 'tag; account: 'account_id; amount: 'amount; whitelist: 'bool}
  [@@deriving sexp]

  type t = (Tag.t, Account_id.t, Currency.Amount.t, bool) t_ [@@deriving sexp]

  let of_user_command_payload_body = function
    | User_command_payload.Body.Payment {receiver; amount} ->
        {tag= Tag.Payment; account= receiver; amount; whitelist= false}
    | Stake_delegation (Set_delegate {new_delegate}) ->
        { tag= Tag.Stake_delegation
        ; account= Account_id.create new_delegate Token_id.default
        ; amount= Currency.Amount.zero
        ; whitelist= false }
    | Mint {receiver; amount} ->
        {tag= Tag.Mint; account= receiver; amount; whitelist= false}
    | Mint_new {receiver_pk; amount; approved_accounts_only} ->
        { tag= Tag.Mint
        ; account= Account_id.create receiver_pk Token_id.default
        ; amount
        ; whitelist= approved_accounts_only }
    | Enable_account account ->
        {tag= Tag.Mint; account; amount= Currency.Amount.zero; whitelist= true}
    | Disable_account account ->
        {tag= Tag.Mint; account; amount= Currency.Amount.zero; whitelist= false}

  let gen ~fee =
    let open Quickcheck.Generator.Let_syntax in
    let%bind tag = Tag.gen in
    let%bind account = Account_id.gen in
    let%map amount, whitelist =
      let%bind min, max, whitelist =
        let max_amount_without_overflow =
          Amount.(sub max_int (of_fee fee))
          |> Option.value_exn ?here:None ?message:None ?error:None
        in
        match tag with
        | Payment ->
            return (Amount.zero, max_amount_without_overflow, true)
        | Stake_delegation ->
            return (Amount.zero, max_amount_without_overflow, true)
        | Fee_transfer ->
            return (Amount.zero, max_amount_without_overflow, true)
        | Coinbase ->
            (* In this case,
             amount - fee should be defined. In other words,
             amount >= fee *)
            return (Amount.of_fee fee, Amount.max_int, true)
        | Mint ->
            let%map whitelist = Bool.quickcheck_generator in
            (Amount.zero, max_amount_without_overflow, whitelist)
      in
      let%map amount = Amount.gen_incl min max in
      (amount, whitelist)
    in
    {tag; account; amount; whitelist}

  [%%ifdef
  consensus_mechanism]

  type var =
    (Tag.Unpacked.var, Account_id.var, Currency.Amount.var, Boolean.var) t_

  let to_hlist {tag; account; amount; whitelist} =
    H_list.[tag; account; amount; whitelist]

  let spec =
    Data_spec.
      [Tag.unpacked_typ; Account_id.typ; Currency.Amount.typ; Boolean.typ]

  let typ =
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~value_to_hlist:to_hlist
      ~var_of_hlist:(fun H_list.[tag; account; amount; whitelist] ->
        {tag; account; amount; whitelist} )
      ~value_of_hlist:(fun H_list.[tag; account; amount; whitelist] ->
        {tag; account; amount; whitelist} )

  module Checked = struct
    let constant ({tag; account; amount; whitelist} : t) : var =
      { tag= Tag.unpacked_of_t tag
      ; account= Account_id.var_of_t account
      ; amount= Currency.Amount.var_of_t amount
      ; whitelist= Boolean.var_of_value whitelist }

    let to_input {tag; account; amount; whitelist} =
      let open Random_oracle.Input in
      let%map tag = Tag.Unpacked.Checked.to_input tag in
      append tag
      @@ append (Account_id.Checked.to_input account)
      @@ append
           (bitstring (Currency.Amount.var_to_bits amount :> Boolean.var list))
           (bitstring [whitelist])
  end

  [%%endif]

  let to_input {tag; account; amount; whitelist} =
    let open Random_oracle.Input in
    append (Tag.to_input tag)
    @@ append (Account_id.to_input account)
    @@ append
         (bitstring (Currency.Amount.to_bits amount))
         (bitstring [whitelist])
end

type t = (User_command_payload.Common.t, Body.t) User_command_payload.Poly.t
[@@deriving sexp]

type payload = t [@@deriving sexp]

let of_user_command_payload ({common; body} : User_command_payload.t) : t =
  {common; body= Body.of_user_command_payload_body body}

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind common = User_command_payload.Common.gen in
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
    let%map common = User_command_payload.Common.Checked.to_input common
    and body = Body.Checked.to_input body in
    Random_oracle.Input.append common body

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
  | Mint ->
      Amount.Signed.of_unsigned (Amount.of_fee fee)

let supply_increase (payload : payload) =
  let tag = payload.body.tag in
  match tag with
  | Coinbase ->
      payload.body.amount
  | Payment | Stake_delegation | Fee_transfer | Mint ->
      Amount.zero
