load("@bazel_tools//tools/build_defs/repo:git.bzl",
     "git_repository", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

all_content = """filegroup(name = "all", srcs = glob(["**"]), visibility = ["//visibility:public"])"""

def _cc_rules():
    ## Bazel is migrating to this lib instead of builtin rules_cc.
    ## Use the http_archive rule once it is released.
    maybe(
        git_repository,
        name = "rules_cc",
        remote = "https://github.com/bazelbuild/rules_cc",
        branch = "master"
    )

    # maybe(
    #     http_archive,
    #     name = "rules_cc",
    #     urls = ["https://github.com/bazelbuild/rules_cc/archive/TODO"],
    #     # sha256 = "TODO",
    # )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        strip_prefix="rules_foreign_cc-master",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/master.zip",
        # sha256 = "3fc764c7084da14cff812ae42327d19c8d6e99379f8b3e310b3213e1d5f0e7e8"
    )

def _cc_repos():

    maybe(
        http_archive,
        name = "bzip2",
        url = "https://www.sourceware.org/pub/bzip2/bzip2-latest.tar.gz",
        type = "gz",
        # sha256 = "461eee78a32a51b639ef82ca192b98c64a6a4d7f4be0642f3fc5a23992138fd5",
        strip_prefix = "bzip2-1.0.8",
        build_file_content = all_content
    )


    maybe(
        http_archive,
        name = "jemalloc",
        url = "https://github.com/jemalloc/jemalloc/archive/5.2.1.zip",
        type = "zip",
        sha256 = "461eee78a32a51b639ef82ca192b98c64a6a4d7f4be0642f3fc5a23992138fd5",
        strip_prefix = "jemalloc-5.2.1",
        build_file_content = all_content
        # build_file = "@//bzl/external:jemalloc.BUILD",
    )

    maybe(
        new_git_repository,
        name = "rocksdb",
        remote = "https://github.com/facebook/rocksdb",
        tag= "v5.17.2",
        workspace_file_content = "workspace( name = \"rocksdb\" )",
        build_file_content = all_content,
        verbose = True
    )

    maybe(
        http_archive,
        name = "zlib",
        url = "https://zlib.net/zlib-1.2.11.tar.gz",
        sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
        strip_prefix = "zlib-1.2.11",
        build_file_content = all_content,
    )

    ################################################################
    ################ Legacy C++ libs for @snarky ###################

    ######## Non-bazel external repos ########
    ## Abseil - gtest dep; without this queries with fail with "no such package: @com_google_absl..."
    # maybe(
    #     http_archive,
    #     name = "com_google_absl",
    #     urls = ["https://github.com/abseil/abseil-cpp/archive/master.zip"],
    #     strip_prefix = "abseil-cpp-master",
    # )

    # maybe(
    #     http_archive,
    #     name="gtest",
    #     url="https://github.com/google/googletest/archive/release-1.10.0.tar.gz",
    #     sha256="9dc9157a9a1551ec7a7e43daea9a694a0bb5fb8bec81235d8a1e6ef64c716dcb",
    #     strip_prefix = "googletest-release-1.10.0",
    # )

    ## we need the patch command, but we don't really need to build this?
    # http_archive(
    #     name="libgpatch",
    #     url="https://ftp.gnu.org/gnu/patch/patch-2.7.tar.bz2",
    #     sha256="9077cd75a915330513796e222049c2b6da69299729795e08c02e507bff60d6ee",
    #     strip_prefix = "patch-2.7",
    #     build_file_content = all_content,
    #     # build_file = "@//bzl/external:gpatch.BUILD"
    # )

    maybe(
        http_archive,
        name = "libffi",
        url = "https://github.com/libffi/libffi/releases/download/v3.3/libffi-3.3.tar.gz",
        sha256 = "72fba7922703ddfa7a028d513ac15a85c8d54c8d67f55fa5a4802885dc652056",
        strip_prefix = "libffi-3.3",
        build_file = "@//bzl/external:libffi.BUILD",
        ## the zip version requires use of autogen
        #url = "https://github.com/libffi/libffi/archive/v3.3.zip",
        # type = "zip",
        # sha256 = "60b64c656520f986ec7bd2a6dc61e800848c97872f8f5132c5f753d9c205c358",
    )


    ## OpenMP: use libgomp for linux?
    ## build target: //bzl/external/openmp alias for @libff//bzl/external/openmp
    # maybe(
    #     http_archive,
    #     name="openmp",
    #     url="https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/openmp-10.0.0.src.tar.xz",
    #     sha256="3b9ff29a45d0509a1e9667a0feb43538ef402ea8cfc7df3758a01f20df08adfa",
    #     strip_prefix="openmp-10.0.0.src",
    #     build_file_content = all_content
    # )

    # ## build target: //bzl/external/openssl alias for @libff/bzl/external/openssl
    # maybe(
    #     http_archive,
    #     name="openssl",
    #     url="https://www.openssl.org/source/openssl-1.1.1g.tar.gz",
    #     sha256="ddb04774f1e32f0c49751e21b67216ac87852ceb056b75209af2443400636d46",
    #     strip_prefix="openssl-1.1.1g",
    #     build_file_content = all_content
    # )

    # ## build target: //bzl/external/libsodium alias for @libff//bzl/external/libsodium
    # maybe(
    #     http_archive,
    #     name="libsodium",
    #     type="zip",
    #     url="https://github.com/jedisct1/libsodium/archive/1.0.18-RELEASE.zip",
    #     sha256="7728976ead51b0de60bede2421cd2a455c2bff3f1bc0320a1d61e240e693bce9",
    #     strip_prefix = "libsodium-1.0.18-RELEASE",
    #     build_file_content = all_content,
    # )

    # ## build target: //bzl/external/libgmp alias for @ate_pairing//bzl/external/libgmp
    # maybe(
    #     http_archive,
    #     name="libgmp",
    #     url="https://gmplib.org/download/gmp/gmp-6.2.0.tar.xz",
    #     sha256="258e6cd51b3fbdfc185c716d55f82c08aff57df0c6fbd143cf6ed561267a1526",
    #     strip_prefix = "gmp-6.2.0",
    #     build_file_content = all_content
    # )

    # maybe(
    #     http_archive,
    #     name = "postgresql",
    #     type = "bz2",
    #     # url from homebrew recipe
    #     url = "https://ftp.postgresql.org/pub/source/v12.2/postgresql-12.2.tar.bz2",
    #     sha256 = "ad1dcc4c4fc500786b745635a9e1eba950195ce20b8913f50345bb7d5369b5de",
    #     strip_prefix = "postgresql-12.2",
    #     build_file_content = all_content,
    # )

    # ## boost needed by: libsnark, @xbyak//sample:calc
    # maybe(
    #     git_repository,
    #     name = "com_github_nelhage_rules_boost",
    #     commit = "9f9fb8b2f0213989247c9d5c0e814a8451d18d7f",
    #     remote = "https://github.com/nelhage/rules_boost",
    #     shallow_since = "1570056263 -0700",
    # )
    # load("@com_github_nelhage_rules_boost//:boost/boost.bzl", "boost_deps")
    # boost_deps()


    # boost::locale needs iconv on mac os?
    # or, use libicu?
    # http_archive(
    #     name="libiconv",
    #     url="https://ftp.gnu.org/gnu/libiconv/libiconv-1.16.tar.gz",
    #     sha256="e6a1b1b589654277ee790cce3734f07876ac4ccfaecbee8afa0b649cf529cc04",
    #     strip_prefix = "libiconv-1.16",
    #     build_file_content = all_content
    # )

    # maybe(
    #     http_archive,
    #     name = "libomp",
    #     url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/openmp-10.0.0.src.tar.xz",
    #     sha256 = "3b9ff29a45d0509a1e9667a0feb43538ef402ea8cfc7df3758a01f20df08adfa",
    #     strip_prefix = "openmp-10.0.0.src",
    #     build_file_content = all_content,
    # )

    # # libsnark-caml:
    # maybe(
    #     new_git_repository,
    #     name = "libsnark-supercop",
    #     commit = "b04a0ea2c7d7422d74a512ce848e762196f48149",
    #     remote = "https://github.com/mbbarbosa/libsnark-supercop",
    #     shallow_since = "1433349878 +0100",
    #     build_file = "@libsnark//bzl/external/libsnark-supercop:BUILD.bazel"
    # )

    # maybe(
    #     # not used by snarky; build:  @libff//bzl/external/procps
    #     new_git_repository,
    #     name = "procps",
    #     commit = "4090fa711be367a35e689a34c9ba751ad90f6f0d",
    #     remote = "https://github.com/obazl/procps.git",
    #     shallow_since = "1588067259 +1000",
    #     build_file_content = all_content,
    # )

    #########################################
    #### Bazelized Snarky external repos ####

    ## Currently these are embedded in src/camlsnark_c/libsnark_caml,
    ## and loaded using local_repository rules in root WORKSPACE.bazel.

    # maybe(
    #     http_archive,
    #     name = "libsnark",
    #     urls = ["https://github.com/o1-labs/libsnark/archive/bzl-1.0.tar.gz"],
    #     strip_prefix = "libsnark-bzl-1.0",
    #     # sha256 = ...
    # )

    # http_archive(
    #     name = "libfqfft",
    #     urls = ["https://github.com/o1-labs/libfqfft/archive/bzl-1.0.tar.gz"],
    #     strip_prefix = "libfqfft-bzl-1.0",
    #     sha256 = ...
    # )

    # http_archive(
    #     name = "libff",
    #     urls = ["https://github.com/o1-labs/libff/archive/bzl-1.0.tar.gz"],
    #     strip_prefix = "libff-bzl-1.0",
    #     sha256 = ...
    # )

    # Used only for bn128, in libff/algebra/curves/bn128/BUILD.bazel, target: @ate_pairing//libzm
    # http_archive(
    #     name = "ate_pairing",
    #     urls = ["https://github.com/o1-labs/ate-pairing/archive/bzl-1.0.tar.gz"],
    #     strip_prefix = "ate-pairing-bzl-1.0",
    #     sha256 = ...
    #     # commit: 8d34a92e92b0c661291dfc177f9e2b61c78597c4
    # )

    # http_archive(
    #     name = "xbyak",
    #     urls = ["https://github.com/o1-labs/xbyak/archive/bzl-1.0.tar.gz"],
    #     strip_prefix = "xbyak-bzl-1.0",
    #     # sha256 = ...
    # )

    # maybe(
    #     new_git_repository,
    #     name = "libprocps",
    #     # commit = "",
    #     remote = "https://gitlab.com/procps-ng/procps.git",
    #     # procps-v3.3.16.tar
    #     branch = "master",
    #     init_submodules = True,
    #     # shallow_since = "1570056263 -0700",
    #     build_file_content = all_content,
    #     verbose = True,
    # )

    # maybe(
    #     http_archive,
    #     name = "libre2",
    #     url = "https://github.com/google/re2/archive/2020-05-01.tar.gz",
    #     sha256 = "88864d7f5126bb17daa1aa8f41b05599aa6e3222e7b28a90e372db53c1c49aeb",
    #     strip_prefix = "re2-2020-05-01",
    # )

    ############################################
    ################    CUDA    ################
    # http_archive(
    #     name="cuda_fixnum",
    #     url="https://github.com/unzvfu/cuda-fixnum/archive/v0.2.1.tar.gz",
    #     sha256="08fe417a91261de8cbe5b631c9b257de003df787fa39fec44537aece710cedce",
    #     strip_prefix = "cuda-fixnum-0.2.1",
    #     build_file_content = all_content
    #     # build_file = "@//:foo.BUILD"
    # )

def cc_bootstrap():
    """This bootstraps (loads) C/C++ rules and repos."""
    _cc_rules()
    _cc_repos()
