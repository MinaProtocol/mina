open Core
open Async
open Mina_base
open Mina_transaction_logic.For_tests
module L = Mina_ledger.Ledger
module Root_ledger = Mina_ledger.Root

let logger = Logger.create ~id:"test_mina_ledger" ()

let quickcheck_size = 10

let ledger_depth = 10

let num_accounts = 200

let () = assert (num_accounts <= Int.shift_left 1 ledger_depth)

module Root_test = struct
  (** populate a root with at most [num] untimed accounts. This is because generated 
      accounts might duplicate *)
  let populate_with_random_untimed_accounts ~num ~root ~random =
    let unmasked = Root_ledger.as_unmasked root in
    let module LocMap = L.Any_ledger.Location.Map in
    Quickcheck.Generator.(
      list_with_length num Mina_base.Account.gen
      |> generate ~size:quickcheck_size ~random)
    |> List.fold ~init:LocMap.empty ~f:(fun acc acct ->
           let acct_id = Account_id.create acct.public_key Token_id.default in
           match L.Any_ledger.M.get_or_create_account unmasked acct_id acct with
           | Ok (_, loc) -> (
               match LocMap.add ~key:loc ~data:acct acc with
               | `Ok acc ->
                   acc
               | `Duplicate ->
                   (* NOTE: This branch will be ran into if randomly
                      generated accounts happened to clash *)
                   acc )
           | Error _ ->
               failwith "Could not add starting account" )

  let assert_accounts ~loc_with_accounts ~root =
    let module LocMap = L.Any_ledger.Location.Map in
    let locations = LocMap.keys loc_with_accounts in
    L.Any_ledger.M.get_batch (Root_ledger.as_unmasked root) locations
    |> List.iter ~f:(fun (loc, account) ->
           let actual_account =
             Option.value_exn account
               ~message:
                 "Account is inserted in stable db backed root, but when \
                  reloading with unstable DB backed root it's gone "
           in
           let expected = LocMap.find_exn loc_with_accounts loc in
           assert (
             Account.equal expected actual_account
             || failwith "Inserted account didn't match actual account" ) )

  let converting_config_with_random_hf_slot () =
    Root_ledger.Config.Converting_db
      (Mina_numbers.Global_slot_since_genesis.random ())

  (* When a node restarts, we should be able to replace the backing type of it
     with converting without any other change. This corresponds to setting HF
     mode to auto on a new release *)
  let test_stable_backing_compatible_with_converting ~random () =
    Mina_stdlib_unix.File_system.with_temp_dir
      "stable_backing_compatible_with_converting" ~f:(fun cwd ->
        (* NOTE: The converting ledger would be created as siblings of the
           primary ledger, hence we need a sub dir for `with_temp_dir` to clean
           up the garbages correctly after the test*)
        (* STEP 1: create a stable root, fill with some accounts, get the locs
           and closing *)
        let cfg =
          Root_ledger.Config.with_directory ~directory_name:(cwd ^/ "ledger")
        in
        let stable_root =
          Root_ledger.create ~logger
            ~config:(cfg ~backing_type:Stable_db)
            ~depth:ledger_depth ()
        in
        let loc_with_accounts =
          populate_with_random_untimed_accounts ~num:num_accounts
            ~root:stable_root ~random
        in
        Root_ledger.close stable_root ;
        let converting_root =
          Root_ledger.create ~logger
            ~config:
              (cfg ~backing_type:(converting_config_with_random_hf_slot ()))
            ~depth:ledger_depth ()
        in
        (* STEP 2: reopening the root now as converting, check accounts are
           matched up. *)
        assert_accounts ~loc_with_accounts ~root:converting_root ;
        Root_ledger.close converting_root ;
        Deferred.unit )

  let check_converting_open ~primary_dir ~hardfork_slot =
    let module Converting_ledger = L.Make_converting (struct
      let convert = Account.Hardfork.migrate_from_berkeley ~hardfork_slot
    end) in
    Converting_ledger.(
      create
        ~config:
          (In_directories (Config.with_primary ~directory_name:primary_dir))
        ~logger ~depth:ledger_depth ~assert_synced:true ()
      |> close)

  let test_root_moving ~random () =
    Mina_stdlib_unix.File_system.with_temp_dir "root_moving" ~f:(fun cwd ->
        (* NOTE: The converting ledger would be created as siblings of the
           primary ledger, hence we need a sub dir for `with_temp_dir` to clean
           up the garbages correctly after the test*)
        (* STEP 1: create a root, fill with some accounts, get the locs and
           closing *)
        (* TODO: consider design a proper generator for Root_ledger.Config.t
           later. *)
        let backing_type =
          Quickcheck.Generator.of_list
            [ Root_ledger.Config.Stable_db
            ; converting_config_with_random_hf_slot ()
            ]
          |> Quickcheck.Generator.generate ~size:quickcheck_size ~random
        in
        let config =
          Root_ledger.Config.with_directory ~directory_name:(cwd ^/ "ledger")
            ~backing_type
        in
        let root = Root_ledger.create ~logger ~config ~depth:ledger_depth () in
        let loc_with_accounts =
          populate_with_random_untimed_accounts ~num:num_accounts ~root ~random
        in
        Root_ledger.close root ;
        let moved_primary_dir = cwd ^/ "ledger_moved" in
        let config_moved =
          Root_ledger.Config.with_directory ~directory_name:moved_primary_dir
            ~backing_type
        in
        Root_ledger.Config.move_backing_exn ~src:config ~dst:config_moved ;
        assert (
          (not (Root_ledger.Config.exists_any_backing config))
          && Root_ledger.Config.exists_backing config_moved
          || failwith "Config is not moved" ) ;
        let root_moved =
          Root_ledger.create ~logger ~config:config_moved ~depth:ledger_depth ()
        in

        (* STEP 2: reopening the root in moved location, check accounts is
           matched up. *)
        assert_accounts ~loc_with_accounts ~root:root_moved ;
        Root_ledger.close root_moved ;
        ( match backing_type with
        | Converting_db hardfork_slot ->
            check_converting_open ~primary_dir:moved_primary_dir ~hardfork_slot
        | _ ->
            () ) ;
        Deferred.unit )

  let test_root_make_checkpointing ~random () =
    Mina_stdlib_unix.File_system.with_temp_dir "root_make_checkpointing"
      ~f:(fun cwd ->
        (* NOTE: The converting ledger would be created as siblings of the
           primary ledger, hence we need a sub dir for `with_temp_dir` to clean
           up the garbages correctly after the test*)
        (* STEP 1: create a root, fill with some accounts, get the locs and
           closing *)
        let backing_type =
          Quickcheck.Generator.of_list
            [ Root_ledger.Config.Stable_db
            ; converting_config_with_random_hf_slot ()
            ]
          |> Quickcheck.Generator.generate ~size:quickcheck_size ~random
        in
        let config =
          Root_ledger.Config.with_directory ~directory_name:(cwd ^/ "ledger")
            ~backing_type
        in
        let root = Root_ledger.create ~logger ~config ~depth:ledger_depth () in
        let loc_with_accounts =
          populate_with_random_untimed_accounts ~num:num_accounts ~root ~random
        in
        let checkpointed_primary_dir = cwd ^/ "ledger_checkpointed" in
        let config_checkpoint =
          Root_ledger.Config.with_directory
            ~directory_name:checkpointed_primary_dir ~backing_type
        in
        Root_ledger.make_checkpoint root ~config:config_checkpoint ;
        Root_ledger.close root ;
        let root_checkpointed =
          Root_ledger.create ~logger ~config:config_checkpoint
            ~depth:ledger_depth ()
        in
        (* STEP 2: opening the checkpointed root, check accounts are matched up. *)
        assert_accounts ~loc_with_accounts ~root:root_checkpointed ;
        Root_ledger.close root_checkpointed ;
        ( match backing_type with
        | Converting_db hardfork_slot ->
            check_converting_open ~primary_dir:checkpointed_primary_dir
              ~hardfork_slot
        | _ ->
            () ) ;
        Deferred.unit )

  (** Test that a root created with a stable backing and then made converting
      has the expected database states *)
  let test_root_make_converting ~random () =
    Mina_stdlib_unix.File_system.with_temp_dir "root_gradual_migration"
      ~f:(fun cwd ->
        let cfg =
          Root_ledger.Config.with_directory ~directory_name:(cwd ^/ "ledger")
        in
        let root =
          Root_ledger.create ~logger
            ~config:(cfg ~backing_type:Stable_db)
            ~depth:ledger_depth ()
        in
        let loc_with_accounts =
          populate_with_random_untimed_accounts ~num:num_accounts ~root ~random
        in
        let%bind root =
          Root_ledger.make_converting
            ~hardfork_slot:(Mina_numbers.Global_slot_since_genesis.random ())
            root
        in
        (* Make sure the stable accounts are all still present *)
        assert_accounts ~loc_with_accounts ~root ;
        Root_ledger.close root ;
        (* Re-open the root as converting to check that the databases are in
           sync *)
        let converting_root =
          Root_ledger.create ~logger
            ~config:
              (cfg ~backing_type:(converting_config_with_random_hf_slot ()))
            ~depth:ledger_depth ~assert_synced:true ()
        in
        Root_ledger.close converting_root ;
        Deferred.unit )
end

module Ledger_test = struct
  open Zkapp_command_builder

  let constraint_constants =
    Genesis_constants.For_unit_tests.Constraint_constants.t

  let ledger_get_exn ledger pk token =
    match
      L.Ledger_inner.get_or_create ledger (Account_id.create pk token)
      |> Or_error.ok_exn
    with
    | `Added, _, _ ->
        failwith "Account did not exist"
    | `Existed, acct, _ ->
        acct

  let test_tokens () =
    let keypair_and_amounts = Quickcheck.random_value (Init_ledger.gen ()) in
    let pk =
      let kp, _ = keypair_and_amounts.(0) in
      Signature_lib.Public_key.compress kp.public_key
    in
    let main (ledger : L.t) =
      let execute_zkapp_command_transaction
          (account_updates :
            ( Account_update.Body.Simple.t
            , unit
            , unit )
            Zkapp_command.Call_forest.t ) : unit =
        let _, ({ nonce; _ } : Account.t), _ =
          L.Ledger_inner.get_or_create ledger
            (Account_id.create pk Token_id.default)
          |> Or_error.ok_exn
        in
        let zkapp_command =
          mk_zkapp_command ~fee:7 ~fee_payer_pk:pk ~fee_payer_nonce:nonce
            account_updates
        in
        match
          L.apply_zkapp_command_unchecked ~signature_kind ~constraint_constants
            ~global_slot:
              (Mina_numbers.Global_slot_since_genesis.succ
                 view.global_slot_since_genesis )
            ~state_view:view ledger zkapp_command
        with
        | Ok ({ command = { status; _ }; _ }, _) -> (
            match status with
            | Transaction_status.Applied ->
                ()
            | Failed failures ->
                let indexed_failures :
                    (int * Transaction_status.Failure.t list) list =
                  Transaction_status.Failure.Collection.to_display failures
                in
                let formatted_failures =
                  List.map indexed_failures ~f:(fun (ndx, fails) ->
                      sprintf "Index: %d  Failures: %s" ndx
                        ( List.map fails ~f:Transaction_status.Failure.to_string
                        |> String.concat ~sep:"," ) )
                  |> String.concat ~sep:"; "
                in
                failwithf "Transaction failed: %s" formatted_failures () )
        | Error err ->
            failwithf "Error executing transaction: %s"
              (Error.to_string_hum err) ()
      in
      let token_funder, _ = keypair_and_amounts.(1) in
      let token_funder_pk =
        token_funder.public_key |> Signature_lib.Public_key.compress
      in
      let token_owner = Signature_lib.Keypair.create () in
      let token_owner_pk =
        token_owner.public_key |> Signature_lib.Public_key.compress
      in
      let token_account1 = Signature_lib.Keypair.create () in
      let token_account2 = Signature_lib.Keypair.create () in
      (* patch ledger so that token funder account has Proof send permission and a
         zkapp acount dummy verification key

         allows use of Proof authorization in `create_token` zkApp, below
      *)
      L.iteri ledger ~f:(fun _n acct ->
          if
            Signature_lib.Public_key.Compressed.equal acct.public_key
              token_funder_pk
          then
            let acct_id = Account_id.create token_funder_pk Token_id.default in
            let loc =
              Option.value_exn @@ L.location_of_account ledger acct_id
            in
            let acct_with_zkapp =
              { acct with
                permissions =
                  { acct.permissions with
                    send = Permissions.Auth_required.Proof
                  }
              ; zkapp =
                  Some
                    { Zkapp_account.default with
                      verification_key =
                        Some
                          With_hash.
                            { data = Side_loaded_verification_key.dummy
                            ; hash = Zkapp_account.dummy_vk_hash ()
                            }
                    }
              }
            in
            L.set ledger loc acct_with_zkapp ) ;
      let account_creation_fee =
        Currency.Fee.to_nanomina_int constraint_constants.account_creation_fee
      in
      let create_token :
          (Account_update.Body.Simple.t, unit, unit) Zkapp_command.Call_forest.t
          =
        mk_forest
          [ mk_node
              (mk_account_update_body
                 (Proof (Zkapp_account.dummy_vk_hash ()))
                 No token_funder Token_id.default
                 (-(4 * account_creation_fee)) )
              []
          ; mk_node
              (mk_account_update_body Signature No token_owner Token_id.default
                 (3 * account_creation_fee) )
              []
          ]
      in
      let custom_token_id =
        Account_id.derive_token_id
          ~owner:(Account_id.create token_owner_pk Token_id.default)
      in
      let token_minting =
        mk_forest
          [ mk_node
              (mk_account_update_body Signature No token_owner Token_id.default
                 (-account_creation_fee) )
              [ mk_node
                  (mk_account_update_body None_given Parents_own_token
                     token_account1 custom_token_id 100 )
                  []
              ]
          ]
      in
      let token_transfers =
        mk_forest
          [ mk_node
              (mk_account_update_body Signature No token_owner Token_id.default
                 (-account_creation_fee) )
              [ mk_node
                  (mk_account_update_body Signature Parents_own_token
                     token_account1 custom_token_id (-30) )
                  []
              ; mk_node
                  (mk_account_update_body None_given Parents_own_token
                     token_account2 custom_token_id 30 )
                  []
              ; mk_node
                  (mk_account_update_body Signature Parents_own_token
                     token_account1 custom_token_id (-10) )
                  []
              ; mk_node
                  (mk_account_update_body None_given Parents_own_token
                     token_account2 custom_token_id 10 )
                  []
              ; mk_node
                  (mk_account_update_body Signature Parents_own_token
                     token_account2 custom_token_id (-5) )
                  []
              ; mk_node
                  (mk_account_update_body None_given Parents_own_token
                     token_account1 custom_token_id 5 )
                  []
              ]
          ]
      in
      let check_token_balance k balance =
        [%test_eq: Currency.Balance.t]
          (ledger_get_exn ledger
             (Signature_lib.Public_key.compress
                k.Signature_lib.Keypair.public_key )
             custom_token_id )
            .balance
          (Currency.Balance.of_nanomina_int_exn balance)
      in
      execute_zkapp_command_transaction create_token ;
      (* Check that token_owner exists *)
      let (_ : Account.t) =
        ledger_get_exn ledger token_owner_pk Token_id.default
      in
      execute_zkapp_command_transaction token_minting ;
      check_token_balance token_account1 100 ;
      execute_zkapp_command_transaction token_transfers ;
      check_token_balance token_account1 65 ;
      check_token_balance token_account2 35
    in
    L.with_ledger ~depth ~f:(fun ledger ->
        Init_ledger.init
          (module L.Ledger_inner)
          [| keypair_and_amounts.(0); keypair_and_amounts.(1) |]
          ledger ;
        main ledger )

  let test_zkapp_command_payment () =
    let constraint_constants =
      { Genesis_constants.For_unit_tests.Constraint_constants.t with
        account_creation_fee = Currency.Fee.of_nanomina_int_exn 1
      }
    in
    Quickcheck.test ~trials:1 Test_spec.gen ~f:(fun { init_ledger; specs } ->
        let ts1 : Signed_command.t list = List.map specs ~f:command_send in
        let ts2 : Zkapp_command.t list =
          List.map specs ~f:(fun s ->
              let use_full_commitment =
                Quickcheck.random_value Bool.quickcheck_generator
              in
              account_update_send ~use_full_commitment s )
        in
        L.with_ledger ~depth ~f:(fun l1 ->
            L.with_ledger ~depth ~f:(fun l2 ->
                Init_ledger.init (module L.Ledger_inner) init_ledger l1 ;
                Init_ledger.init (module L.Ledger_inner) init_ledger l2 ;
                let open Result.Let_syntax in
                let%bind () =
                  iter_err ts1 ~f:(fun t ->
                      L.apply_user_command_unchecked l1 t ~constraint_constants
                        ~txn_global_slot )
                in
                let%bind () =
                  iter_err ts2 ~f:(fun t ->
                      let%bind res, _ =
                        L.apply_zkapp_command_unchecked ~signature_kind l2 t
                          ~constraint_constants ~global_slot:txn_global_slot
                          ~state_view:view
                      in
                      match res.command.status with
                      | Transaction_status.Applied ->
                          Ok ()
                      | Transaction_status.Failed failure ->
                          Or_error.error_string
                            (Yojson.Safe.pretty_to_string
                               (Transaction_status.Failure.Collection.to_yojson
                                  failure ) ) )
                in
                let accounts =
                  List.concat_map ~f:Zkapp_command.accounts_referenced ts2
                in
                (* TODO: Hack. The nonces are inconsistent between the 2
                   versions. See the comment in
                   [Mina_transaction_logic.For_tests.account_update_send] for more info.
                *)
                L.iteri l1 ~f:(fun index account ->
                    L.set_at_index_exn l1 index
                      { account with
                        nonce =
                          account.nonce |> Mina_numbers.Account_nonce.to_uint32
                          |> Unsigned.UInt32.(mul (of_int 2))
                          |> Mina_numbers.Account_nonce.to_uint32
                      } ) ;
                test_eq (module L.Ledger_inner) accounts l1 l2 ) )
        |> Or_error.ok_exn )

  let test_user_command_on_masked_ledger () =
    let constraint_constants =
      { Genesis_constants.For_unit_tests.Constraint_constants.t with
        account_creation_fee = Currency.Fee.of_nanomina_int_exn 1
      }
    in
    Quickcheck.test ~trials:1 Test_spec.gen ~f:(fun { init_ledger; specs } ->
        let cmds = List.map specs ~f:command_send in
        L.with_ledger ~depth ~f:(fun l ->
            Init_ledger.init (module L.Ledger_inner) init_ledger l ;
            let init_merkle_root = L.merkle_root l in
            let m =
              L.Maskable.register_mask
                (L.Any_ledger.cast (module L) l)
                (L.Mask.create ~depth:(L.depth l) ())
            in
            let () =
              iter_err cmds
                ~f:
                  (L.apply_user_command_unchecked ~constraint_constants
                     ~txn_global_slot l )
              |> Or_error.ok_exn
            in
            assert (not (Ledger_hash.equal init_merkle_root (L.merkle_root l))) ;
            (*Parent updates reflected in child masks*)
            assert (Ledger_hash.equal (L.merkle_root l) (L.merkle_root m)) ) )

  let test_zkapp_command_on_masked_ledger () =
    let constraint_constants =
      { Genesis_constants.For_unit_tests.Constraint_constants.t with
        account_creation_fee = Currency.Fee.of_nanomina_int_exn 1
      }
    in
    Quickcheck.test ~trials:1 Test_spec.gen ~f:(fun { init_ledger; specs } ->
        let cmds =
          List.map specs ~f:(fun spec ->
              let use_full_commitment =
                Quickcheck.random_value Bool.quickcheck_generator
              in
              account_update_send ~use_full_commitment
                ~double_sender_nonce:false spec )
        in
        L.with_ledger ~depth ~f:(fun l ->
            Init_ledger.init (module L.Ledger_inner) init_ledger l ;
            let init_merkle_root = L.merkle_root l in
            let m =
              L.Maskable.register_mask
                (L.Any_ledger.cast (module L) l)
                (L.Mask.create ~depth:(L.depth l) ())
            in
            let () =
              iter_err cmds
                ~f:
                  (L.apply_zkapp_command_unchecked ~signature_kind
                     ~constraint_constants ~global_slot:txn_global_slot
                     ~state_view:view l )
              |> Or_error.ok_exn
            in
            assert (not (Ledger_hash.equal init_merkle_root (L.merkle_root l))) ;
            (*Parent updates reflected in child masks*)
            assert (Ledger_hash.equal (L.merkle_root l) (L.merkle_root m)) ) )

  let test_user_command_on_converting_ledger () =
    let constraint_constants =
      { Genesis_constants.For_unit_tests.Constraint_constants.t with
        account_creation_fee = Currency.Fee.of_nanomina_int_exn 1
      }
    in
    let logger = Logger.create () in
    Quickcheck.test ~trials:1 Test_spec.gen ~f:(fun { init_ledger; specs } ->
        let cmds = List.map specs ~f:command_send in
        L.Ledger_inner.Converting_for_tests.with_converting_ledger_exn ~logger
          ~depth ~f:(fun (l, cl) ->
            Init_ledger.init (module L.Ledger_inner) init_ledger l ;
            let init_merkle_root = L.merkle_root l in
            let init_cl_merkle_root = L.Hardfork_db.merkle_root cl in
            let () =
              iter_err cmds
                ~f:
                  (L.apply_user_command_unchecked ~constraint_constants
                     ~txn_global_slot l )
              |> Or_error.ok_exn
            in
            (* Assert that the ledger and the converting ledger are non-empty *)
            assert (not (Ledger_hash.equal init_merkle_root (L.merkle_root l))) ;
            L.commit l ;
            assert (
              not
                (Ledger_hash.equal init_cl_merkle_root
                   (L.Hardfork_db.merkle_root cl) ) ) ;
            (* Assert that the converted ledger has the same accounts as the first one, up to conversion *)
            L.iteri l ~f:(fun index account ->
                let account_converted =
                  L.Hardfork_db.get_at_index_exn cl index
                in
                assert (
                  Mina_base.Account.Hardfork.(
                    equal (of_stable account) account_converted) ) ) ;
            (* Assert that the converted ledger doesn't have anything "extra" compared to the primary ledger *)
            L.Hardfork_db.iteri cl ~f:(fun index account_converted ->
                let account = L.get_at_index_exn l index in
                assert (
                  Mina_base.Account.Key.(
                    equal account.public_key account_converted.public_key) ) ) ) )
end

module Sparse_ledger_test = struct
  let test_of_ledger_subset_exn_with_nonexistent_keys () =
    let keygen () =
      let privkey = Signature_lib.Private_key.create () in
      ( privkey
      , Signature_lib.Public_key.of_private_key_exn privkey
        |> Signature_lib.Public_key.compress )
    in
    L.with_ledger
      ~depth:
        Genesis_constants.For_unit_tests.Constraint_constants.t.ledger_depth
      ~f:(fun ledger ->
        let _, pub1 = keygen () in
        let _, pub2 = keygen () in
        let aid1 = Account_id.create pub1 Token_id.default in
        let aid2 = Account_id.create pub2 Token_id.default in
        let sl =
          Mina_ledger.Sparse_ledger.of_ledger_subset_exn ledger [ aid1; aid2 ]
        in
        [%test_eq: Ledger_hash.t] (L.merkle_root ledger)
          ( (Mina_ledger.Sparse_ledger.merkle_root sl :> Random_oracle.Digest.t)
          |> Ledger_hash.of_hash ) )
end

let () =
  let random = Splittable_random.State.create Random.State.default in
  Async.Thread_safe.block_on_async_exn (fun () ->
      Alcotest_async.run "Mina Ledger"
        [ ( "Root"
          , [ Alcotest_async.test_case
                "closing stable root, reload as converting" `Quick
                (Root_test.test_stable_backing_compatible_with_converting
                   ~random )
            ; Alcotest_async.test_case "moving a root" `Quick
                (Root_test.test_root_moving ~random)
            ; Alcotest_async.test_case "make checkpointing a root" `Quick
                (Root_test.test_root_make_checkpointing ~random)
            ; Alcotest_async.test_case "make converting a root" `Quick
                (Root_test.test_root_make_converting ~random)
            ] )
        ; ( "Ledger"
          , [ Alcotest_async.test_case_sync "tokens test" `Quick
                Ledger_test.test_tokens
            ; Alcotest_async.test_case_sync "zkapp_command payment test" `Quick
                Ledger_test.test_zkapp_command_payment
            ; Alcotest_async.test_case_sync
                "user_command application on masked ledger" `Quick
                Ledger_test.test_user_command_on_masked_ledger
            ; Alcotest_async.test_case_sync
                "zkapp_command application on masked ledger" `Quick
                Ledger_test.test_zkapp_command_on_masked_ledger
            ; Alcotest_async.test_case_sync
                "user_command application on converting ledger" `Quick
                Ledger_test.test_user_command_on_converting_ledger
            ] )
        ; ( "Sparse_ledger"
          , [ Alcotest_async.test_case_sync
                "of_ledger_subset_exn with keys that don't exist works" `Quick
                Sparse_ledger_test
                .test_of_ledger_subset_exn_with_nonexistent_keys
            ] )
        ] )
