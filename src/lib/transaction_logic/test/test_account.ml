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
  ; token_id : Token_id.t
  }
[@@deriving equal]

let make ?zkapp ?nonce ?(token_id = Token_id.default) ?(balance = Balance.zero)
    pk =
  { pk = Public_key.Compressed.of_base58_check_exn pk
  ; balance
  ; nonce =
      Option.value_map ~f:Account_nonce.of_int ~default:Account_nonce.zero nonce
  ; zkapp
  ; token_id
  }

let non_empty { balance; _ } = Balance.(balance > zero)

let account_id { pk; token_id; _ } = Account_id.create pk token_id

let set_token_id token_id account = { account with token_id }

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%bind balance = Balance.gen in
  let%map nonce = Account_nonce.gen in
  { pk; nonce; balance; zkapp = None; token_id = Token_id.default }

let gen_constrained_balance ?(min = Balance.zero) ?(max = Balance.max_int) () =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%bind balance = Balance.gen_incl min max in
  let%map nonce = Account_nonce.gen in
  { pk; balance; nonce; zkapp = None; token_id = Token_id.default }

let gen_with_zkapp =
  let open Quickcheck.Generator.Let_syntax in
  let%map account = gen and zkapp = Zkapp_account.gen in
  { account with zkapp = Some zkapp }

let gen_empty =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%map nonce = Account_nonce.gen in
  { pk
  ; nonce
  ; balance = Balance.zero
  ; zkapp = None
  ; token_id = Token_id.default
  }

let gen_custom_token =
  let open Quickcheck.Generator.Let_syntax in
  let%bind pk = Public_key.Compressed.gen in
  let%bind balance = Balance.gen in
  let%map nonce = Account_nonce.gen in
  let owner =
    { pk; nonce; balance; zkapp = None; token_id = Token_id.default }
  in
  let token_id = Account_id.derive_token_id ~owner:(account_id owner) in
  (owner, token_id)

let with_token_id ?(gen = gen) token_id =
  let open Quickcheck.Generator.Let_syntax in
  let%map account = gen in
  { account with token_id }
