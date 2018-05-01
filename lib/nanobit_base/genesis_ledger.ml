open Core_kernel

let rich_sk =
  "IgAAAAAAAAABIJLfK6/afuZTpDqzVSI/eMo7h/HuH/CcZozCtSEgsoLc"
      |> B64.decode
      |> Bigstring.of_string
      |> Private_key.of_bigstring
      |> Or_error.ok_exn

let rich_pk = Public_key.(compress (of_private_key rich_sk))

(* Genesis ledger has a single rich person *)
let ledger =
  let ledger = Ledger.create () in
  Ledger.set
    ledger
    rich_pk
    { Account.public_key = rich_pk
    ; balance = Currency.Balance.of_int 100
    };
  ledger

