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
  end )
