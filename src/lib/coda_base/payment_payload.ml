(* payment_payload.ml *)

open Core_kernel
open Import

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { source_pk: Public_key.Compressed.Stable.V1.t
      ; receiver_pk: Public_key.Compressed.Stable.V1.t
      ; token_id: Token_id.Stable.V1.t
      ; amount: Amount.Stable.V1.t
      ; do_not_pay_creation_fee: bool }
    [@@deriving eq, sexp, hash, yojson, compare]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  { source_pk: Public_key.Compressed.t
  ; receiver_pk: Public_key.Compressed.t
  ; token_id: Token_id.t
  ; amount: Amount.t
  ; do_not_pay_creation_fee: bool }
[@@deriving eq, sexp, hash, yojson, compare]

let dummy =
  { source_pk= Public_key.Compressed.empty
  ; receiver_pk= Public_key.Compressed.empty
  ; token_id= Token_id.invalid
  ; amount= Amount.zero
  ; do_not_pay_creation_fee= false }

let token {token_id; _} = token_id

let gen_aux ?source_pk ~token_id ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%bind source_pk =
    match source_pk with
    | Some source_pk ->
        return source_pk
    | None ->
        Public_key.Compressed.gen
  in
  let%bind receiver_pk = Public_key.Compressed.gen in
  let%map amount = Amount.gen_incl Amount.zero max_amount in
  {source_pk; receiver_pk; token_id; amount; do_not_pay_creation_fee= false}

let gen ?source_pk ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%bind token_id = Token_id.gen in
  gen_aux ?source_pk ~token_id ~max_amount

let gen_default_token ?source_pk ~max_amount =
  gen_aux ?source_pk ~token_id:Token_id.default ~max_amount

let gen_non_default_token ?source_pk ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%bind token_id = Token_id.gen_non_default in
  gen_aux ?source_pk ~token_id ~max_amount
