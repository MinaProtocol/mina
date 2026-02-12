open Core
open Async
open Mina_base
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
      let convert = Account.Hardfork.migrate_to_mesa ~hardfork_slot
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
        ] )
