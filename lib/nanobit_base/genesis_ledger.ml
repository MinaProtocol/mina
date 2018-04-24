open Core_kernel

(* Genesis ledger has a single rich person *)
let ledger =
  let ledger = Ledger.create () in
  let rich_sk =
    "IgAAAAAAAAABIJLfK6/afuZTpDqzVSI/eMo7h/HuH/CcZozCtSEgsoLc"
        |> B64.decode
        |> Bigstring.of_string
        |> Private_key.of_bigstring
        |> Or_error.ok_exn
  in
  let rich_pk = Public_key.of_private_key rich_sk in
  let compressed_rich_pk =
    Public_key.compress rich_pk
  in
  Ledger.update
    ledger
    compressed_rich_pk
    { Account.public_key = compressed_rich_pk
    ; balance = Currency.Balance.of_int 100
    };

  ledger

