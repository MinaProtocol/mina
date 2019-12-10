open Core
open Signature_lib

type account_data =
  { pk: Public_key.Compressed.Stable.V1.t
  ; sk: Private_key.Stable.V1.t option
  ; balance: Currency.Balance.Stable.V1.t
  ; delegate: Public_key.Compressed.Stable.V1.t option }
[@@deriving yojson, bin_io]

type t = account_data list [@@deriving yojson, bin_io]

(*TODO: replace this with actual ledger configs*)
let sample_account_data1 : account_data =
  let keys = Signature_lib.Keypair.create () in
  let balance = Currency.Balance.of_int 1000 in
  let delegate = None in
  { pk= Public_key.compress keys.public_key
  ; sk= Some keys.private_key
  ; balance
  ; delegate }

let sample_account_data2 : account_data =
  let keys = Signature_lib.Keypair.create () in
  let balance = Currency.Balance.of_int 1000 in
  let pk = Public_key.compress keys.public_key in
  let delegate = Some pk in
  {pk; sk= Some keys.private_key; balance; delegate}

let sample_account_data3 : account_data =
  let keys = Signature_lib.Keypair.create () in
  let balance = Currency.Balance.of_int 1000 in
  let delegate = None in
  {pk= Public_key.compress keys.public_key; sk= None; balance; delegate}

let sample_list2 =
  [sample_account_data1; sample_account_data2; sample_account_data3]

let sample_list : t =
  List.map Test_genesis_ledger.accounts ~f:(fun (sk, acc) ->
      { pk= acc.public_key
      ; sk
      ; balance= acc.balance
      ; delegate= Some acc.delegate } )
