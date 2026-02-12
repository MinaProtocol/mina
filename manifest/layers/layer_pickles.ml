(** Mina pickles layer: recursive proof composition system.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let pickles_types =
  library "pickles_types" ~path:"src/lib/crypto/pickles_types"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ]
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; result
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.plonkish_prelude
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "kimchi_pasta_snarky_backend"
      ; local "kimchi_types"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.h_list_ppx
         ] )

let pickles_base_one_hot_vector =
  library "pickles_base.one_hot_vector" ~internal_name:"one_hot_vector"
    ~path:"src/lib/crypto/pickles_base/one_hot_vector"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:[ core_kernel; pickles_types; Snarky_lib.snarky_backendless ]
    ~ppx:Ppx.standard

let pickles_base =
  library "pickles_base" ~path:"src/lib/crypto/pickles_base"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ]
    ~deps:
      [ base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; pickles_base_one_hot_vector
      ; pickles_types
      ; ppxlib
      ; sexplib0
      ; Layer_base.mina_wire_types
      ; Layer_crypto.random_oracle_input
      ; Layer_kimchi.plonkish_prelude
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ] )

let pickles_backend =
  library "pickles.backend" ~internal_name:"backend"
    ~path:"src/lib/crypto/pickles/backend"
    ~deps:
      [ Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ]
    ~ppx:Ppx.mina_rich

let pickles_limb_vector =
  library "pickles.limb_vector" ~internal_name:"limb_vector"
    ~path:"src/lib/crypto/pickles/limb_vector"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~modules_without_implementation:[ "limb_vector" ]
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; pickles_backend
      ; pickles_types
      ; result
      ; sexplib0
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:Ppx.mina_rich

let pickles_pseudo =
  library "pickles.pseudo" ~internal_name:"pseudo"
    ~path:"src/lib/crypto/pickles/pseudo"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ core_kernel
      ; pickles_base
      ; pickles_base_one_hot_vector
      ; pickles_types
      ; Snarky_lib.snarky_backendless
      ; local "pickles_plonk_checks"
      ]
    ~ppx:Ppx.mina_rich

let pickles_composition_types =
  library "pickles.composition_types" ~internal_name:"composition_types"
    ~path:"src/lib/crypto/pickles/composition_types"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a-70-27"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; pickles_backend
      ; pickles_base
      ; pickles_limb_vector
      ; pickles_types
      ; sexplib0
      ; Layer_base.mina_wire_types
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ] )

let pickles_plonk_checks =
  library "pickles.plonk_checks" ~internal_name:"plonk_checks"
    ~path:"src/lib/crypto/pickles/plonk_checks"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a-4-70"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ base_internalhash_types
      ; core_kernel
      ; ocaml_migrate_parsetree
      ; pickles_base
      ; pickles_composition_types
      ; pickles_types
      ; ppxlib_ast
      ; sexplib0
      ; Layer_kimchi.kimchi_backend
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "kimchi_types"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~extra_stanzas:
      [ "rule"
        @: [ "target" @: [ atom "scalars.ml" ]
           ; "mode" @: [ atom "promote" ]
           ; "deps"
             @: [ list [ atom ":<"; atom "gen_scalars/gen_scalars.exe" ] ]
           ; "action"
             @: [ list
                    [ atom "progn"
                    ; list [ atom "run"; atom "%{<}"; atom "%{target}" ]
                    ; list
                        [ atom "run"
                        ; atom "ocamlformat"
                        ; atom "-i"
                        ; atom "scalars.ml"
                        ]
                    ]
                ]
           ]
      ]

let pickles =
  library "pickles" ~path:"src/lib/crypto/pickles" ~inline_tests:true
    ~modules_without_implementation:
      [ "full_signature"; "type"; "intf"; "pickles_intf" ]
    ~flags:[ atom "-open"; atom "Core_kernel" ]
    ~deps:
      [ async_kernel
      ; base
      ; base64
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; digestif
      ; integers
      ; pickles_backend
      ; pickles_base
      ; pickles_base_one_hot_vector
      ; pickles_composition_types
      ; pickles_limb_vector
      ; pickles_plonk_checks
      ; pickles_pseudo
      ; pickles_types
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; stdio
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.error_json
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_concurrency.promise
      ; Layer_crypto.bignum_bigint
      ; Layer_crypto.random_oracle_input
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_kimchi.kimchi_pasta_constraint_system
      ; Layer_kimchi.plonkish_prelude
      ; Layer_logging.logger
      ; Layer_logging.logger_context_logger
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snark_keys_header
      ; Layer_snarky.snarky_group_map
      ; Layer_snarky.snarky_log
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.group_map
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.snarky_curve
      ; Snarky_lib.snarky_intf
      ; Snarky_lib.sponge
      ; Snarky_lib.tuple_lib
      ; local "key_cache"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_snarky_backend"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ] )

let proof_cache_tag =
  library "proof_cache_tag" ~path:"src/lib/proof_cache_tag"
    ~deps:
      [ async_kernel
      ; core_kernel
      ; pickles
      ; local "disk_cache"
      ; local "logger"
      ]
    ~ppx:Ppx.standard
