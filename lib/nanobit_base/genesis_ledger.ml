open Core_kernel

let rich_sk =
  "IgAAAAAAAAABIJLfK6/afuZTpDqzVSI/eMo7h/HuH/CcZozCtSEgsoLc" |> B64.decode
  |> Bigstring.of_string |> Private_key.of_bigstring |> Or_error.ok_exn

let poor_sk =
  "KgAAAAAAAAABKEHfd5r8nKEMPSVcgvbWS6CdErbzB4eYaxpr9qJqtKy5JAAAAAAAAAA="
  |> B64.decode |> Bigstring.of_string |> Private_key.of_bigstring
  |> Or_error.ok_exn

let poor_pk = Public_key.of_private_key poor_sk |> Public_key.compress

let rich_pk = Public_key.of_private_key rich_sk |> Public_key.compress

let initial_rich_balance = Currency.Balance.of_int 10_000

let initial_poor_balance = Currency.Balance.of_int 100

(* Genesis ledger has a single rich person *)
let ledger =
  let ledger = Ledger.create () in
  Ledger.set ledger rich_pk
    { Account.public_key= rich_pk
    ; balance= initial_rich_balance
    ; receipt_chain_hash = Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  Ledger.set ledger poor_pk
    { Account.public_key= poor_pk
    ; balance= initial_poor_balance
    ; receipt_chain_hash = Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  ledger
