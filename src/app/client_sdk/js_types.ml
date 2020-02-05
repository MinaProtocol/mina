(* js_types.ml -- types for import, export from Javascript *)

open Js_of_ocaml
open Snark_params_nonconsensus
open Coda_base_nonconsensus
module Currency = Currency_nonconsensus.Currency
module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Global_slot = Coda_numbers_nonconsensus.Global_slot
module Memo = User_command_memo

type string_js = Js.js_string Js.t

type payload_common_js =
  < fee: string_js Js.prop
  ; nonce: string_js Js.prop
  ; validUntil: string_js Js.prop
  ; memo: string_js Js.prop >
  Js.t

type payment_payload_js =
  < receiver: string_js Js.prop ; amount: string_js Js.prop > Js.t

type payment_js =
  < common: payload_common_js Js.prop
  ; paymentPayload: payment_payload_js Js.prop >
  Js.t

type stake_delegation_js =
  < common: payload_common_js Js.prop ; new_delegate: string_js Js.prop > Js.t

let get_payload_common (payload_common_js : payload_common_js) =
  let fee_js = payload_common_js##.fee in
  let fee = Js.to_string fee_js |> Currency.Fee.of_string in
  let nonce_js = payload_common_js##.nonce in
  let nonce = Js.to_string nonce_js |> Coda_numbers.Account_nonce.of_string in
  let valid_until_js = payload_common_js##.validUntil in
  let valid_until = Js.to_string valid_until_js |> Global_slot.of_string in
  let memo_js = payload_common_js##.memo in
  let memo = Js.to_string memo_js |> Memo.create_from_string_exn in
  User_command_payload.Common.Poly.{fee; nonce; valid_until; memo}

type signature_js =
  < field: string_js Js.readonly_prop ; scalar: string_js Js.readonly_prop >
  Js.t

let signature_to_js_object ((field, scalar) : Signature.t) =
  object%js
    val field = Field.to_string field |> Js.string

    val scalar = Inner_curve.Scalar.to_string scalar |> Js.string
  end

type signed_payment =
  < payment: payment_js Js.readonly_prop
  ; sender: string_js Js.readonly_prop
  ; signature: signature_js Js.readonly_prop >

type signed_stake_delegation =
  < stakeDelegation: stake_delegation_js Js.readonly_prop
  ; sender: string_js Js.readonly_prop
  ; signature: signature_js Js.readonly_prop >
