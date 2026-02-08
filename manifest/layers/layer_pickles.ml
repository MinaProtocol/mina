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
      [ sexplib0
      ; result
      ; core_kernel
      ; base_caml
      ; bin_prot_shape
      ; local "kimchi_types"
      ; Layer_kimchi.kimchi_backend_common
      ; local "kimchi_pasta_snarky_backend"
      ; Layer_kimchi.plonkish_prelude
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
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
    ~deps:[ core_kernel; local "snarky.backendless"; pickles_types ]
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
      [ base_internalhash_types
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; ppxlib
      ; core_kernel
      ; Layer_base.mina_wire_types
      ; local "snarky.backendless"
      ; Layer_crypto.random_oracle_input
      ; pickles_types
      ; pickles_base_one_hot_vector
      ; Layer_kimchi.plonkish_prelude
      ; Layer_ppx.ppx_version_runtime
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
      [ bin_prot_shape
      ; sexplib0
      ; core_kernel
      ; base_caml
      ; result
      ; local "snarky.backendless"
      ; pickles_backend
      ; pickles_types
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ppx.ppx_version_runtime
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
      ; pickles_types
      ; local "pickles_plonk_checks"
      ; pickles_base_one_hot_vector
      ; local "snarky.backendless"
      ; pickles_base
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
      [ sexplib0
      ; bin_prot_shape
      ; core_kernel
      ; base_caml
      ; Layer_base.mina_wire_types
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; local "snarky.backendless"
      ; pickles_types
      ; pickles_limb_vector
      ; Layer_kimchi.kimchi_backend
      ; pickles_base
      ; pickles_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_ppx.ppx_version_runtime
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
      [ sexplib0
      ; ppxlib_ast
      ; core_kernel
      ; ocaml_migrate_parsetree
      ; base_internalhash_types
      ; pickles_types
      ; pickles_base
      ; pickles_composition_types
      ; Layer_kimchi.kimchi_backend
      ; local "kimchi_types"
      ; local "snarky.backendless"
      ; local "tuple_lib"
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
      [ stdio
      ; integers
      ; result
      ; base_caml
      ; Layer_crypto.bignum_bigint
      ; core_kernel
      ; base64
      ; digestif
      ; ppx_inline_test_config
      ; sexplib0
      ; base
      ; async_kernel
      ; bin_prot_shape
      ; Layer_base.mina_wire_types
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_kimchi.kimchi_pasta_constraint_system
      ; local "kimchi_pasta_snarky_backend"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ; pickles_backend
      ; pickles_types
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; pickles_pseudo
      ; pickles_limb_vector
      ; pickles_base
      ; Layer_kimchi.plonkish_prelude
      ; Layer_kimchi.kimchi_backend
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_crypto.random_oracle_input
      ; pickles_composition_types
      ; pickles_plonk_checks
      ; pickles_base_one_hot_vector
      ; local "snarky_log"
      ; local "group_map"
      ; local "snarky_curve"
      ; local "key_cache"
      ; Layer_crypto.snark_keys_header
      ; local "tuple_lib"
      ; Layer_concurrency.promise
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_logging.logger
      ; Layer_logging.logger_context_logger
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.error_json
      ; Layer_base.mina_stdlib
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
      [ core_kernel; async_kernel; local "logger"; local "disk_cache"; pickles ]
    ~ppx:Ppx.standard
