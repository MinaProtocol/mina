open Manifest

(* Core / Jane Street *)
let core_kernel = opam "core_kernel"

let core_kernel_hash_heap = opam "core_kernel.hash_heap"

let core_kernel_pairing_heap = opam "core_kernel.pairing_heap"

let core_kernel_uuid = opam "core_kernel.uuid"

let core = opam "core"

let core_bench = opam "core_bench"

let core_bench_inline_benchmarks = opam "core_bench.inline_benchmarks"

let core_daemon = opam "core.daemon"

let core_time_stamp_counter = opam "core.time_stamp_counter"

let core_uuid = opam "core.uuid"

let core_unix_command_unix = opam "core_unix.command_unix"

let base = opam "base"

let base_caml = opam "base.caml"

let base_internalhash_types = opam "base.base_internalhash_types"

let base_md5 = opam "base.md5"

let base_quickcheck = opam "base_quickcheck"

let base_quickcheck_ppx = opam "base_quickcheck.ppx_quickcheck"

let async = opam "async"

let async_kernel = opam "async_kernel"

let async_unix = opam "async_unix"

let async_rpc_kernel = opam "async_rpc_kernel"

let async_ssl = opam "async_ssl"

let async_command = opam "async.async_command"

let async_rpc = opam "async.async_rpc"

let sexplib0 = opam "sexplib0"

let sexplib = opam "sexplib"

let sexp_diff_kernel = opam "sexp_diff_kernel"

let bin_prot = opam "bin_prot"

let bin_prot_shape = opam "bin_prot.shape"

let fieldslib = opam "fieldslib"

let incremental = opam "incremental"

let splittable_random = opam "splittable_random"

let stdio = opam "stdio"

let bignum = opam "bignum"

let bignum_bigint = opam "bignum.bigint"

let rpc_parallel = opam "rpc_parallel"

(* PPX *)
let ppxlib = opam "ppxlib"

let ppxlib_ast = opam "ppxlib.ast"

let ppxlib_astlib = opam "ppxlib.astlib"

let ppx_bin_prot = opam "ppx_bin_prot"

let ppx_derivers = opam "ppx_derivers"

let ppx_deriving_api = opam "ppx_deriving.api"

let ppx_deriving_runtime = opam "ppx_deriving.runtime"

let ppx_deriving_yojson = opam "ppx_deriving_yojson"

let ppx_deriving_yojson_runtime = opam "ppx_deriving_yojson.runtime"

let ppx_hash_runtime_lib = opam "ppx_hash.runtime-lib"

let ppx_inline_test_config = opam "ppx_inline_test.config"

let ppx_inline_test_runner_lib = opam "ppx_inline_test.runner.lib"

let ppx_version_runtime = opam "ppx_version.runtime"

let ocaml_migrate_parsetree = opam "ocaml-migrate-parsetree"

let ocaml_compiler_libs_common = opam "ocaml-compiler-libs.common"

(* Data formats / parsing *)
let yojson = opam "yojson"

let angstrom = opam "angstrom"

let result = opam "result"

let base64 = opam "base64"

let base58 = opam "base58"

let hex = opam "hex"

let bitstring = opam "bitstring"

let re = opam "re"

let re2 = opam "re2"

let astring = opam "astring"

let fmt = opam "fmt"

let ptime = opam "ptime"

let cmdliner = opam "cmdliner"

let lens = opam "lens"

(* Web / GraphQL *)
let cohttp = opam "cohttp"

let cohttp_async = opam "cohttp-async"

let graphql = opam "graphql"

let graphql_async = opam "graphql-async"

let graphql_cohttp = opam "graphql-cohttp"

let graphql_parser = opam "graphql_parser"

let uri = opam "uri"

let conduit_async = opam "conduit-async"

(* Database *)
let caqti = opam "caqti"

let caqti_async = opam "caqti-async"

let caqti_driver_postgresql = opam "caqti-driver-postgresql"

let rocks = opam "rocks"

let lmdb = opam "lmdb"

(* Crypto *)
let blake2 = opam "blake2"

let digestif = opam "digestif"

let sodium = opam "sodium"

let mirage_crypto_ec = opam "mirage-crypto-ec"

(* Math *)
let zarith = opam "zarith"

let zarith_stubs_js = opam "zarith_stubs_js"

(* Kimchi / proof-systems bindings *)
let kimchi_bindings = opam "kimchi_bindings"

let kimchi_types = opam "kimchi_types"

let pasta_bindings = opam "pasta_bindings"

(* C / FFI *)
let ctypes = opam "ctypes"

let ctypes_foreign = opam "ctypes.foreign"

let integers = opam "integers"

let stdint = opam "stdint"

let bigarray_compat = opam "bigarray-compat"

(* Testing *)
let alcotest = opam "alcotest"

let alcotest_async = opam "alcotest-async"

(* Networking *)
let capnp = opam "capnp"

let libp2p_ipc = opam "libp2p_ipc"

(* Monitoring / profiling *)
let prometheus = opam "prometheus"

let memtrace = opam "memtrace"

(* Graph *)
let ocamlgraph = opam "ocamlgraph"

(* OCaml stdlib / system *)
let stdlib = opam "stdlib"

let unix = opam "unix"

let dynlink = opam "dynlink"

let threads_posix = opam "threads.posix"

let compiler_libs = opam "compiler-libs"

let compiler_libs_common = opam "compiler-libs.common"

let js_of_ocaml = opam "js_of_ocaml"

let init = opam "init"

let lib = opam "lib"

(* Mina packages referenced as opam *)
let archive_cli = opam "archive_cli"

let archive_lib = opam "archive_lib"

let cli_lib = opam "cli_lib"

let logger = opam "logger"

let mina_metrics = opam "mina_metrics"

let mina_stdlib = opam "mina_stdlib"

let unsigned_extended = opam "unsigned_extended"

let zkapp_test_transaction_lib = opam "zkapp_test_transaction_lib"

(* Snarky submodule libraries (src/lib/snarky/).
   These have their own dune-project and are not generated
   by the manifest. *)
module Snarky_lib = struct
  let snarky = submodule "snarky"

  let snarky_backendless = submodule "snarky.backendless"

  let snarky_intf = submodule "snarky.intf"

  let snarky_integer = submodule "snarky_integer"

  let snarky_curve = submodule "snarky_curve"

  let fold_lib = submodule "fold_lib"

  let tuple_lib = submodule "tuple_lib"

  let bitstring_lib = submodule "bitstring_lib"

  let sponge = submodule "sponge"

  let snarkette = submodule "snarkette"

  let group_map = submodule "group_map"

  let h_list = submodule "h_list"
end

(* PPX preprocessor libraries (string constants for Ppx.custom/extend). *)
module Ppx_lib = struct
  let base_quickcheck_ppx_quickcheck = "base_quickcheck.ppx_quickcheck"

  let graphql_ppx = "graphql_ppx"

  let h_list_ppx = "h_list.ppx"

  let js_of_ocaml_ppx = "js_of_ocaml-ppx"

  let lens_ppx_deriving = "lens.ppx_deriving"

  let ppx_annot = "ppx_annot"

  let ppx_assert = "ppx_assert"

  let ppx_base = "ppx_base"

  let ppx_bench = "ppx_bench"

  let ppx_bin_prot = "ppx_bin_prot"

  let ppx_bitstring = "ppx_bitstring"

  let ppx_compare = "ppx_compare"

  let ppx_custom_printf = "ppx_custom_printf"

  let ppx_deriving_enum = "ppx_deriving.enum"

  let ppx_deriving_eq = "ppx_deriving.eq"

  let ppx_deriving_make = "ppx_deriving.make"

  let ppx_deriving_ord = "ppx_deriving.ord"

  let ppx_deriving_show = "ppx_deriving.show"

  let ppx_deriving_std = "ppx_deriving.std"

  let ppx_deriving_yojson = "ppx_deriving_yojson"

  let ppx_enumerate = "ppx_enumerate"

  let ppx_fields_conv = "ppx_fields_conv"

  let ppx_fixed_literal = "ppx_fixed_literal"

  let ppx_hash = "ppx_hash"

  let ppx_here = "ppx_here"

  let ppx_inline_test = "ppx_inline_test"

  let ppx_jane = "ppx_jane"

  let ppx_let = "ppx_let"

  let ppx_mina = "ppx_mina"

  let ppx_module_timer = "ppx_module_timer"

  let ppx_optional = "ppx_optional"

  let ppx_pipebang = "ppx_pipebang"

  let ppx_register_event = "ppx_register_event"

  let ppx_sexp_conv = "ppx_sexp_conv"

  let ppx_sexp_message = "ppx_sexp_message"

  let ppx_sexp_value = "ppx_sexp_value"

  let ppx_snarky = "ppx_snarky"

  let ppx_string = "ppx_string"

  let ppx_typerep_conv = "ppx_typerep_conv"

  let ppx_variants_conv = "ppx_variants_conv"

  let ppx_version = "ppx_version"

  let ppxlib_metaquot = "ppxlib.metaquot"
end
