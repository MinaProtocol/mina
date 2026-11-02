open Async_kernel
open Core_kernel
open Pipe_lib
open Network_peer

let%test_module "network pool test" =
  ( module struct
    let trust_system = Mocks.trust_system

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    (* SNARK work is rejected if the prover doesn't have an account and the fee
       is below the account creation fee, so waive the fee for test work. *)
    let constraint_constants =
      { precomputed_values.constraint_constants with
        account_creation_fee = Currency.Fee.zero
      }

    let consensus_constants = precomputed_values.consensus_constants

    let proof_level = precomputed_values.proof_level

    let time_controller = Block_time.Controller.basic ~logger

    let block_window_duration =
      Mina_compile_config.For_unit_tests.t.block_window_duration

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default ~constraint_constants ~logger ~proof_level
            () )

    module Mock_snark_pool =
      Snark_pool.Make (Mocks.Base_ledger) (Mocks.Staged_ledger)
        (Mocks.Transition_frontier)

    let proof_cache_db = Proof_cache_tag.For_tests.create_db ()

    let config =
      Mock_snark_pool.Resource_pool.make_config ~verifier ~trust_system
        ~disk_location:"/tmp/snark-pool" ~proof_cache_db

    let%test_unit "Work that gets fed into apply_and_broadcast will be \
                   received in the pool's reader" =
      let tf = Mocks.Transition_frontier.create [] in
      let frontier_broadcast_pipe_r, _ = Broadcast_pipe.create (Some tf) in
      let work =
        `One
          (Quickcheck.random_value ~seed:(`Deterministic "network_pool_test")
             Transaction_snark.Statement.gen )
      in
      let fee_ =
        { Mina_base.Fee_with_prover.fee = Currency.Fee.zero
        ; prover = Signature_lib.Public_key.Compressed.empty
        }
      in
      let priced_proof =
        { Priced_proof.proof =
            One_or_two.map
              ~f:(fun statement ->
                Ledger_proof.For_tests.mk_dummy_proof ~statement ~fee:fee_.fee
                  ~prover:fee_.prover )
              work
        ; fee = fee_
        }
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let network_pool, _, _ =
            Mock_snark_pool.create ~config ~logger ~constraint_constants
              ~consensus_constants ~time_controller
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
              ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
              ~block_window_duration
          in
          let%bind () =
            Mocks.Transition_frontier.refer_statements tf [ work ]
          in
          let read_proofs =
            One_or_two.map ~f:Ledger_proof.Cached.read_proof_from_disk
          in
          let command =
            Mock_snark_pool.Resource_pool.Diff.Cached.write_all_proofs_to_disk
              ~proof_cache_db
              (Add_solved_work (work, priced_proof))
          in
          Mock_snark_pool.apply_and_broadcast network_pool
            (Envelope.Incoming.local command)
            (Mock_snark_pool.Broadcast_callback.Local (Fn.const ())) ;
          let%map _ =
            Linear_pipe.read (Mock_snark_pool.broadcasts network_pool)
          in
          let pool = Mock_snark_pool.resource_pool network_pool in
          match Mock_snark_pool.Resource_pool.request_proof pool work with
          | Some { proof; fee = _ } ->
              assert (
                [%equal: Ledger_proof.t One_or_two.t] (read_proofs proof)
                  priced_proof.proof )
          | None ->
              failwith "There should have been a proof here" )

    let%test_unit "when creating a network, the incoming diffs and local diffs \
                   in the reader pipes will automatically get process" =
      let work_count = 10 in
      let works =
        Quickcheck.random_sequence ~seed:(`Deterministic "works")
          Transaction_snark.Statement.gen
        |> Fn.flip Sequence.take work_count
        |> Sequence.map ~f:(fun x -> `One x)
        |> Sequence.to_list
      in
      let per_reader = work_count / 2 in
      let fee_ =
        { Mina_base.Fee_with_prover.fee = Currency.Fee.zero
        ; prover =
            Quickcheck.random_value ~seed:(`Deterministic "prover")
              Signature_lib.Public_key.Compressed.gen
        }
      in
      let create_work work =
        Mock_snark_pool.Resource_pool.Diff.Add_solved_work
          ( work
          , Priced_proof.
              { proof =
                  One_or_two.map
                    ~f:(fun statement ->
                      Ledger_proof.For_tests.mk_dummy_proof ~statement
                        ~fee:fee_.fee ~prover:fee_.prover )
                    work
              ; fee = fee_
              } )
      in
      let verify_unsolved_work () =
        let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
        let tf = Mocks.Transition_frontier.create [] in
        let frontier_broadcast_pipe_r, _ = Broadcast_pipe.create (Some tf) in
        let network_pool, remote_sink, local_sink =
          Mock_snark_pool.create ~config ~logger ~constraint_constants
            ~consensus_constants ~time_controller
            ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
            ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
            ~block_window_duration
        in
        let%bind () = Mocks.Transition_frontier.refer_statements tf works in
        let remote_works = List.take works per_reader in
        let local_works = List.drop works per_reader in
        let remote_callbacks =
          List.map remote_works ~f:(fun work ->
              let cb =
                Mina_net2.Validation_callback.create_without_expiration ()
              in
              Mock_snark_pool.Remote_sink.push remote_sink
                (Envelope.Incoming.local (create_work work), cb)
              |> Deferred.don't_wait_for ;
              cb )
        in
        let local_results =
          List.map local_works ~f:(fun work ->
              let result = Ivar.create () in
              Mock_snark_pool.Local_sink.push local_sink
                (create_work work, Ivar.fill result)
              |> Deferred.don't_wait_for ;
              Ivar.read result )
        in
        (* Remote diffs are accepted for gossip by libp2p, not rebroadcast by
           the pool. *)
        let%bind () =
          Deferred.List.iter remote_callbacks ~f:(fun cb ->
              match%map Mina_net2.Validation_callback.await_exn cb with
              | `Accept ->
                  ()
              | `Reject | `Ignore ->
                  failwith "Remote work was not accepted" )
        in
        let%bind () =
          Deferred.List.iter local_results ~f:(fun result ->
              match%map result with
              | Ok (`Broadcasted, _, _) ->
                  ()
              | Ok (`Not_broadcasted, _, _) ->
                  failwith "Local work was not broadcast"
              | Error err ->
                  Error.raise err )
        in
        let%map broadcast_works =
          Deferred.List.init (List.length local_works) ~f:(fun _ ->
              match%map
                Linear_pipe.read (Mock_snark_pool.broadcasts network_pool)
              with
              | `Ok
                  With_nonce.
                    { message =
                        Mock_snark_pool.Resource_pool.Diff.Add_solved_work
                          (work, _)
                    ; _
                    } ->
                  work
              | `Ok { message = Mock_snark_pool.Resource_pool.Diff.Empty; _ } ->
                  failwith "Unexpected empty diff broadcast"
              | `Eof ->
                  failwith "Broadcast pipe closed" )
        in
        [%test_eq: Transaction_snark_work.Statement.t list]
          (List.sort ~compare:Transaction_snark_work.Statement.compare
             broadcast_works )
          (List.sort ~compare:Transaction_snark_work.Statement.compare
             local_works ) ;
        let pool = Mock_snark_pool.resource_pool network_pool in
        List.iter works ~f:(fun work ->
            assert (
              Option.is_some
                (Mock_snark_pool.Resource_pool.request_proof pool work) ) )
      in
      verify_unsolved_work |> Async.Thread_safe.block_on_async_exn
  end )
