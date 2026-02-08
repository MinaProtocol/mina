(** Mina cryptographic layer: hashing, signatures, and general crypto utilities.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let blake2 =
  library "blake2" ~path:"src/lib/crypto/blake2" ~inline_tests:true
    ~deps:
      [ base_caml
      ; base_internalhash_types
      ; bigarray_compat
      ; bin_prot_shape
      ; core_kernel
      ; digestif
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let bignum_bigint =
  library "bignum_bigint" ~path:"src/lib/crypto/bignum_bigint"
    ~synopsis:"Bignum's bigint re-exported as Bignum_bigint"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:[ async_kernel; bignum_bigint; core_kernel; Snarky_lib.fold_lib ]
    ~ppx:Ppx.standard

let string_sign =
  library "string_sign" ~path:"src/lib/crypto/string_sign"
    ~synopsis:"Schnorr signatures for strings"
    ~deps:
      [ core_kernel
      ; result
      ; Layer_base.mina_base
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta_basic"
      ; local "mina_signature_kind"
      ; local "pickles"
      ; local "pickles_backend"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:Ppx.mina

let random_oracle_input =
  library "random_oracle_input" ~path:"src/lib/crypto/random_oracle_input"
    ~inline_tests:true
    ~deps:[ base_caml; core_kernel; ppx_inline_test_config; sexplib0 ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let outside_hash_image =
  library "outside_hash_image" ~path:"src/lib/crypto/outside_hash_image"
    ~deps:[ local "snark_params" ]
    ~ppx:Ppx.minimal

let hash_prefixes =
  library "hash_prefixes" ~path:"src/lib/hash_prefixes"
    ~deps:[ local "mina_signature_kind" ]
    ~ppx:Ppx.minimal

let sgn =
  library "sgn" ~path:"src/lib/sgn" ~synopsis:"sgn library"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; sexplib0
      ; yojson
      ; Layer_base.sgn_type
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
      ; local "pickles"
      ; local "snark_params"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let crypto_params =
  library "crypto_params" ~path:"src/lib/crypto/crypto_params"
    ~synopsis:"Cryptographic parameters"
    ~flags:
      [ atom ":standard"; atom "-short-paths"; atom "-warn-error"; atom "-58" ]
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ bin_prot_shape
      ; core_kernel
      ; sexplib0
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Snarky_lib.group_map
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "cache_dir"
      ; local "pickles"
      ; local "pickles_backend"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.h_list_ppx; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
    ~extra_stanzas:
      [ "rule"
        @: [ "targets" @: [ atom "group_map_params.ml" ]
           ; "deps" @: [ list [ atom ":<"; atom "gen/gen.exe" ] ]
           ; "action" @: [ list [ atom "run"; atom "%{<}"; atom "%{targets}" ] ]
           ]
      ]

let snark_params =
  library "snark_params" ~path:"src/lib/crypto/snark_params"
    ~synopsis:"Snark parameters" ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; base_internalhash_types
      ; bignum_bigint
      ; core_kernel
      ; crypto_params
      ; digestif
      ; sexplib0
      ; Layer_base.mina_wire_types
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_snarky.snark_bits
      ; Layer_snarky.snarky_curves
      ; Layer_snarky.snarky_field_extensions
      ; Layer_snarky.snarky_group_map
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.group_map
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.snarky_intf
      ; Snarky_lib.sponge
      ; local "pickles"
      ; local "pickles_backend"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_snarky
         ] )

let random_oracle =
  library "random_oracle" ~path:"src/lib/crypto/random_oracle"
    ~inline_tests:true
    ~deps:
      [ base
      ; core_kernel
      ; ppx_inline_test_config
      ; random_oracle_input
      ; sexplib0
      ; snark_params
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.sponge
      ; local "pickles"
      ; local "pickles_backend"
      ; local "random_oracle_permutation"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ] )

let random_oracle_permutation =
  library "random_oracle.permutation" ~internal_name:"random_oracle_permutation"
    ~path:"src/lib/crypto/random_oracle/permutation"
    ~deps:
      [ Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Snarky_lib.sponge
      ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "random_oracle_permutation" ]
    ~default_implementation:"random_oracle.permutation.external"

let random_oracle_permutation_external =
  library "random_oracle.permutation.external"
    ~internal_name:"random_oracle_permutation_external"
    ~path:"src/lib/crypto/random_oracle/permutation/external" ~inline_tests:true
    ~deps:
      [ base
      ; core_kernel
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_bindings_pasta_fp_poseidon
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Snarky_lib.sponge
      ; local "kimchi_bindings"
      ; local "pickles"
      ; local "pickles_backend"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_inline_test; Ppx_lib.ppx_assert ] )
    ~implements:"random_oracle.permutation"

let random_oracle_permutation_ocaml =
  library "random_oracle.permutation.ocaml"
    ~internal_name:"random_oracle_permutation_ocaml"
    ~path:"src/lib/crypto/random_oracle/permutation/ocaml"
    ~deps:
      [ base
      ; core_kernel
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Snarky_lib.sponge
      ; local "pickles"
      ; local "pickles_backend"
      ]
    ~ppx:Ppx.minimal ~implements:"random_oracle.permutation"

let non_zero_curve_point =
  library "non_zero_curve_point" ~path:"src/lib/crypto/non_zero_curve_point"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; ppx_inline_test_config
      ; random_oracle
      ; random_oracle_input
      ; sexplib0
      ; snark_params
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.mina_wire_types
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ppx.ppx_version_runtime
      ; Layer_test.test_util
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; local "pickles"
      ; local "pickles_backend"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_custom_printf
         ] )

let signature_lib =
  library "signature_lib" ~path:"src/lib/crypto/signature_lib"
    ~synopsis:"Schnorr signatures using the tick and tock curves"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ base
      ; base_caml
      ; bignum_bigint
      ; bignum_bigint
      ; bin_prot_shape
      ; blake2
      ; core_kernel
      ; crypto_params
      ; non_zero_curve_point
      ; ppx_inline_test_config
      ; random_oracle
      ; random_oracle_input
      ; result
      ; sexplib0
      ; snark_params
      ; yojson
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.mina_wire_types
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snarky_curves
      ; Layer_test.test_util
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.h_list
      ; Snarky_lib.snarky_backendless
      ; local "hash_prefix_states"
      ; local "mina_debug"
      ; local "pickles"
      ; local "pickles_backend"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ] )

let secrets =
  library "secrets" ~path:"src/lib/crypto/secrets"
    ~synopsis:"Managing secrets including passwords and keypairs"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base58
      ; base_caml
      ; bignum_bigint
      ; core
      ; core_kernel
      ; ppx_deriving_yojson_runtime
      ; ppx_inline_test_config
      ; random_oracle
      ; result
      ; sexplib0
      ; signature_lib
      ; snark_params
      ; sodium
      ; yojson
      ; Layer_base.base58_check
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_logging.logger
      ; Snarky_lib.snarky_backendless
      ; local "mina_net2"
      ; local "network_peer"
      ; local "pickles"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_make
         ] )

let key_gen =
  library "key_gen" ~path:"src/lib/crypto/key_gen"
    ~deps:[ core_kernel; signature_lib ]
    ~ppx:Ppx.minimal

let bowe_gabizon_hash =
  library "bowe_gabizon_hash" ~path:"src/lib/crypto/bowe_gabizon_hash"
    ~inline_tests:true ~deps:[ core_kernel ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )
