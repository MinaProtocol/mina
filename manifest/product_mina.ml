(** Mina product: library and executable declarations.

    Each declaration here corresponds to a dune file in the
    source tree. The manifest generates these files from
    the declarations below. *)

open Manifest
open Dune_s_expr

let register () =
  (* ============================================================ *)
  (* Tier 1: Trivial libraries                                    *)
  (* ============================================================ *)

  (* -- hex -------------------------------------------------------- *)
  library "hex"
    ~path:"src/lib/hex"
    ~deps:[ opam "core_kernel" ]
    ~ppx:(Ppx.custom
            [ "ppx_jane"; "ppx_version"; "ppx_inline_test" ])
    ~inline_tests:true;

  (* -- monad_lib -------------------------------------------------- *)
  library "monad_lib"
    ~path:"src/lib/monad_lib"
    ~deps:[ opam "core_kernel" ]
    ~ppx:Ppx.standard;

  (* -- with_hash -------------------------------------------------- *)
  library "with_hash"
    ~path:"src/lib/with_hash"
    ~deps:
      [ opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"; "ppx_jane"; "ppx_deriving_yojson"
         ; "ppx_deriving.std"; "ppx_version"
         ; "ppx_fields_conv"
         ]);

  (* -- pipe_lib --------------------------------------------------- *)
  library "pipe_lib"
    ~path:"src/lib/concurrency/pipe_lib"
    ~deps:
      [ opam "async_kernel"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib"
      ; local "logger"
      ; local "o1trace"
      ; local "run_in_thread"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"; "ppx_version"; "ppx_jane"
         ; "ppx_deriving.make"
         ])
    ~inline_tests:true;

  (* ============================================================ *)
  (* Tier 2: Moderate libraries                                   *)
  (* ============================================================ *)

  (* -- base58_check ----------------------------------------------- *)
  library "base58_check"
    ~path:"src/lib/base58_check"
    ~synopsis:"Base58Check implementation"
    ~deps:
      [ opam "base"
      ; opam "base58"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"; "ppx_base"; "ppx_deriving.std"
         ; "ppx_deriving_yojson"; "ppx_inline_test"
         ; "ppx_let"; "ppx_sexp_conv"; "ppx_version"
         ])
    ~inline_tests:true
    ~library_flags:[ "-linkall" ];

  (* -- currency --------------------------------------------------- *)
  library "currency"
    ~path:"src/lib/currency"
    ~synopsis:"Currency types"
    ~deps:
      [ opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "zarith"
      ; local "bignum_bigint"
      ; local "bitstring_lib"
      ; local "codable"
      ; local "kimchi_backend_common"
      ; local "mina_numbers"
      ; local "mina_wire_types"
      ; local "pickles"
      ; local "ppx_version.runtime"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "sgn"
      ; local "snark_bits"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "test_util"
      ; local "unsigned_extended"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"; "ppx_annot"; "ppx_assert"
         ; "ppx_bin_prot"; "ppx_compare"
         ; "ppx_custom_printf"; "ppx_deriving.std"
         ; "ppx_deriving_yojson"; "ppx_fields_conv"
         ; "ppx_hash"; "ppx_inline_test"; "ppx_let"
         ; "ppx_mina"; "ppx_sexp_conv"; "ppx_version"
         ])
    ~inline_tests:true
    ~library_flags:[ "-linkall" ];

  (* ============================================================ *)
  (* Tier 3: Virtual modules                                      *)
  (* ============================================================ *)

  (* -- mina_version ----------------------------------------------- *)
  library "mina_version"
    ~path:"src/lib/mina_version"
    ~deps:[ opam "core_kernel" ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "mina_version" ]
    ~default_implementation:"mina_version.normal";

  (* -- mina_version.normal ---------------------------------------- *)
  library "mina_version.normal"
    ~internal_name:"mina_version_normal"
    ~path:"src/lib/mina_version/normal"
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ]
    ~ppx:Ppx.minimal
    ~implements:"mina_version"
    ~extra_stanzas:
      [ "rule"
        @: [ "targets" @: [ atom "mina_version.ml" ]
           ; "deps"
             @: [ "sandbox" @: [ atom "none" ]
                ; list [ atom ":<"; atom "gen.sh" ]
                ; list [ atom "universe" ]
                ]
           ; "action"
             @: [ "run"
                  @: [ atom "bash"
                     ; atom "%{<}"
                     ; atom "%{targets}"
                     ]
                ]
           ]
      ];

  (* ============================================================ *)
  (* Tier 4: Edge cases                                           *)
  (* ============================================================ *)

  (* -- child_processes -------------------------------------------- *)
  library "child_processes"
    ~path:"src/lib/child_processes"
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ctypes"
      ; opam "ctypes.foreign"
      ; opam "integers"
      ; opam "ppx_hash.runtime-lib"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "error_json"
      ; local "logger"
      ; local "mina_stdlib_unix"
      ; local "pipe_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_assert"; "ppx_custom_printf"
         ; "ppx_deriving.show"; "ppx_here"
         ; "ppx_inline_test"; "ppx_let"; "ppx_mina"
         ; "ppx_pipebang"; "ppx_version"
         ])
    ~inline_tests:true
    ~foreign_stubs:("c", [ "caml_syslimits" ]);

  (* -- mina_base -------------------------------------------------- *)
  library "mina_base"
    ~path:"src/lib/mina_base"
    ~synopsis:
      "Snarks and friends necessary for keypair generation"
    ~deps:
      [ opam "async_kernel"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "base_quickcheck"
      ; opam "base_quickcheck.ppx_quickcheck"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "core_kernel.uuid"
      ; opam "digestif"
      ; opam "integers"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "sexp_diff_kernel"
      ; opam "sexplib0"
      ; opam "yojson"
      ; local "base58_check"
      ; local "bignum_bigint"
      ; local "blake2"
      ; local "block_time"
      ; local "codable"
      ; local "crypto_params"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "dummy_values"
      ; local "error_json"
      ; local "fields_derivers.graphql"
      ; local "fields_derivers.json"
      ; local "fields_derivers.zkapps"
      ; local "fold_lib"
      ; local "genesis_constants"
      ; local "hash_prefix_create"
      ; local "hash_prefix_states"
      ; local "hex"
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base.import"
      ; local "mina_base.util"
      ; local "mina_numbers"
      ; local "mina_signature_kind"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "one_or_two"
      ; local "outside_hash_image"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "ppx_version.runtime"
      ; local "proof_cache_tag"
      ; local "protocol_version"
      ; local "quickcheck_lib"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "rosetta_coding"
      ; local "run_in_thread"
      ; local "sgn"
      ; local "sgn_type"
      ; local "signature_lib"
      ; local "snark_bits"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "sparse_ledger_lib"
      ; local "test_util"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "base_quickcheck.ppx_quickcheck"; "h_list.ppx"
         ; "ppx_annot"; "ppx_assert"; "ppx_base"
         ; "ppx_bench"; "ppx_bin_prot"; "ppx_compare"
         ; "ppx_custom_printf"; "ppx_deriving.enum"
         ; "ppx_deriving.make"; "ppx_deriving.ord"
         ; "ppx_deriving_yojson"; "ppx_fields_conv"
         ; "ppx_here"; "ppx_inline_test"; "ppx_let"
         ; "ppx_mina"; "ppx_pipebang"; "ppx_sexp_conv"
         ; "ppx_snarky"; "ppx_variants_conv"
         ; "ppx_version"
         ])
    ~inline_tests:true
    ~library_flags:[ "-linkall" ];

  (* -- mina_base.import (sub-library) ----------------------------- *)
  library "mina_base.import"
    ~internal_name:"mina_base_import"
    ~path:"src/lib/mina_base/import"
    ~deps:[ local "signature_lib" ]
    ~ppx:Ppx.minimal;

  (* -- mina_base.util (sub-library) ------------------------------- *)
  library "mina_base.util"
    ~internal_name:"mina_base_util"
    ~path:"src/lib/mina_base/util"
    ~deps:
      [ opam "core_kernel"
      ; local "bignum_bigint"
      ; local "snark_params"
      ]
    ~ppx:Ppx.minimal;

  (* ============================================================ *)
  (* Executables (src/app)                                        *)
  (* ============================================================ *)

  (* -- archive ---------------------------------------------------- *)
  executable "archive"
    ~package:"archive"
    ~path:"src/app/archive"
    ~deps:
      [ opam "archive_cli"
      ; opam "async"
      ; opam "async_unix"
      ; opam "core_kernel"
      ; local "mina_version"
      ]
    ~modules:[ "archive" ]
    ~modes:[ "native" ]
    ~ppx:Ppx.minimal
    ~bisect_sigterm:true;

  (* -- generate_keypair ------------------------------------------- *)
  executable "mina-generate-keypair"
    ~internal_name:"generate_keypair"
    ~package:"generate_keypair"
    ~path:"src/app/generate_keypair"
    ~deps:
      [ opam "async"
      ; opam "async_unix"
      ; opam "cli_lib"
      ; opam "core_kernel"
      ; local "mina_version"
      ]
    ~modes:[ "native" ]
    ~flags:[ ":standard"; "-w"; "+a" ]
    ~ppx:Ppx.minimal;

  (* -- logproc ---------------------------------------------------- *)
  executable "logproc"
    ~path:"src/app/logproc"
    ~deps:
      [ opam "cmdliner"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; opam "stdio"
      ; opam "yojson"
      ; local "interpolator_lib"
      ; local "logger"
      ; local "logproc_lib"
      ; local "mina_stdlib"
      ]
    ~modules:[ "logproc" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_deriving.std" ]);

  ()
