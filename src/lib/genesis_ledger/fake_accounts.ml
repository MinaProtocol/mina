(* fake_accounts.ml -- generate fake accounts for testnet *)

open Core_kernel
open Signature_lib

let make_account pk balance =
  Intf.Public_accounts.{pk; balance; delegate= None; timing= None}

let balance_gen = Quickcheck.Generator.of_list (List.range 10 500)

let gen =
  let open Quickcheck.Let_syntax in
  let%bind balance = balance_gen in
  let%map pk = Public_key.Compressed.gen in
  make_account pk balance
