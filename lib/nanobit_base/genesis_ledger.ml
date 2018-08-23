open Core_kernel

let rich_sk = Private_key.of_base64_exn "JgOTdFn9Dnvlc52Mh7AmUXSokCyFvGV4qrd98TRWKyBsnRGVsIFC"

let poor_sk = Private_key.of_base64_exn "JgOg9hn2KucsCNf+tu+TCjgXd1yjUYQpus5e3K5M/XSrAlBJkfh/"

let accounts = 8

let sincere_pairs = List.init accounts ~f:(fun _ -> Signature_keypair.create ())

let sincere_pks =
  List.map sincere_pairs ~f:(fun pair -> Public_key.compress pair.public_key)

let init_balance = 1000

let poor_pk = Public_key.of_private_key poor_sk |> Public_key.compress

let rich_pk = Public_key.of_private_key rich_sk |> Public_key.compress

let initial_rich_balance = Currency.Balance.of_int 10_000

let initial_poor_balance = Currency.Balance.of_int 100

let ledger =
  let ledger = Ledger.create () in
  Ledger.set ledger rich_pk
    { Account.public_key= rich_pk
    ; balance= initial_rich_balance
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  Ledger.set ledger poor_pk
    { Account.public_key= poor_pk
    ; balance= initial_poor_balance
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  List.fold sincere_pairs ~init:() ~f:(fun _ pair ->
      Ledger.set ledger
        (Public_key.compress pair.public_key)
        { Account.public_key= Public_key.compress pair.public_key
        ; balance= Currency.Balance.of_int 1000
        ; receipt_chain_hash= Receipt.Chain_hash.empty
        ; nonce= Account.Nonce.zero } ) ;
  ledger
