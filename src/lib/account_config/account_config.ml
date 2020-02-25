open Core_kernel

type account_data =
  { pk: Signature_lib.Public_key.Compressed.t
  ; sk: Signature_lib.Private_key.t option
  ; balance: Currency.Balance.t
  ; delegate: Signature_lib.Public_key.Compressed.t option }
[@@deriving yojson]

type t = account_data list [@@deriving yojson]

module Fake_accounts = struct
  let gen =
    let open Quickcheck.Let_syntax in
    let%bind balance = Quickcheck.Generator.of_list (List.range 10 500) in
    let%map pk = Signature_lib.Public_key.Compressed.gen in
    {pk; sk= None; balance= Currency.Balance.of_int balance; delegate= None}

  let generate n =
    let open Quickcheck in
    random_value ~seed:(`Deterministic "fake accounts for genesis ledger")
      (Generator.list_with_length n gen)
end
