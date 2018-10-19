open Core_kernel
open Import

let high_balance_pk, high_balance_sk = Sample_keypairs.keypairs.(0)

let low_balance_pk, low_balance_sk = Sample_keypairs.keypairs.(1)

let extra_accounts =
  let offset = 2 in
  let n = 16 in
  List.init n ~f:(fun i -> Sample_keypairs.keypairs.(offset + i))

let pks = fst @@ List.unzip extra_accounts

let init_balance = 1000

let initial_high_balance = Currency.Balance.of_int 10_000_000

let initial_low_balance = Currency.Balance.of_int 100

let total_currency =
  let open Currency.Amount in
  let of_balance = Fn.compose of_int Currency.Balance.to_int in
  let add_exn x y =
    Option.value_exn
      ~message:"overflow while calculating genesis ledger total currency"
      (add x y)
  in
  List.fold_left pks ~init:zero ~f:(fun amount _ ->
      add_exn amount (of_int init_balance) )
  |> add_exn (of_balance initial_high_balance)
  |> add_exn (of_balance initial_low_balance)

let ledger =
  let ledger = Ledger.create () in
  let create_account pk account =
    Ledger.create_new_account_exn ledger pk account
  in
  create_account low_balance_pk
    { Account.public_key= low_balance_pk
    ; balance= initial_low_balance
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  List.fold pks ~init:() ~f:(fun _ pk ->
      create_account pk
        { Account.public_key= pk
        ; balance= Currency.Balance.of_int init_balance
        ; receipt_chain_hash= Receipt.Chain_hash.empty
        ; nonce= Account.Nonce.zero } ) ;
  create_account high_balance_pk
    { Account.public_key= high_balance_pk
    ; balance= initial_high_balance
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
  ledger
