open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Signature_lib

type t =
  { pk : Public_key.Compressed.t
  ; nonce : Account_nonce.t
  ; balance : Balance.t
  ; zkapp : Zkapp_account.t option
  }
[@@deriving equal]

let make ?zkapp ?nonce ?(balance = Balance.zero) pk =
  { pk = Public_key.Compressed.of_base58_check_exn pk
  ; balance
  ; nonce =
      Option.value_map ~f:Account_nonce.of_int ~default:Account_nonce.zero nonce
  ; zkapp
  }

let non_empty { balance; _ } = Balance.(balance > zero)

let account_id { pk; _ } = Account_id.create pk Token_id.default

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%bind balance = Balance.gen in
  let%map nonce = Account_nonce.gen in
  { pk; nonce; balance; zkapp = None }

let gen_constrained_balance ?(min = Balance.zero) ?(max = Balance.max_int) () =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%bind balance = Balance.gen_incl min max in
  let%map nonce = Account_nonce.gen in
  { pk; balance; nonce; zkapp = None }

let gen_with_zkapp =
  let open Quickcheck.Generator.Let_syntax in
  let%map account = gen and zkapp = Zkapp_account.gen in
  { account with zkapp = Some zkapp }

let gen_empty =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%map nonce = Account_nonce.gen in
  { pk; nonce; balance = Balance.zero; zkapp = None }
