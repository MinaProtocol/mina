(** Mina cryptographic layer: hashing, signatures, and general crypto utilities.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let blake2 =
  library "blake2" ~path:"src/lib/crypto/blake2" ~inline_tests:true
    ~deps:
      [ base_internalhash_types
      ; base_caml
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
    ~deps:[ core_kernel; async_kernel; bignum_bigint; Snarky_lib.fold_lib ]
    ~ppx:Ppx.standard

let string_sign =
  library "string_sign" ~path:"src/lib/crypto/string_sign"
    ~synopsis:"Schnorr signatures for strings"
    ~deps:
      [ core_kernel
      ; result
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta_basic"
      ; Layer_base.mina_base
      ; local "mina_signature_kind"
      ; local "pickles"
      ; local "pickles_backend"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:Ppx.mina

let snark_keys_header =
  library "snark_keys_header" ~path:"src/lib/crypto/snark_keys_header"
    ~deps:[ base; base_caml; core_kernel; integers; result; sexplib0; stdio ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_ord
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )

let random_oracle_input =
  library "random_oracle_input" ~path:"src/lib/crypto/random_oracle_input"
    ~inline_tests:true
    ~deps:[ core_kernel; sexplib0; base_caml; ppx_inline_test_config ]
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
      [ ppx_deriving_yojson_runtime
      ; core_kernel
      ; yojson
      ; sexplib0
      ; base
      ; bin_prot_shape
      ; base_caml
      ; local "snark_params"
      ; Layer_base.sgn_type
      ; local "pickles"
      ; Snarky_lib.snarky_backendless
      ; Layer_ppx.ppx_version_runtime
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
      ; local "cache_dir"
      ; Snarky_lib.group_map
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; local "pickles"
      ; local "pickles_backend"
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
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
      [ base_internalhash_types
      ; core_kernel
      ; digestif
      ; base
      ; sexplib0
      ; Layer_base.mina_wire_types
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; bignum_bigint
      ; local "pickles_backend"
      ; local "snarky_curves"
      ; Snarky_lib.snarky_backendless
      ; local "snarky_group_map"
      ; Snarky_lib.sponge
      ; Snarky_lib.group_map
      ; Snarky_lib.fold_lib
      ; Snarky_lib.bitstring_lib
      ; Layer_snarky.snark_bits
      ; local "pickles"
      ; crypto_params
      ; local "snarky_field_extensions"
      ; Snarky_lib.snarky_intf
      ; Layer_kimchi.kimchi_backend
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
      [ ppx_inline_test_config
      ; base
      ; core_kernel
      ; sexplib0
      ; snark_params
      ; local "pickles_backend"
      ; Snarky_lib.sponge
      ; local "pickles"
      ; random_oracle_input
      ; Snarky_lib.snarky_backendless
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Snarky_lib.fold_lib
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
      [ Snarky_lib.sponge
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "random_oracle_permutation" ]
    ~default_implementation:"random_oracle.permutation.external"

let random_oracle_permutation_external =
  library "random_oracle.permutation.external"
    ~internal_name:"random_oracle_permutation_external"
    ~path:"src/lib/crypto/random_oracle/permutation/external" ~inline_tests:true
    ~deps:
      [ ppx_inline_test_config
      ; base
      ; core_kernel
      ; sexplib0
      ; Snarky_lib.sponge
      ; local "pickles"
      ; local "pickles_backend"
      ; Layer_kimchi.kimchi_bindings_pasta_fp_poseidon
      ; local "kimchi_bindings"
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
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
      ; Snarky_lib.sponge
      ; local "pickles"
      ; local "pickles_backend"
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ]
    ~ppx:Ppx.minimal ~implements:"random_oracle.permutation"

let non_zero_curve_point =
  library "non_zero_curve_point" ~path:"src/lib/crypto/non_zero_curve_point"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ ppx_inline_test_config
      ; base_caml
      ; sexplib0
      ; core_kernel
      ; bin_prot_shape
      ; base
      ; base_internalhash_types
      ; Layer_base.mina_wire_types
      ; Snarky_lib.snarky_backendless
      ; random_oracle_input
      ; local "pickles_backend"
      ; local "pickles"
      ; Layer_base.codable
      ; snark_params
      ; Snarky_lib.fold_lib
      ; Layer_base.base58_check
      ; random_oracle
      ; Snarky_lib.bitstring_lib
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_test.test_util
      ; Layer_ppx.ppx_version_runtime
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
      [ bignum_bigint
      ; ppx_inline_test_config
      ; base
      ; sexplib0
      ; yojson
      ; core_kernel
      ; bin_prot_shape
      ; base_caml
      ; result
      ; Layer_base.mina_wire_types
      ; crypto_params
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; random_oracle_input
      ; Snarky_lib.bitstring_lib
      ; Layer_base.codable
      ; snark_params
      ; local "mina_debug"
      ; blake2
      ; local "hash_prefix_states"
      ; non_zero_curve_point
      ; random_oracle
      ; Snarky_lib.snarky_backendless
      ; bignum_bigint
      ; Layer_base.base58_check
      ; local "snarky_curves"
      ; local "pickles"
      ; Snarky_lib.fold_lib
      ; local "pickles_backend"
      ; Layer_kimchi.kimchi_backend
      ; Snarky_lib.h_list
      ; Layer_test.test_util
      ; Layer_ppx.ppx_version_runtime
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
      [ result
      ; base_caml
      ; bignum_bigint
      ; async_kernel
      ; async
      ; core
      ; async_unix
      ; sodium
      ; ppx_deriving_yojson_runtime
      ; yojson
      ; core_kernel
      ; sexplib0
      ; base58
      ; ppx_inline_test_config
      ; Layer_base.mina_stdlib_unix
      ; random_oracle
      ; local "pickles"
      ; Layer_logging.logger
      ; snark_params
      ; Layer_base.mina_stdlib
      ; local "mina_net2"
      ; Layer_base.mina_base
      ; Layer_base.base58_check
      ; signature_lib
      ; local "network_peer"
      ; Layer_base.mina_numbers
      ; Snarky_lib.snarky_backendless
      ; Layer_base.error_json
      ; Layer_base.mina_base_import
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
