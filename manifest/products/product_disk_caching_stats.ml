(** Product: disk_caching_stats — Disk caching performance stats. *)

open Manifest
open Externals

let () =
  executable "mina-disk-caching-stats" ~internal_name:"disk_caching_stats"
    ~package:"mina_disk_caching_stats" ~path:"src/app/disk_caching_stats"
    ~deps:
      [ base
      ; base_caml
      ; bigarray_compat
      ; bin_prot
      ; core
      ; core_kernel
      ; digestif
      ; sexplib0
      ; splittable_random
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_network.network_pool
      ; Layer_network.snark_profiler_lib
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_protocol.transaction_snark
      ; Layer_snark_worker.ledger_proof
      ; Layer_snark_worker.transaction_snark_scan_state
      ; Layer_transaction.mina_transaction_logic
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
