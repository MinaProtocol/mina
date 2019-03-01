open Core
open Async
open Coda_base

let num_breadcrumb_to_add = 3

let max_length = num_breadcrumb_to_add + 2

module Stubs = Stubs.Make (struct
  let max_length = max_length
end)

open Stubs

let%test_module "Sync_handler" =
  ( module struct
    let%test "sync with ledgers from another peer via glue_sync_ledger" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.create () in
      Ledger.with_ephemeral_ledger ~f:(fun dest_ledger ->
          Thread_safe.block_on_async_exn (fun () ->
              let%bind frontier =
                create_root_frontier ~logger Genesis_ledger.accounts
              in
              let source_ledger =
                Transition_frontier.For_tests.root_snarked_ledger frontier
                |> Ledger.of_database
              in
              let desired_root = Ledger.merkle_root source_ledger in
              let sync_ledger =
                Sync_ledger.create dest_ledger ~parent_log:logger
              in
              let query_reader = Sync_ledger.query_reader sync_ledger in
              let answer_writer = Sync_ledger.answer_writer sync_ledger in
              let peer =
                Network_peer.Peer.create Unix.Inet_addr.localhost
                  ~discovery_port:0 ~communication_port:1
              in
              let network =
                Network.create ~logger
                  ~peers:
                    (Network_peer.Peer.Table.of_alist_exn [(peer, frontier)])
              in
              Network.glue_sync_ledger network query_reader answer_writer ;
              match%map Sync_ledger.fetch sync_ledger desired_root with
              | `Ok synced_ledger ->
                  Ledger_hash.equal
                    (Ledger.merkle_root dest_ledger)
                    (Ledger.merkle_root source_ledger)
                  && Ledger_hash.equal
                       (Ledger.merkle_root synced_ledger)
                       (Ledger.merkle_root source_ledger)
              | `Target_changed _ ->
                  failwith "target of sync_ledger should not change" ) )
  end )
