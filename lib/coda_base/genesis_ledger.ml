open Core_kernel
open Import

let pk = Public_key.Compressed.of_base64_exn

let sk = Private_key.of_base64_exn

let high_balance_pk, high_balance_sk =
  ( pk "KE63vdBqwbQ+p2XQ5QOrrPUkCfKtvPRg5jX2AfeC8C7cCNCJSmQBAAAB"
  , sk "KG4SU+0RbKTdsnrMHF8FW6sWwURj3d7uElsztcGvNH0shPVtKywAAAA=" )

let low_balance_pk, low_balance_sk =
  ( pk "KNQxdQ2zGPN+xbEinl9//vVvVxIvI/I6UCXiYCj3Bu66afuhDHkBAAAA"
  , sk "KLPXDSFPannP/XEG0mzkD8twYUObNRhzpS39pLdOuIU96ZqSRcMCAAA=" )

let extra_accounts =
  [ ( pk "KA4EVFZFimYTnjvb5+o7Pfh8qe7+/vf7oZC5S1kk3xXdXRZ+xBoBAAAA"
    , sk "KH9kL3O+vcLHvQTIli8z2xs9YoagMZM7oDjDitx+0/tps04bOhcCAAA=" )
  ; ( pk "KB71COB8c4Cz9m1MgQwdJ5f1wW/DZOSOdVr6qwA4Lw/ZNLmuoHQDAAAB"
    , sk "KG9w15C1oYIndb0bp4cFB0TqsIZ8QEwKfnxL0FCt54jPk4NmJswCAAA=" )
  ; ( pk "KL8imhaBJyJCKXhjaBf8xEhT8MdNKu7fd6W0akmuaPQo0nfiuXMAAAAA"
    , sk "KCijYT7z7Opl8VI16EyMPWG4ty6o4iWeWI7I+cdW7H1hj3HJ8JIBAAA=" )
  ; ( pk "KMGTh/pZ4Re7c81teCUupEh53+9fAwx4G+OzujBaQXNlG4fR9l4DAAAB"
    , sk "KDYNlJUdYS09kvoWpcstfu7B6cGKEf9uP9anSPej0eVj2jzB1mcDAAA=" )
  ; ( pk "KMdebPAAdlELbSX6zwVCQHYPVNKUY5nyLVNl3BdSbH+cbxU0ADQCAAAB"
    , sk "KNfa2my92ziufwlYs33or/4EY8v0DHLpgUaTCOBk7DjeEZRz0UUDAAA=" )
  ; ( pk "KO7wOEi08r68hg3+TKjYz0hAxpfBnwKwWDWELtGpggfHskEvtF4BAAAB"
    , sk "KNoKzYEPCUizc6EPGAxafj+jtwHz2qbgJPcy/+n1DpBwL8UryooBAAA=" )
  ; ( pk "KI8nqqAgq4mEGjrFebow36GOKM3d26db+sIZ1Up7T+paKoCgmTYDAAAB"
    , sk "KM2do4YVHCcJS0QjI1Iw2xyEHg2ETJtO0GIV7Sm2R7qa7UD9LiwAAAA=" )
  ; ( pk "KFIwno4wxlO/e0MjRdZROXnlrmh9AMYVad3kJrcPU4Fwe74qHPkAAAAB"
    , sk "KIMpQd2zHGzMm9kJUdRqTOuxZZWt5MJKHsgOzpnuo163s2UXItgBAAA=" )
  ; ( pk "KKueD3sKJ+S7EbJlo192GPKFSgNkCs/Xio7BpkVh8dVDvKSNyJQBAAAA"
    , sk "KLlOtOQ02TIP5eDWkoGwq0UkWJy1Pz29oNBsCmnOT2zTf3QoSQAAAAA=" )
  ; ( pk "KBNmX7yf+XL3X/NL8eb4phJNPkFqnKnjW1d8UIoQXKVmW9gUdf4BAAAA"
    , sk "KHiXtcpDPD5bv0UDn8scGO2XWmufONb2FJN1D1errmdOr/hGxB8DAAA=" )
  ; ( pk "KMJOuj+qTSWhW3Z3ovBOXjiinclBfBoy2LUJwLwj8QImm0kcDRoBAAAA"
    , sk "KGE/+fYdDGAJ7XzDENaRU8RUBiiGW3d7N9UP89lUGRDFgD8s6TUCAAA=" )
  ; ( pk "KOvma+7SVL0GM5vU0DTJ/EkwHeuTgfuEx6uAwMVPnAWB++XVBX0AAAAA"
    , sk "KDxMD1RMRTFeybSy2I/j/mXi3BbwMZK1T0/m9yg0qlmErjzTuXABAAA=" )
  ; ( pk "KMdpUe3I8lWqhUIdUbWzdV4ubU6vfQVpkVBVLY1W/6enBMrQdoEDAAAB"
    , sk "KKfW61uYc0U7CihhXnTEioJ5I1qqeS/C13702l6RVR46xvm7uPUCAAA=" )
  ; ( pk "KKy4+/iZ/s5m8PS3G4HG95bI5osiKY71BVKRgcnkh4dnS8H9luABAAAB"
    , sk "KMYeC2u+ugxQkBdE8HTHTvROlA1+oOIcYR3Rxi9qJwFtcLbqkusAAAA=" )
  ; ( pk "KEqReFvUxEAUxhNjyGaUS5iH0pS4/TBHkUpvdIl8ue3SAb5cDqEBAAAB"
    , sk "KPXCLIvKGY6NozqsdfgAeAGZNgka46HYitp1n5RlqG8tqLeqVPsAAAA=" )
  ; ( pk "KNztEcQ4/KcriidoDPC5H8V5otv2wvJQPxlcg2/TlOFBR69LfdMAAAAB"
    , sk "KPdCR+LJeRfaOOgg2VeIk3yAPJavBnew8UFd0e1gNajIQ7RJTR4DAAA=" ) ]

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
