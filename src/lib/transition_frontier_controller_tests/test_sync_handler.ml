open Core
open Async
open Coda_base
open Stubs

let%test_module "Sync_handler" =
  ( module struct
    let%test "sync with ledgers with another peer via glue_sync_ledger" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.create () in
      let num_breadcrumb_to_add = 3 in
      let max_length = num_breadcrumb_to_add + 2 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~max_length ~logger in
          let%bind () =
            build_frontier_randomly frontier
              ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
                Quickcheck.Generator.with_size ~size:num_breadcrumb_to_add
                @@ Quickcheck_lib.gen_imperative_list
                     (root_breadcrumb |> return |> Quickcheck.Generator.return)
                     (gen_breadcrumb ~logger) )
          in
          let source_ledger =
            Transition_frontier.root frontier
            |> Transition_frontier.Breadcrumb.staged_ledger
            |> Staged_ledger.ledger
          in
          let dest_ledger =
            Transition_frontier.best_tip frontier
            |> Transition_frontier.Breadcrumb.staged_ledger
            |> Staged_ledger.ledger
          in
          let desired_root = Ledger.merkle_root dest_ledger in
          let sync_ledger =
            Sync_ledger.create source_ledger ~parent_log:logger
          in
          let query_reader = Sync_ledger.query_reader sync_ledger in
          let answer_writer = Sync_ledger.answer_writer sync_ledger in
          let me =
            Network_peer.Peer.create Unix.Inet_addr.localhost ~discovery_port:0
              ~communication_port:1
          in
          let network =
            Network.create ~logger
              ~peers:(Network_peer.Peer.Table.of_alist_exn [(me, frontier)])
          in
          Network.glue_sync_ledger network query_reader answer_writer ;
          match%map Sync_ledger.fetch sync_ledger desired_root with
          | `Ok synced_ledger ->
              Ledger_hash.equal
                (Ledger.merkle_root source_ledger)
                (Ledger.merkle_root dest_ledger)
              && Ledger_hash.equal
                   (Ledger.merkle_root synced_ledger)
                   (Ledger.merkle_root dest_ledger)
          | `Target_changed _ ->
              failwith "target of sync_ledger should not change" )
  end )
