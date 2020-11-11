"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def marlin_plonk_bindings_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "raze__alga__0_9_3",
        url = "https://crates.io/api/v1/crates/alga/0.9.3/download",
        type = "tar.gz",
        strip_prefix = "alga-0.9.3",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.alga-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__approx__0_3_2",
        url = "https://crates.io/api/v1/crates/approx/0.3.2/download",
        type = "tar.gz",
        strip_prefix = "approx-0.3.2",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.approx-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__autocfg__1_0_1",
        url = "https://crates.io/api/v1/crates/autocfg/1.0.1/download",
        type = "tar.gz",
        strip_prefix = "autocfg-1.0.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.autocfg-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__cfg_if__0_1_10",
        url = "https://crates.io/api/v1/crates/cfg-if/0.1.10/download",
        type = "tar.gz",
        strip_prefix = "cfg-if-0.1.10",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.cfg-if-0.1.10.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__const_fn__0_4_3",
        url = "https://crates.io/api/v1/crates/const_fn/0.4.3/download",
        type = "tar.gz",
        strip_prefix = "const_fn-0.4.3",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.const_fn-0.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__crossbeam_channel__0_5_0",
        url = "https://crates.io/api/v1/crates/crossbeam-channel/0.5.0/download",
        type = "tar.gz",
        strip_prefix = "crossbeam-channel-0.5.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.crossbeam-channel-0.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__crossbeam_deque__0_8_0",
        url = "https://crates.io/api/v1/crates/crossbeam-deque/0.8.0/download",
        type = "tar.gz",
        strip_prefix = "crossbeam-deque-0.8.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.crossbeam-deque-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__crossbeam_epoch__0_9_0",
        url = "https://crates.io/api/v1/crates/crossbeam-epoch/0.9.0/download",
        type = "tar.gz",
        strip_prefix = "crossbeam-epoch-0.9.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.crossbeam-epoch-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__crossbeam_utils__0_8_0",
        url = "https://crates.io/api/v1/crates/crossbeam-utils/0.8.0/download",
        type = "tar.gz",
        strip_prefix = "crossbeam-utils-0.8.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.crossbeam-utils-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__cty__0_2_1",
        url = "https://crates.io/api/v1/crates/cty/0.2.1/download",
        type = "tar.gz",
        strip_prefix = "cty-0.2.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.cty-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__either__1_6_1",
        url = "https://crates.io/api/v1/crates/either/1.6.1/download",
        type = "tar.gz",
        strip_prefix = "either-1.6.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.either-1.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__getrandom__0_1_15",
        url = "https://crates.io/api/v1/crates/getrandom/0.1.15/download",
        type = "tar.gz",
        strip_prefix = "getrandom-0.1.15",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.getrandom-0.1.15.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__hermit_abi__0_1_17",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.17/download",
        type = "tar.gz",
        strip_prefix = "hermit-abi-0.1.17",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.hermit-abi-0.1.17.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__libc__0_2_80",
        url = "https://crates.io/api/v1/crates/libc/0.2.80/download",
        type = "tar.gz",
        strip_prefix = "libc-0.2.80",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.libc-0.2.80.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__libm__0_2_1",
        url = "https://crates.io/api/v1/crates/libm/0.2.1/download",
        type = "tar.gz",
        strip_prefix = "libm-0.2.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.libm-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__matrixmultiply__0_2_3",
        url = "https://crates.io/api/v1/crates/matrixmultiply/0.2.3/download",
        type = "tar.gz",
        strip_prefix = "matrixmultiply-0.2.3",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.matrixmultiply-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__memoffset__0_5_6",
        url = "https://crates.io/api/v1/crates/memoffset/0.5.6/download",
        type = "tar.gz",
        strip_prefix = "memoffset-0.5.6",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.memoffset-0.5.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ndarray__0_13_1",
        url = "https://crates.io/api/v1/crates/ndarray/0.13.1/download",
        type = "tar.gz",
        strip_prefix = "ndarray-0.13.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.ndarray-0.13.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_bigint__0_2_6",
        url = "https://crates.io/api/v1/crates/num-bigint/0.2.6/download",
        type = "tar.gz",
        strip_prefix = "num-bigint-0.2.6",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.num-bigint-0.2.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_complex__0_2_4",
        url = "https://crates.io/api/v1/crates/num-complex/0.2.4/download",
        type = "tar.gz",
        strip_prefix = "num-complex-0.2.4",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.num-complex-0.2.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_integer__0_1_44",
        url = "https://crates.io/api/v1/crates/num-integer/0.1.44/download",
        type = "tar.gz",
        strip_prefix = "num-integer-0.1.44",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.num-integer-0.1.44.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_traits__0_1_43",
        url = "https://crates.io/api/v1/crates/num-traits/0.1.43/download",
        type = "tar.gz",
        strip_prefix = "num-traits-0.1.43",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.num-traits-0.1.43.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_traits__0_2_14",
        url = "https://crates.io/api/v1/crates/num-traits/0.2.14/download",
        type = "tar.gz",
        strip_prefix = "num-traits-0.2.14",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.num-traits-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_cpus__1_13_0",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.0/download",
        type = "tar.gz",
        strip_prefix = "num_cpus-1.13.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.num_cpus-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ocaml__0_18_1",
        url = "https://crates.io/api/v1/crates/ocaml/0.18.1/download",
        type = "tar.gz",
        strip_prefix = "ocaml-0.18.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.ocaml-0.18.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ocaml_derive__0_18_0",
        url = "https://crates.io/api/v1/crates/ocaml-derive/0.18.0/download",
        type = "tar.gz",
        strip_prefix = "ocaml-derive-0.18.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.ocaml-derive-0.18.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ocaml_sys__0_18_1",
        url = "https://crates.io/api/v1/crates/ocaml-sys/0.18.1/download",
        type = "tar.gz",
        strip_prefix = "ocaml-sys-0.18.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.ocaml-sys-0.18.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ppv_lite86__0_2_10",
        url = "https://crates.io/api/v1/crates/ppv-lite86/0.2.10/download",
        type = "tar.gz",
        strip_prefix = "ppv-lite86-0.2.10",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.ppv-lite86-0.2.10.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__proc_macro2__1_0_24",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.24/download",
        type = "tar.gz",
        strip_prefix = "proc-macro2-1.0.24",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.proc-macro2-1.0.24.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__quote__1_0_7",
        url = "https://crates.io/api/v1/crates/quote/1.0.7/download",
        type = "tar.gz",
        strip_prefix = "quote-1.0.7",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.quote-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rand__0_7_3",
        url = "https://crates.io/api/v1/crates/rand/0.7.3/download",
        type = "tar.gz",
        strip_prefix = "rand-0.7.3",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.rand-0.7.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rand_chacha__0_2_2",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.2.2/download",
        type = "tar.gz",
        strip_prefix = "rand_chacha-0.2.2",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.rand_chacha-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rand_core__0_5_1",
        url = "https://crates.io/api/v1/crates/rand_core/0.5.1/download",
        type = "tar.gz",
        strip_prefix = "rand_core-0.5.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.rand_core-0.5.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rand_hc__0_2_0",
        url = "https://crates.io/api/v1/crates/rand_hc/0.2.0/download",
        type = "tar.gz",
        strip_prefix = "rand_hc-0.2.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.rand_hc-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rawpointer__0_2_1",
        url = "https://crates.io/api/v1/crates/rawpointer/0.2.1/download",
        type = "tar.gz",
        strip_prefix = "rawpointer-0.2.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.rawpointer-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rayon__1_5_0",
        url = "https://crates.io/api/v1/crates/rayon/1.5.0/download",
        type = "tar.gz",
        strip_prefix = "rayon-1.5.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.rayon-1.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rayon_core__1_9_0",
        url = "https://crates.io/api/v1/crates/rayon-core/1.9.0/download",
        type = "tar.gz",
        strip_prefix = "rayon-core-1.9.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.rayon-core-1.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__sprs__0_7_1",
        url = "https://crates.io/api/v1/crates/sprs/0.7.1/download",
        type = "tar.gz",
        strip_prefix = "sprs-0.7.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.sprs-0.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__syn__1_0_48",
        url = "https://crates.io/api/v1/crates/syn/1.0.48/download",
        type = "tar.gz",
        strip_prefix = "syn-1.0.48",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.syn-1.0.48.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__synstructure__0_12_4",
        url = "https://crates.io/api/v1/crates/synstructure/0.12.4/download",
        type = "tar.gz",
        strip_prefix = "synstructure-0.12.4",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.synstructure-0.12.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__unicode_xid__0_2_1",
        url = "https://crates.io/api/v1/crates/unicode-xid/0.2.1/download",
        type = "tar.gz",
        strip_prefix = "unicode-xid-0.2.1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.unicode-xid-0.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__wasi__0_9_0_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.9.0+wasi-snapshot-preview1/download",
        type = "tar.gz",
        strip_prefix = "wasi-0.9.0+wasi-snapshot-preview1",
        build_file = Label("//src/lib/marlin_plonk_bindings/stubs/bzl/cargo/remote:BUILD.wasi-0.9.0+wasi-snapshot-preview1.bazel"),
    )
