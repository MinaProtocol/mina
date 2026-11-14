open Core
open Async
open Mina_base

let%test_module "Catchup state of a loaded frontier" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let constraint_constants = precomputed_values.constraint_constants

    let proof_level = precomputed_values.proof_level

    module Context = struct
      let logger = logger

      let precomputed_values = precomputed_values

      let constraint_constants = constraint_constants

      let consensus_constants = precomputed_values.consensus_constants

      let proof_cache_db = Proof_cache_tag.For_tests.create_db ()

      let signature_kind = Mina_signature_kind.Testnet
    end

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default ~constraint_constants ~logger ~proof_level
            () )

    let max_length = 10

    let%test_unit "The catchup tree holds every breadcrumb of a frontier \
                   loaded from persistence" =
      let consensus_local_state =
        Consensus.Data.Local_state.create
          ~context:(module Context)
          ~genesis_ledger:precomputed_values.genesis_ledger
          ~genesis_epoch_data:precomputed_values.genesis_epoch_data
          ~epoch_ledger_location:
            ( Filename.temp_dir_name ^/ "epoch_ledger"
            ^ (Uuid_unix.create () |> Uuid.to_string) )
          ~genesis_state_hash:
            (State_hash.With_state_hashes.state_hash
               precomputed_values.protocol_state_with_hashes )
          ~epoch_ledger_backing_type:Stable_db
          Signature_lib.Public_key.Compressed.Set.empty
      in
      (* Fewer breadcrumbs than [max_length], so that the root doesn't move. *)
      let frontier =
        Quickcheck.random_value
          (Transition_frontier.For_tests.gen ~logger ~precomputed_values
             ~verifier ~consensus_local_state ~max_length ~size:(max_length / 2)
             () )
      in
      let state_hashes =
        Transition_frontier.all_breadcrumbs frontier
        |> List.map ~f:Transition_frontier.Breadcrumb.state_hash
      in
      assert (List.length state_hashes > 1) ;
      let persistent_root = Transition_frontier.persistent_root frontier in
      let persistent_frontier =
        Transition_frontier.persistent_frontier frontier
      in
      let loaded =
        Async.Thread_safe.block_on_async_exn (fun () ->
            let%bind () = Transition_frontier.close ~loc:__LOC__ frontier in
            match%map
              Transition_frontier.load
                ~context:(module Context)
                ~verifier ~consensus_local_state ~persistent_root
                ~persistent_frontier ~catchup_mode:`Super ()
            with
            | Ok loaded ->
                loaded
            | Error _ ->
                failwith "Couldn't load the persisted frontier" )
      in
      let (Full catchup_tree) = Transition_frontier.catchup_state loaded in
      List.iter state_hashes ~f:(fun state_hash ->
          if not (Hashtbl.mem catchup_tree.nodes state_hash) then
            failwithf "The catchup tree lacks breadcrumb %s"
              (State_hash.to_base58_check state_hash)
              () ) ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          Transition_frontier.close ~loc:__LOC__ loaded )
  end )
