(* Only show stdout for failed inline tests. *)
open Core_kernel

let%test_module "Persistent_root tests" =
  ( module struct
    let%test_unit "potential_snarked_ledgers to_yojson and of_yojson are \
                   inverses" =
      Quickcheck.test ~trials:10
        (Quickcheck.Generator.list_non_empty String.quickcheck_generator)
        ~f:(fun directory_names ->
          let open Mina_ledger.Root in
          let original_queue = Queue.create () in
          (* Alternate between Stable_db and Converting_db to test mixed configs *)
          List.iteri directory_names ~f:(fun i directory_name ->
              let backing_type =
                if i % 2 = 0 then Config.Stable_db
                else
                  Converting_db
                    (Mina_numbers.Global_slot_since_genesis.random ())
              in
              Queue.enqueue original_queue
                (Config.with_directory ~backing_type ~directory_name) ) ;

          let json =
            Persistent_root.Instance.potential_snarked_ledgers_to_yojson
              original_queue
          in

          let configs_list =
            Persistent_root.Instance.potential_snarked_ledgers_of_yojson json
          in

          let reconstructed_queue = Queue.create () in
          List.iter configs_list ~f:(Queue.enqueue reconstructed_queue) ;

          (* Compare directory names (the primary identifiers) *)
          let original_dirs =
            Queue.to_list original_queue |> List.map ~f:Config.primary_directory
          in
          let reconstructed_dirs =
            Queue.to_list reconstructed_queue
            |> List.map ~f:Config.primary_directory
          in

          [%test_eq: string list] original_dirs reconstructed_dirs )

    let%test_unit "string list JSON roundtrip preserves original strings" =
      Quickcheck.test ~trials:10
        (Quickcheck.Generator.list_non_empty String.quickcheck_generator)
        ~f:(fun directory_names ->
          let original_json =
            `List (List.map directory_names ~f:(fun s -> `String s))
          in

          let configs_list =
            Persistent_root.Instance.potential_snarked_ledgers_of_yojson
              original_json
          in

          let queue = Queue.create () in
          List.iter configs_list ~f:(Queue.enqueue queue) ;

          let reconstructed_json =
            Persistent_root.Instance.potential_snarked_ledgers_to_yojson queue
          in

          let reconstructed_strings =
            match reconstructed_json with
            | `List items ->
                List.map items ~f:(function
                  | `String s ->
                      s
                  | _ ->
                      failwith "Expected string in JSON list" )
            | _ ->
                failwith "Expected JSON list"
          in

          [%test_eq: string list] directory_names reconstructed_strings )

    let ledger_depth = 10

    (* [n] and [m] accounts, all with distinct identifiers. *)
    let random_accounts n m =
      let accounts =
        Quickcheck.random_value
          (Quickcheck.Generator.list_with_length
             (2 * (n + m))
             Mina_base.Account.gen )
        |> List.dedup_and_sort ~compare:(fun a b ->
               Mina_base.Account_id.compare
                 (Mina_base.Account.identifier a)
                 (Mina_base.Account.identifier b) )
      in
      assert (List.length accounts >= n + m) ;
      (List.take accounts n, List.sub accounts ~pos:n ~len:m)

    let create_ledger ~config accounts =
      let ledger =
        Mina_ledger.Root.create ~logger:(Logger.null ()) ~depth:ledger_depth
          ~config ()
      in
      Mina_ledger.Root.set_batch_accounts ledger
        (List.mapi accounts ~f:(fun i account ->
             (Mina_ledger.Ledger.Db.Addr.of_int_exn ~ledger_depth i, account) )
        ) ;
      ledger

    (* Recover a potential snarked ledger holding [accounts], after an
       interrupted recovery left [stale_accounts] in tmp_snarked_ledger. *)
    let recover_over_stale_tmp ~accounts ~stale_accounts =
      let directory =
        Filename.concat Filename.temp_dir_name
          ("persistent_root_test_" ^ Uuid.to_string (Uuid_unix.create ()))
      in
      Core.Unix.mkdir_p directory ;
      Exn.protect
        ~finally:(fun () -> Mina_stdlib_unix.File_system.rmrf directory)
        ~f:(fun () ->
          let factory =
            Persistent_root.create ~logger:(Logger.null ()) ~directory
              ~backing_type:Mina_ledger.Root.Config.Stable_db ~ledger_depth
          in
          let potential_config =
            Persistent_root.Config.make_potential_snarked_ledger factory
          in
          let potential = create_ledger ~config:potential_config accounts in
          let snarked_ledger_hash =
            Mina_base.Frozen_ledger_hash.of_ledger_hash
              (Mina_ledger.Root.merkle_root potential)
          in
          Mina_ledger.Root.close potential ;
          Yojson.Safe.to_file
            (Persistent_root.Config.potential_snarked_ledgers factory)
            (Persistent_root.Instance.potential_snarked_ledgers_to_yojson
               (Queue.of_list [ potential_config ]) ) ;
          let tmp_config = Persistent_root.Config.tmp_snarked_ledger factory in
          Mina_ledger.Root.close
            (create_ledger ~config:tmp_config stale_accounts) ;
          match
            Persistent_root.load_from_disk_exn factory ~snarked_ledger_hash
              ~logger:(Logger.null ())
          with
          | Error `Snarked_ledger_mismatch ->
              failwith "Recovering the potential snarked ledger failed"
          | Ok instance ->
              let snarked_ledger =
                Persistent_root.Instance.snarked_ledger instance
              in
              [%test_eq: Mina_base.Frozen_ledger_hash.t] snarked_ledger_hash
                (Mina_base.Frozen_ledger_hash.of_ledger_hash
                   (Mina_ledger.Root.merkle_root snarked_ledger) ) ;
              [%test_eq: int] (List.length accounts)
                (Mina_ledger.Root.num_accounts snarked_ledger) ;
              List.iter stale_accounts ~f:(fun account ->
                  assert (
                    Option.is_none
                      (Mina_ledger.Ledger.Any_ledger.M.location_of_account
                         (Mina_ledger.Root.as_unmasked snarked_ledger)
                         (Mina_base.Account.identifier account) ) ) ) ;
              assert (
                not
                  (Core.Sys.file_exists_exn
                     (Mina_ledger.Root.Config.primary_directory tmp_config) ) ) ;
              Persistent_root.Instance.close instance )

    let%test_unit "recovery ignores a leftover tmp_snarked_ledger with more \
                   accounts" =
      let accounts, stale_accounts = random_accounts 5 8 in
      recover_over_stale_tmp ~accounts ~stale_accounts

    let%test_unit "recovery ignores a leftover tmp_snarked_ledger with \
                   different accounts" =
      let accounts, stale_accounts = random_accounts 5 5 in
      recover_over_stale_tmp ~accounts ~stale_accounts
  end )
