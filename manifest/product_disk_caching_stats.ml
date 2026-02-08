(** Product: disk_caching_stats — Disk caching performance stats. *)

open Manifest

let register () =
  executable "mina-disk-caching-stats" ~internal_name:"disk_caching_stats"
    ~package:"mina_disk_caching_stats" ~path:"src/app/disk_caching_stats"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "bin_prot"
      ; opam "bigarray-compat"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "sexplib0"
      ; opam "splittable_random"
      ; local "crypto_params"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "ledger_proof"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_ledger"
      ; local "mina_numbers"
      ; local "mina_state"
      ; local "mina_transaction_logic"
      ; local "mina_wire_types"
      ; local "network_pool"
      ; local "one_or_two"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "snark_profiler_lib"
      ; local "transaction_snark"
      ; local "transaction_snark_scan_state"
      ; local "with_hash"
      ]
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_version" ]) ;

  ()
