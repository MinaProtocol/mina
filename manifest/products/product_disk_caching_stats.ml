(** Product: disk_caching_stats — Disk caching performance stats. *)

open Manifest
open Externals

let () =
  executable "mina-disk-caching-stats" ~internal_name:"disk_caching_stats"
    ~package:"mina_disk_caching_stats" ~path:"src/app/disk_caching_stats"
    ~deps:
      [ base
      ; base_caml
      ; bin_prot
      ; bigarray_compat
      ; core
      ; core_kernel
      ; digestif
      ; sexplib0
      ; splittable_random
      ; Layer_crypto.crypto_params
      ; Layer_base.currency
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_crypto.kimchi_pasta
      ; Layer_crypto.kimchi_pasta_basic
      ; Layer_snark_worker.ledger_proof
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_ledger.mina_ledger
      ; Layer_infra.mina_numbers
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction_logic
      ; Layer_base.mina_wire_types
      ; Layer_network.network_pool
      ; Layer_base.one_or_two
      ; Layer_crypto.pickles
      ; Layer_crypto.pickles_backend
      ; Layer_crypto.pickles_types
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_network.snark_profiler_lib
      ; Layer_protocol.transaction_snark
      ; Layer_snark_worker.transaction_snark_scan_state
      ; Layer_base.with_hash
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
