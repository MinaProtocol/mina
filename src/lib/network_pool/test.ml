open Async_kernel
open Core_kernel
open Pipe_lib
open Network_peer

let%test_module "network pool test" =
  ( module struct
    let trust_system = Mocks.trust_system

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let constraint_constants = precomputed_values.constraint_constants

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
      let priced_proof =
        { Priced_proof.proof =
            One_or_two.map ~f:Ledger_proof.For_tests.mk_dummy_proof work
        ; fee =
            { fee = Currency.Fee.zero
            ; prover = Signature_lib.Public_key.Compressed.empty
            }
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
      let create_work work =
        Mock_snark_pool.Resource_pool.Diff.Add_solved_work
          ( work
          , Priced_proof.
              { proof =
                  One_or_two.map ~f:Ledger_proof.For_tests.mk_dummy_proof work
              ; fee =
                  { fee = Currency.Fee.zero
                  ; prover = Signature_lib.Public_key.Compressed.empty
                  }
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
        List.map (List.take works per_reader) ~f:create_work
        |> List.map ~f:(fun work ->
               ( Envelope.Incoming.local work
               , Mina_net2.Validation_callback.create_without_expiration () ) )
        |> List.iter ~f:(fun diff ->
               Mock_snark_pool.Remote_sink.push remote_sink diff
               |> Deferred.don't_wait_for ) ;
        List.map (List.drop works per_reader) ~f:create_work
        |> List.iter ~f:(fun diff ->
               Mock_snark_pool.Local_sink.push local_sink (diff, Fn.const ())
               |> Deferred.don't_wait_for ) ;
        let%bind () = Mocks.Transition_frontier.refer_statements tf works in
        don't_wait_for
        @@ Linear_pipe.iter (Mock_snark_pool.broadcasts network_pool)
             ~f:(fun With_nonce.{ message = work_command; _ } ->
               let work =
                 match work_command with
                 | Mock_snark_pool.Resource_pool.Diff.Add_solved_work (work, _)
                   ->
                     work
                 | Mock_snark_pool.Resource_pool.Diff.Empty ->
                     assert false
               in
               assert (
                 List.mem works work
                   ~equal:Transaction_snark_work.Statement.equal ) ;
               Deferred.unit ) ;
        Deferred.unit
      in
      verify_unsolved_work |> Async.Thread_safe.block_on_async_exn
  end )
