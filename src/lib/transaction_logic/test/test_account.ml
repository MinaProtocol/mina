open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Signature_lib

type t =
  { pk : Public_key.Compressed.t; nonce : Account_nonce.t; balance : Balance.t }
[@@deriving equal]

let make ?nonce ?(balance = Balance.zero) pk =
  { pk = Public_key.Compressed.of_base58_check_exn pk
  ; balance
  ; nonce =
      Option.value_map ~f:Account_nonce.of_int ~default:Account_nonce.zero nonce
  }

let non_empty { balance; _ } = Balance.(balance > zero)

let account_id { pk; _ } = Account_id.create pk Token_id.default

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%bind balance = Balance.gen in
  let%map nonce = Account_nonce.gen in
  { pk; nonce; balance }
