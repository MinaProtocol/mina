(** Mina: register all library layers and product executables.

    Layers group related libraries by domain.
    Products correspond to application executables in src/app. *)

let register () =
  (* Library layers *)
  Layer_ppx.register () ;
  Layer_base.register () ;
  Layer_concurrency.register () ;
  Layer_test.register () ;
  Layer_tooling.register () ;
  Layer_node.register () ;
  Layer_snarky.register () ;
  Layer_crypto.register () ;
  Layer_storage.register () ;
  Layer_infra.register () ;
  Layer_domain.register () ;
  Layer_ledger.register () ;
  Layer_transaction.register () ;
  Layer_protocol.register () ;
  Layer_network.register () ;
  (* Products *)
  Product_archive.register () ;
  Product_archive_blocks.register () ;
  Product_archive_hardfork_toolbox.register () ;
  Product_batch_txn_tool.register () ;
  Product_benchmarks.register () ;
  Product_best_tip_merger.register () ;
  Product_cli.register () ;
  Product_delegation_verify.register () ;
  Product_disk_caching_stats.register () ;
  Product_dump_blocks.register () ;
  Product_extract_blocks.register () ;
  Product_generate_keypair.register () ;
  Product_graphql_schema_dump.register () ;
  Product_heap_usage.register () ;
  Product_ledger_export_bench.register () ;
  Product_logproc.register () ;
  Product_missing_blocks_auditor.register () ;
  Product_reformat.register () ;
  Product_replayer.register () ;
  Product_rocksdb_scanner.register () ;
  Product_rosetta.register () ;
  Product_runtime_genesis_ledger.register () ;
  Product_test_executive.register () ;
  Product_validate_keypair.register () ;
  Product_zkapp_limits.register () ;
  Product_zkapp_test_transaction.register () ;
  Product_zkapps_examples.register ()
