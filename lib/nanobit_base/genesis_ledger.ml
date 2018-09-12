open Core_kernel
open Import

let pk = Public_key.Compressed.of_base64_exn

let sk = Private_key.of_base64_exn

let high_balance_pk, high_balance_sk =
  ( pk "JgN/txgzOFPrOy8khSJSdPyFHdT+t05dgljjcaRvjXSC6ZFfcfkXAA"
  , sk "JgGg7PfX+SuEc8siVxn+OVeXBXcN3p0Wed0plH+tRn4+RduAlfUY" )

let low_balance_pk, low_balance_sk =
  ( pk "JgMuF0Dkx1tw6eAX2om4kJ+4Ch4PsBmtaaeX9o0y26fsnUBLrUlPAA"
  , sk "JgERfGHovlhcwIfMQltKFskwxODQCiI8pOhbJNLCItz38ljGMnPK" )

let extra_accounts =
  [ ( pk "JgLY2GjlFLGHNbrbu/32nGlO39ixo1/NzMH6/L1GuP+BHJulXVDEAA"
    , sk "JgMnYAqUS1X1qOwW6AwuOh8mIiWmo0bLTbDqW7ouhBHCq0VqaGs3" )
  ; ( pk "JgHfMr6v59H2q19OecwH9UaFrGqXdnziPqsX7ULF4DhdL2/gVYeNAA"
    , sk "JgHINxmgDL8GFdXyikq+eROjlsmyVINqFChuWzUeXMoRCD5pcdq6" )
  ; ( pk "JgIOKmls1aOl3+PznWZUNEsJ3zgGRGt+nS4A1oi4l03hy/DvlzZBAQ"
    , sk "JgF283vHMDkdLytZlRD1RY+3CFAr2AtpKHpnbOIcbfFQrTZaRkC9" )
  ; ( pk "JgO8ti/8l0mg1Uwk4F56JqpkozVmkIrnwcJj5lYTJldUu+N4Jdz+AQ"
    , sk "JgIzb5ddd7RlfcokVW9hw/IQbEReGnj+NmpD1pw8w8RNwTP1FzRF" )
  ; ( pk "JgIgzSmc6IxkeAaD8lGhZ1bkeXLIM7NUSbpP5FcUnKeqc5mL1pSyAA"
    , sk "JgNvjVrgqpPqgCeReVn5R1EMUadiZVEkE0fDEDEXH8J+niGq9i1v" )
  ; ( pk "JgJaS0kJRzpqJBg0a+cRF3hvDCE9fxK9sq7Lj7lNWO5SDjJaFQKWAQ"
    , sk "JgOp9/95QdH3hS2U/j3Ddx5mskHQ93UBf/YzoQHUoq1iGplMZezg" )
  ; ( pk "JgKoLBcjSkt+DssCqYz5/+ayWHyC5dJZL4VCg7WVaMHhHFBva5vSAA"
    , sk "JgMsQrwAH+RyLOR1esRb4XGgj3lLDChTGB9YUqPkJVq9TWMTzupK" )
  ; ( pk "JgMwgDyBIdFgALh8vXRIPMFmlIQTt3ZPgwnIZAOEQZmq45LmtU3AAQ"
    , sk "JgBM8rWambKPszX61qbf3Eb+QAGpLkqheflPqiiXKsKEVCu0faYc" )
  ; ( pk "JgBw5GRX/8MZXO6Ff3PizxSfzziAYjvs9QQOnP3sJqQhNQoJUS/+AA"
    , sk "JgAiZueO1mYN/8zUIIF1aohOwL2ZKEy5ASAuFvk0umuu8Noc2BIL" )
  ; ( pk "JgCaJziWG8VV7DdDQRlvcTN2sqJfsCXLlNn5ZnsTGu0Gz6ZAJGxIAA"
    , sk "JgOmXbtaAJJJFSATZkfONlXxkY4SCOWfK981CN1RMukrk7h8JvaP" )
  ; ( pk "JgG1CnPr+XNMpqz/QaeTtusDDn/JfpFK16tyMl0/AvlaPqaOxacYAA"
    , sk "JgDDyEej3siVxk0ql8Xuetmy53p28UnSa3ICDCPeDjxR/mPoSztp" )
  ; ( pk "JgHD27kPFutx01zY2+MetiPIRKw7iYIIvKWJahJ/GWTFBNbkIfZfAA"
    , sk "JgI3S4++04bM/tul3MWlt8RqGIKGFcwkMb6sVJ7wQnNA0LdKErP2" )
  ; ( pk "JgJkntFhEpBWcsGnKIdyzhTdyXiFvrru9+U+iSFQCpJoMaF9YCReAA"
    , sk "JgJ6mS/GkgD1GGQbx1+G7/y2NzWUYk3FWR7QoFKNiPujl1uG/vkv" )
  ; ( pk "JgE5hzTB/bgp8Dj4szxkd7l41epgG6/LDf9oTr+JHIkHAbVt07kNAA"
    , sk "JgNP4DpNRoc6kaipoXtLWiyGfZ1l6R9BztBL1shJcc/CEzcf9Pag" )
  ; ( pk "JgNCzMj7zA30XxNkja+EGYaplp6b+/Y2C7segUpHDaHhewRCKS6vAQ"
    , sk "JgEtzt0FSquiXmxHyvwoDFxfDjpMPDlV72QekDlHGT4KjbMOS0E+" )
  ; ( pk "JgIIB+xP5EBjykhIteN2xbCgGK7BxKnaOqDiMGJROrr0nMj+kZstAQ"
    , sk "JgOeo/ijaEqR3ZoNgDKj3gU+ZnrbR+yo/+cNW68SjOQ6Z7UBzKHa" ) ]

let pks = fst @@ List.unzip extra_accounts

let init_balance = 1000

let initial_high_balance = Currency.Balance.of_int 10_000

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
  create_account high_balance_pk
    { Account.public_key= high_balance_pk
    ; balance= initial_high_balance
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; nonce= Account.Nonce.zero } ;
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
  ledger
