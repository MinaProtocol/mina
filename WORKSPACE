load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")

################################################################
#### OCAML ####
git_repository(
    name = "obazl_rules_ocaml",
    remote = "https://github.com/obazl/rules_ocaml",
    branch = "master",
    # commit = "feef897197b36b14b65ffdf00b9badcbdb8f42f4",
    # shallow_since = "1593623637 -0500"
)


load("@obazl_rules_ocaml//ocaml:deps.bzl",
     "ocaml_configure_tooling",
     # "ocaml_repositories",
     # "ocaml_home_sdk",
     "ocaml_register_toolchains")

ocaml_configure_tooling()

ocaml_register_toolchains(installation="host")

################################################################
git_repository(
    name = "rules_foreign_cc",
    remote = "https://github.com/bazelbuild/rules_foreign_cc",
    commit = "74b146dc87d37baa1919da1e8f7b8aafbd32acd9",
    shallow_since = "1588931020 +0200"
    # strip_prefix = "rules_foreign_cc-master",
    # url = "https://github.com/bazelbuild/rules_foreign_cc/archive/master.zip",
    # sha256 = "55b7c4678b4014be103f0e93eb271858a43493ac7a193ec059289fbdc20b9023",
)

########################
####   PROTOBUF
########################
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "com_google_protobuf",
    commit = "09745575a923640154bcf307fba8aedff47f240a",
    remote = "https://github.com/protocolbuffers/protobuf",
    shallow_since = "1558721209 -0700",
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

http_archive(
    name = "rules_proto",
    sha256 = "602e7161d9195e50246177e7c55b2f39950a9cf7366f74ed5f22fd45750cd208",
    strip_prefix = "rules_proto-97d8af4dc474595af3900dd85cb3a29ad28cc313",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_proto/archive/97d8af4dc474595af3900dd85cb3a29ad28cc313.tar.gz",
        "https://github.com/bazelbuild/rules_proto/archive/97d8af4dc474595af3900dd85cb3a29ad28cc313.tar.gz",
    ],
)

load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

rules_proto_dependencies()

rules_proto_toolchains()

##################################################
########        C/C++ DEPENDENCIES        ########
##################################################
load("@rules_foreign_cc//:workspace_definitions.bzl", "rules_foreign_cc_dependencies")

rules_foreign_cc_dependencies()

# most libs can use this filegroup to define their build sources.
# if not, put a custom filegroup in a build_file
all_content = """filegroup(name = "all", srcs = glob(["**"]), visibility = ["//visibility:public"])"""

http_archive(
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

http_archive(
    name = "libgmp",
    url = "https://gmplib.org/download/gmp/gmp-6.2.0.tar.xz",
    sha256 = "258e6cd51b3fbdfc185c716d55f82c08aff57df0c6fbd143cf6ed561267a1526",
    strip_prefix = "gmp-6.2.0",
    build_file_content = all_content,
)

http_archive(
    name = "gtest",
    url = "https://github.com/google/googletest/archive/release-1.10.0.tar.gz",
    sha256 = "9dc9157a9a1551ec7a7e43daea9a694a0bb5fb8bec81235d8a1e6ef64c716dcb",
    strip_prefix = "googletest-release-1.10.0",
)

## we need the patch command, but we don't really need to build this?
# http_archive(
#     name="libgpatch",
#     url="https://ftp.gnu.org/gnu/patch/patch-2.7.tar.bz2",
#     sha256="9077cd75a915330513796e222049c2b6da69299729795e08c02e507bff60d6ee",
#     strip_prefix = "patch-2.7",
#     build_file_content = all_content,
#     # build_file = "@//bzl/external:gpatch.BUILD"
# )

new_git_repository(
    name = "libprocps",
    # commit = "",
    remote = "https://gitlab.com/procps-ng/procps.git",
    # procps-v3.3.16.tar
    branch = "master",
    init_submodules = True,
    # shallow_since = "1570056263 -0700",
    build_file_content = all_content,
    verbose = True,
)

http_archive(
    name = "libre2",
    url = "https://github.com/google/re2/archive/2020-05-01.tar.gz",
    sha256 = "88864d7f5126bb17daa1aa8f41b05599aa6e3222e7b28a90e372db53c1c49aeb",
    strip_prefix = "re2-2020-05-01",
)

http_archive(
    name = "libsodium",
    type = "zip",
    url = "https://github.com/jedisct1/libsodium/archive/1.0.18-RELEASE.zip",
    sha256 = "7728976ead51b0de60bede2421cd2a455c2bff3f1bc0320a1d61e240e693bce9",
    strip_prefix = "libsodium-1.0.18-RELEASE",
    build_file_content = all_content,
    # build_file="@//bzl/external:libsodium.BUILD"
)

http_archive(
    name = "jemalloc",
    url = "https://github.com/jemalloc/jemalloc/archive/5.2.1.zip",
    type = "zip",
    sha256 = "461eee78a32a51b639ef82ca192b98c64a6a4d7f4be0642f3fc5a23992138fd5",
    strip_prefix = "jemalloc-5.2.1",
    # build_file_content = all_content
    build_file = "@//bzl/external:jemalloc.BUILD",
)

# boost::locale needs iconv on mac os
# or, use libicu?
# http_archive(
#     name="libiconv",
#     url="https://ftp.gnu.org/gnu/libiconv/libiconv-1.16.tar.gz",
#     sha256="e6a1b1b589654277ee790cce3734f07876ac4ccfaecbee8afa0b649cf529cc04",
#     strip_prefix = "libiconv-1.16",
#     build_file_content = all_content
# )

################ BOOST
git_repository(
    name = "com_github_nelhage_rules_boost",
    commit = "9f9fb8b2f0213989247c9d5c0e814a8451d18d7f",
    remote = "https://github.com/nelhage/rules_boost",
    shallow_since = "1570056263 -0700",
)

load("@com_github_nelhage_rules_boost//:boost/boost.bzl", "boost_deps")

boost_deps()
################

http_archive(
    name = "libomp",
    url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/openmp-10.0.0.src.tar.xz",
    sha256 = "3b9ff29a45d0509a1e9667a0feb43538ef402ea8cfc7df3758a01f20df08adfa",
    strip_prefix = "openmp-10.0.0.src",
    build_file_content = all_content,
)

http_archive(
    name = "openssl",
    url = "https://www.openssl.org/source/openssl-1.1.1g.tar.gz",
    sha256 = "ddb04774f1e32f0c49751e21b67216ac87852ceb056b75209af2443400636d46",
    strip_prefix = "openssl-1.1.1g",
    build_file_content = all_content,
)

http_archive(
    name = "postgresql",
    type = "bz2",
    # url from homebrew recipe
    url = "https://ftp.postgresql.org/pub/source/v12.2/postgresql-12.2.tar.bz2",
    sha256 = "ad1dcc4c4fc500786b745635a9e1eba950195ce20b8913f50345bb7d5369b5de",
    strip_prefix = "postgresql-12.2",
    build_file_content = all_content,
)

# new_git_repository(
#     name = "libsnark",
#     commit = "477c9dfd07b280e42369f82f89c08416319e24ae",
#     remote = "https://github.com/scipr-lab/libsnark.git",
#     # branch = "master",
#     init_submodules = True,
#     shallow_since = "1560897792 -0400",
#     # strip_prefix = "",
#     build_file_content = all_content,
#     verbose = True
# )

# new_git_repository(
#     name = "snarky",
#     # commit = "",
#     remote = "git@github.com:o1-labs/snarky.git",
#     branch = "master",
#     init_submodules = True,
#     # shallow_since = "1570056263 -0700",
#     build_file_content = all_content,
#     verbose = True
# )

http_archive(
    name = "zlib",
    url = "https://zlib.net/zlib-1.2.11.tar.gz",
    sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
    strip_prefix = "zlib-1.2.11",
    build_file_content = all_content,
)

############################################
################    CUDA    ################
############################################
# http_archive(
#     name="cuda_fixnum",
#     url="https://github.com/unzvfu/cuda-fixnum/archive/v0.2.1.tar.gz",
#     sha256="08fe417a91261de8cbe5b631c9b257de003df787fa39fec44537aece710cedce",
#     strip_prefix = "cuda-fixnum-0.2.1",
#     build_file_content = all_content
#     # build_file = "@//:foo.BUILD"
# )

##########################################
########        GO TOOLING        ########
##########################################
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "6a68e269802911fa419abb940c850734086869d7fe9bc8e12aaf60a09641c818",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.23.0/rules_go-v0.23.0.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.23.0/rules_go-v0.23.0.tar.gz",
    ],
)

load(
    "@io_bazel_rules_go//go:deps.bzl",
    "go_rules_dependencies",
    "go_register_toolchains",
)

go_rules_dependencies()
go_register_toolchains(go_version = "host")

http_archive(
    name = "bazel_gazelle",
    sha256 = "bfd86b3cbe855d6c16c6fce60d76bd51f5c8dbc9cfcaef7a2bb5c1aafd0710e8",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.0/bazel-gazelle-v0.21.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.0/bazel-gazelle-v0.21.0.tar.gz",
    ],
)

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

gazelle_dependencies()


#######################################
########        GO DEPS        ########

## Fetching this in bzl/external/go.bzl does not work, for some reason.
## libp2p_core depends on it.
go_repository(
    name = "com_github_mini_sha256_simd",
    importpath = "github.com/minio/sha256-simd",
    commit = "6de4475307716de15b286880ff321c9547086fdd",
    # version = "0.1.1"
    # sum = ""
)

load("//bzl/external:go.bzl",
     "fetch_go_repos")
fetch_go_repos()

################################################################
git_repository(
    name = "digestif",
    branch = "bazel",
    remote = "https://github.com/mobileink/digestif",
)

git_repository(
    name = "ppx_optcomp",
    branch = "bazel",
    remote = "https://github.com/mobileink/ppx_optcomp"
)

git_repository(
    name = "ppx_version",
    branch = "bazel",
    remote = "https://github.com/mobileink/ppx_version",
)

local_repository( name = "async_kernel" , path = "src/external/async_kernel")
local_repository( name = "graphql_ppx"  , path = "src/external/graphql_ppx")
local_repository( name = "ocaml_extlib" , path = "src/external/ocaml_extlib")
local_repository( name = "ppx_optcomp"  , path = "src/external/ppx_optcomp")
local_repository( name = "ppx_version"  , path = "src/external/ppx_version")
local_repository( name = "rpc_parallel" , path = "src/external/rpc_parallel")
