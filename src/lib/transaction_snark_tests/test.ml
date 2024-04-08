let trivial_zkapp = Util.trivial_zkapp

let%test_module _ =
  ( module struct
    open Core
    open Mina_base
    open Signature_lib
    open Mina_generators.Zkapp_command_generators

    let `VK vk, `Prover _ = Lazy.force trivial_zkapp

    let mk_ledger ~num_of_unused_keys () =
      let keys = List.init 5 ~f:(fun _ -> Keypair.create ()) in
      let zkapp_keys = List.init 5 ~f:(fun _ -> Keypair.create ()) in
      let unused_keys =
        List.init num_of_unused_keys ~f:(fun _ -> Keypair.create ())
      in
      let account_ids =
        List.map keys ~f:(fun key ->
            Account_id.create
              (Signature_lib.Public_key.compress key.public_key)
              Token_id.default )
      in
      let zkapp_account_ids =
        List.map zkapp_keys ~f:(fun key ->
            Account_id.create
              (Signature_lib.Public_key.compress key.public_key)
              Token_id.default )
      in
      let balance = Currency.Balance.of_mina_int_exn 1_000_000 in
      let accounts =
        List.map account_ids ~f:(fun id -> Account.create id balance)
      in
      let zkapp_accounts =
        List.map zkapp_account_ids ~f:(fun id ->
            let account = Account.create id balance in
            let verification_key = Some vk in
            let zkapp = Some { Zkapp_account.default with verification_key } in
            { account with zkapp } )
      in
      let ledger = Mina_ledger.Ledger.create ~depth:10 () in
      List.iter2_exn (account_ids @ zkapp_account_ids)
        (accounts @ zkapp_accounts) ~f:(fun id account ->
          Mina_ledger.Ledger.get_or_create_account ledger id account
          |> Or_error.ok_exn
          |> fun _ -> () ) ;
      let keymap =
        List.map
          (keys @ zkapp_keys @ unused_keys)
          ~f:(fun { public_key; private_key } ->
            (Public_key.compress public_key, private_key) )
        |> Public_key.Compressed.Map.of_alist_exn
      in
      (ledger, List.hd_exn keys, keymap)

    let%test_unit "generate 100 zkapps with only 3 unused keys" =
      let ledger, fee_payer_keypair, keymap =
        mk_ledger ~num_of_unused_keys:3 ()
      in
      ignore
      @@ Quickcheck.Generator.(
           generate
             (list_with_length 100
                (gen_zkapp_command_from ~fee_payer_keypair ~keymap
                   ~no_token_accounts:true
                   ~account_state_tbl:(Account_id.Table.create ())
                   ~generate_new_accounts:false ~ledger () ) )
             ~size:100
             ~random:(Splittable_random.State.create Random.State.default))

    let%test_unit "generate zkapps with balance and fee range" =
      let ledger, fee_payer_keypair, keymap =
        mk_ledger ~num_of_unused_keys:3 ()
      in
      ignore
      @@ Quickcheck.Generator.(
           generate
             (list_with_length 100
                (gen_zkapp_command_from ~no_account_precondition:true
                   ~fee_payer_keypair ~keymap ~no_token_accounts:true
                   ~fee_range:
                     Currency.Fee.
                       (of_mina_string_exn "2", of_mina_string_exn "4")
                   ~balance_change_range:
                     Currency.Amount.
                       { min_balance_change = of_mina_string_exn "0"
                       ; max_balance_change = of_mina_string_exn "0.00001"
                       ; min_new_zkapp_balance = of_mina_string_exn "50"
                       ; max_new_zkapp_balance = of_mina_string_exn "100"
                       }
                   ~account_state_tbl:(Account_id.Table.create ())
                   ~generate_new_accounts:false ~ledger () ) )
             ~size:100
             ~random:(Splittable_random.State.create Random.State.default))
  end )
