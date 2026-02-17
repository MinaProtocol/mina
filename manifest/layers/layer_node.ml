(** Mina node layer: node configuration and runtime settings.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let mina_node_config_intf =
  library "mina_node_config.intf" ~internal_name:"node_config_intf"
    ~path:"src/lib/node_config/intf"
    ~modules_without_implementation:[ "node_config_intf" ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_base ])

let mina_node_config =
  library "mina_node_config" ~internal_name:"node_config"
    ~path:"src/lib/node_config"
    ~deps:
      [ local "node_config_intf"
      ; local "node_config_profiled"
      ; local "node_config_unconfigurable_constants"
      ; local "node_config_version"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_base ])

let mina_node_config_for_unit_tests =
  library "mina_node_config.for_unit_tests"
    ~internal_name:"node_config_for_unit_tests"
    ~path:"src/lib/node_config/for_unit_tests"
    ~deps:
      [ local "node_config_intf"
      ; local "node_config_unconfigurable_constants"
      ; local "node_config_version"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_base ])

let mina_node_config_profiled =
  library "mina_node_config.profiled" ~internal_name:"node_config_profiled"
    ~path:"src/lib/node_config/profiled"
    ~deps:[ core_kernel; local "comptime"; local "node_config_intf" ]
    ~ppx:Ppx.minimal

let mina_node_config_unconfigurable_constants =
  library "mina_node_config.unconfigurable_constants"
    ~internal_name:"node_config_unconfigurable_constants"
    ~path:"src/lib/node_config/unconfigurable_constants"
    ~deps:[ local "node_config_intf" ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_base ])

let mina_node_config_version =
  library "mina_node_config.version" ~internal_name:"node_config_version"
    ~path:"src/lib/node_config/version"
    ~deps:[ local "node_config_intf" ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_base ])

let mina_compile_config =
  library "mina_compile_config" ~path:"src/lib/mina_compile_config"
    ~deps:
      [ core_kernel
      ; mina_node_config
      ; mina_node_config_for_unit_tests
      ; local "currency"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_base; Ppx_lib.ppx_deriving_yojson ] )

let mina_numbers =
  library "mina_numbers" ~path:"src/lib/mina_numbers"
    ~synopsis:"Snark-friendly numbers used in Coda consensus"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ base
      ; base_caml
      ; base_internalhash_types
      ; bignum_bigint
      ; bin_prot_shape
      ; core_kernel
      ; integers
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; Layer_base.codable
      ; Layer_base.mina_wire_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snark_bits
      ; Layer_test.test_util
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "bignum_bigint"
      ; local "kimchi_backend_common"
      ; local "pickles"
      ; local "protocol_version"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "snark_params"
      ; local "unsigned_extended"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
