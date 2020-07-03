load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")

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

###############################################
########        GO DEPENDENCIES        ########
###############################################
##  Golang Rules

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

# go_register_toolchains()
go_register_toolchains(go_version = "host")

################
##  Gazelle
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

###################
####  Go Libs  ####

## NOTE: libs containing protobuf stuff use:
##    build_file_proto_mode = "disable_global"
## This makes Bazel use the supplied .pb.go files instead
## of processing the proto files.

go_repository(
    name = "com_github_libp2p_go_libp2p",
    importpath = "github.com/libp2p/go-libp2p",
    version = "v0.4.2",
    sum = "h1:p0cthB0jDNHO4gH2HzS8/nAMMXbfUlFHs0jwZ4U+F2g=",
    # version = "v0.3.1",
    # sum = "h1:opd8/1Sm9zFG37LzNQsIzMTMeBabhlcX5VlvLrNZPV0=",
    # version = "v0.9.2",
    # sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_core",
    # per https://github.com/bazelbuild/rules_go/blob/master/proto/core.rst#option-2-use-pre-generated-pb-go-files
    build_file_proto_mode = "disable_global",
    importpath = "github.com/libp2p/go-libp2p-core",
    # most recent v1.12 version:
    version = "v0.2.5",
    sum = "h1:iP1PIiIrlRrGbE1fYq2918yBc5NlCH3pFuIPSWU9hds=",
    # most recent version (go1.13)
    # version = "v0.5.6",
    # sum = "h1:IxFH4PmtLlLdPf4fF/i129SnK/C+/v8WEX644MxhC48=",
)

################
# WARNING: deprecated, use multiformats/go-multiaddr instead
go_repository(
    name = "com_github_libp2p_go_maddr_filter",
    importpath = "github.com/libp2p/go-maddr-filter",
    version = "v0.0.5",
    sum = "h1:CW3AgbMO6vUvT4kf87y4N+0P8KUl2aqLYhrGyDUbLSg=",

    # sum = "h1:4ACqZKw8AqiuJfwFGq1CYDFugfXTOos+qQ3DETkhtCE=",
    # version = "v0.1.0",
    # sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
    # version = "v0.8.1",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_discovery",
    importpath = "github.com/libp2p/go-libp2p-discovery",
    sum = "h1:dK78UhopBk48mlHtRCzbdLm3q/81g77FahEBTjcqQT8=",
    version = "v0.4.0",
    # sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
    # version = "v0.8.1",
)

go_repository(
    name = "com_github_libp2p_go_buffer_pool",
    importpath = "github.com/libp2p/go-buffer-pool",
    version = "v0.0.1",
    sum = "h1:9Rrn/H46cXjaA2HQ5Y8lyhOS1NhTkZ4yuEs2r3Eechg="
    # version = "v0.0.2",
    # sum = "h1:QNK2iAFa8gjAe1SPz6mHSMuCcjs+X1wlHzeOSqcmlfs=",
    # sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
    # version = "v0.8.1",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_pnet",
    importpath = "github.com/libp2p/go-libp2p-pnet",
    version = "v0.1.0",
    sum = "h1:kRUES28dktfnHNIRW4Ro78F7rKBHBiw5MJpl0ikrLIA=",

    # version = "v0.2.0",
    # sum = "h1:J6htxttBipJujEjz1y0a5+eYoiPcFHhSYHH6na5f0/k=",
)

go_repository(
    name = "com_github_libp2p_go_tcp_transport",
    importpath = "github.com/libp2p/go-tcp-transport",
    sum = "h1:YoThc549fzmNJIh7XjHVtMIFaEDRtIrtWciG5LyYAPo=",
    version = "v0.2.0",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_kad_dht",
    importpath = "github.com/libp2p/go-libp2p-kad-dht",
    build_file_proto_mode = "disable_global",
    version = "v0.3.0",
    sum = "h1:KUJaqW3kkHP6zcL0s1CDg+yO0NYNNPkXmG4FrnZbwzM=",

    # version = "v0.7.6",
    # commit = "2d843068a33582996e468895adb5372a651221d2",
    # version = "v0.7.12",
    # sum = "h1:D3eD92iCtmqD0sDAfOwMF2Yh4DRlIms6ADHbUK4CRkc=",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_secio",
    importpath = "github.com/libp2p/go-libp2p-secio",
    build_file_proto_mode = "disable_global",
    # version = "v0.1.0",
    # sum = "h1:NNP5KLxuP97sE5Bu3iuwOWyT/dKEGMN5zSLMWdB7GTQ="
    # version = "v0.2.0",
    # sum = "h1:ywzZBsWEEz2KNTn5RtzauEDq5RFEefPsttXYwAWqHng=",
    version = "v0.2.1",
    sum = "h1:eNWbJTdyPA7NxhP7J3c5lT97DC5d+u+IldkgCYFTPVA=",
    # version = "v0.2.2",
    # sum = "h1:rLLPvShPQAcY6eNurKNZq3eZjPWfU9kXF2eI9jIYdrg=",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_record",
    importpath = "github.com/libp2p/go-libp2p-record",
    build_file_proto_mode = "disable_global",
    sum = "h1:R27hoScIhQf/A8XJZ8lYpnqh9LatJ5YbHs28kCIfql0=",
    version = "v0.1.3",
)

go_repository(
    name = "com_github_libp2p_go_ws_transport",
    importpath = "github.com/libp2p/go-ws-transport",
    sum = "h1:ZX5rWB8nhRRJVaPO6tmkGI/Xx8XNboYX20PW5hXIscw=",
    version = "v0.3.1",
)

go_repository(
    name = "com_github_libp2p_go_stream_muxer",
    importpath = "github.com/libp2p/go-stream-muxer",
    sum = "h1:3ToDXUzx8pDC6RfuOzGsUYP5roMDthbUKRdMRRhqAqY=",
    version = "v0.1.0",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_peerstore",
    importpath = "github.com/libp2p/go-libp2p-peerstore",
    build_file_proto_mode = "disable_global",
    version = "v0.1.4",
    sum = "h1:d23fvq5oYMJ/lkkbO4oTwBp/JP+I/1m5gZJobNXCE/k=",
    # version = "v0.2.4",
    # sum = "h1:jU9S4jYN30kdzTpDAR7SlHUD+meDUjTODh4waLWF1ws=",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_pubsub",
    importpath = "github.com/libp2p/go-libp2p-pubsub",
    build_file_proto_mode = "disable_global",
    version = "v0.2.3",
    sum = "h1:qJRnRnM7Z4xnHb4i6EBb3DKQXRPgtFWlKP4AmfJudLQ=",

    # version = "v0.3.0",
    # sum = "h1:K5FSYyfcSrJWrGExgdbogCLMqwC3pQaXEVt2CaUy1SA=",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_swarm",
    importpath = "github.com/libp2p/go-libp2p-swarm",
    version = "v0.2.2",
    sum = "h1:T4hUpgEs2r371PweU3DuH7EOmBIdTBCwWs+FLcgx3bQ=",
    # version = "v0.2.5",
    # sum = "h1:PinJOL2Haz0USGg6Z7wGALe4E6tJmAaUmKPxYWQSi68=",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_tls",
    importpath = "github.com/libp2p/go-libp2p-tls",
    build_file_proto_mode = "disable_global",
    # version = "v0.0.1",
    # commit = "bda3b040b78987ac1be29d1f3e3ada93a6be5113",

    # commit = "2e8087cb4c6d41c930c88e0dfdcb9c2bb48831ba"

    # version = "v0.1.2",
    # commit = "141af4b2014d61ca0ef27b82e3776c254d4eba91"
    version = "v0.1.3",
    sum = "h1:twKMhMu44jQO+HgQK9X8NHO5HkeJu2QbhLzLJpa8oNM=",
)

# [DEPRECATED] Interfaces for securing libp2p connections; use https://github.com/libp2p/go-libp2p-core/
go_repository(
    name = "com_github_libp2p_go_conn_security",
    importpath = "github.com/libp2p/go-conn-security",
    commit = "5f8143019e00897f3f6776723f2ca9230904458b",
    # sum = "h1:uNiDjS58vrvJTg9jO6bySd1rMKejieG7v45ekqHbZ1M=",
    # version = "v0.1.0",
)

go_repository(
    name = "com_github_libp2p_go_conn_security_multistream",
    importpath = "github.com/libp2p/go-conn-security-multistream",
    sum = "h1:uNiDjS58vrvJTg9jO6bySd1rMKejieG7v45ekqHbZ1M=",
    version = "v0.2.0",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_yamux",
    importpath = "github.com/libp2p/go-libp2p-yamux",
    sum = "h1:0s3ELSLu2O7hWKfX1YjzudBKCP0kZ+m9e2+0veXzkn4=",
    version = "v0.2.8",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_circuit",
    importpath = "github.com/libp2p/go-libp2p-circuit",
    sum = "h1:87RLabJ9lrhoiSDDZyCJ80ZlI5TLJMwfyoGAaWXzWqA=",
    version = "v0.2.2",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_mplex",
    importpath = "github.com/libp2p/go-libp2p-mplex",
    version = "v0.2.1",
    sum = "h1:E1xaJBQnbSiTHGI1gaBKmKhu1TUKkErKJnE8iGvirYI="
    # version = "v0.2.3",
    # sum = "h1:2zijwaJvpdesST2MXpI5w9wWFRgYtMcpRX7rrw0jmOo=",
)

go_repository(
    name = "com_github_libp2p_go_eventbus",
    importpath = "github.com/libp2p/go-eventbus",
    sum = "h1:mlawomSAjjkk97QnYiEmHsLu7E136+2oCWSHRUvMfzQ=",
    version = "v0.1.0",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_autonat",
    importpath = "github.com/libp2p/go-libp2p-autonat",
    version = "v0.1.0",
    sum = "h1:aCWAu43Ri4nU0ZPO7NyLzUvvfqd0nE3dX0R/ZGYVgOU=",
    # version = "v0.2.3",
    # sum = "h1:w46bKK3KTOUWDe5mDYMRjJu1uryqBp8HCNDp/TWMqKw=",
)

go_repository(
    name = "com_github_libp2p_go_yamux",
    importpath = "github.com/libp2p/go-yamux",
    sum = "h1:v40A1eSPJDIZwz2AvrV3cxpTZEGDP11QJbukmEhYyQI=",
    version = "v1.3.7",
)

go_repository(
    name = "com_github_libp2p_go_mplex",
    importpath = "github.com/libp2p/go-mplex",
    version = "v0.1.0",
    sum = "h1:/nBTy5+1yRyY82YaO6HXQRnO5IAGsXTjEJaR3LdTPc0="
    # sum = "h1:qOg1s+WdGLlpkrczDqmhYzyk3vCfsQ8+RxRTQjOZWwI=",
    # version = "v0.1.2",
)

go_repository(
    name = "com_github_libp2p_go_flow_metrics",
    importpath = "github.com/libp2p/go-flow-metrics",
    sum = "h1:8tAs/hSdNvUiLgtlSy3mxwxWP4I9y/jlkPFT7epKdeM=",
    version = "v0.0.3",
)

go_repository(
    name = "com_github_libp2p_go_stream_muxer_multistream",
    importpath = "github.com/libp2p/go-stream-muxer-multistream",
    sum = "h1:TqnSHPJEIqDEO7h1wZZ0p3DXdvDSiLHQidKKUGZtiOY=",
    version = "v0.3.0",
)

go_repository(
    name = "com_github_libp2p_go_reuseport_transport",
    importpath = "github.com/libp2p/go-reuseport-transport",
    sum = "h1:zzOeXnTooCkRvoH+bSXEfXhn76+LAiwoneM0gnXjF2M=",
    version = "v0.0.3",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_blankhost",
    importpath = "github.com/libp2p/go-libp2p-blankhost",
    sum = "h1:CkPp1/zaCrCnBo0AdsQA0O1VkUYoUOtyHOnoa8gKIcE=",
    version = "v0.1.6",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_transport_upgrader",
    importpath = "github.com/libp2p/go-libp2p-transport-upgrader",
    version = "v0.1.1",
    sum = "h1:PZMS9lhjK9VytzMCW3tWHAXtKXmlURSc3ZdvwEcKCzw=",

    # version = "v0.3.0",
    # sum = "h1:q3ULhsknEQ34eVDhv4YwKS8iet69ffs9+Fir6a7weN4=",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_loggables",
    importpath = "github.com/libp2p/go-libp2p-loggables",
    sum = "h1:h3w8QFfCt2UJl/0/NW4K829HX/0S4KD31PQ7m8UXXO8=",
    version = "v0.1.0",
)

go_repository(
    name = "com_github_libp2p_go_addr_util",
    importpath = "github.com/libp2p/go-addr-util",
    sum = "h1:7cWK5cdA5x72jX0g8iLrQWm5TRJZ6CzGdPEhWj7plWU=",
    version = "v0.0.2",
)

go_repository(
    name = "com_github_libp2p_go_msgio",
    importpath = "github.com/libp2p/go-msgio",
    sum = "h1:agEFehY3zWJFUHK6SEMR7UYmk2z6kC3oeCM7ybLhguA=",
    version = "v0.0.4",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_nat",
    importpath = "github.com/libp2p/go-libp2p-nat",
    version = "v0.0.5",
    sum = "h1:/mH8pXFVKleflDL1YwqMg27W9GD8kjEx7NY0P6eGc98="
    # version = "v0.0.6",
    # sum = "h1:wMWis3kYynCbHoyKLPBEMu4YRLltbm8Mk08HGSfvTkU=",
)

go_repository(
    name = "com_github_libp2p_go_netroute",
    importpath = "github.com/libp2p/go-netroute",
    sum = "h1:UHhB35chwgvcRI392znJA3RCBtZ3MpE3ahNCN5MR4Xg=",
    version = "v0.1.2",
)

go_repository(
    name = "com_github_libp2p_go_reuseport",
    importpath = "github.com/libp2p/go-reuseport",
    sum = "h1:7PhkfH73VXfPJYKQ6JwS5I/eVcoyYi9IMNGc6FWpFLw=",
    version = "v0.0.1",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_kbucket",
    importpath = "github.com/libp2p/go-libp2p-kbucket",
    version = "v0.2.1",
    sum = "h1:q9Jfwww9XnXc1K9dyYuARJxJvIvhgYVaQCuziO/dF3c=",
    # sum = "h1:wg+VPpCtY61bCasGRexCuXOmEmdKjN+k1w+JtTwu9gA=",
    # version = "v0.4.2",
)

go_repository(
    name = "com_github_libp2p_go_nat",
    importpath = "github.com/libp2p/go-nat",
    sum = "h1:qxnwkco8RLKqVh1NmjQ+tJ8p8khNLFxuElYG/TwqW4Q=",
    version = "v0.0.5",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_peer",
    importpath = "github.com/libp2p/go-libp2p-peer",
    sum = "h1:EQ8kMjaCUwt/Y5uLgjT8iY2qg0mGUT0N1zUjer50DsY=",
    version = "v0.2.0",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_crypto",
    importpath = "github.com/libp2p/go-libp2p-crypto",
    sum = "h1:k9MFy+o2zGDNGsaoZl0MA3iZ75qXxr9OOoAZF+sD5OQ=",
    version = "v0.1.0",
)

go_repository(
    name = "com_github_libp2p_go_libp2p_routing",
    importpath = "github.com/libp2p/go-libp2p-routing",
    sum = "h1:hFnj3WR3E2tOcKaGpyzfP4gvFZ3t8JkQmbapN0Ct+oU=",
    version = "v0.1.0",
)

################################
####  IPFS DEPS
go_repository(
    name = "com_github_ipfs_go_cid",
    importpath = "github.com/ipfs/go-cid",
    sum = "h1:o0Ix8e/ql7Zb5UVUJEUfjsWCIY8t48++9lR8qi6oiJU=",
    version = "v0.0.5",
)

go_repository(
    name = "com_github_ipfs_go_detect_race",
    importpath = "github.com/ipfs/go-detect-race",
    sum = "h1:qX/xay2W3E4Q1U7d9lNs1sU9nvguX0a7319XbyQ6cOk=",
    version = "v0.0.1",
)

go_repository(
    name = "com_github_ipfs_go_ds_badger",
    importpath = "github.com/ipfs/go-ds-badger",
    sum = "h1:UPGB0y7luFHk+mY/tUZrif/272M8o+hFsW+avLUeWrM=",
    version = "v0.2.4",
)

go_repository(
    name = "com_github_ipfs_go_log",
    importpath = "github.com/ipfs/go-log",
    version = "v0.0.1",
    sum = "h1:9XTUN/rW64BCG1YhPK9Hoy3q8nr4gOmHHBpgFdfw6Lc=",
    # version = "v1.0.4",
    # sum = "h1:6nLQdX4W8P9yZZFH7mO+X/PzjN8Laozm/lMJ6esdgzY=",
)

go_repository(
    name = "com_github_ipfs_go_log_v2",
    importpath = "github.com/ipfs/go-log/v2",
    sum = "h1:Q2gXcBoCALyLN/pUQlz1qgu0x3uFV6FzP9oXhpfyJpc=",
    version = "v2.0.3",
)

go_repository(
    name = "com_github_ipfs_go_datastore",
    importpath = "github.com/ipfs/go-datastore",
    sum = "h1:rjvQ9+muFaJ+QZ7dN5B1MSDNQ0JVZKkkES/rMZmA8X8=",
    version = "v0.4.4",
)

go_repository(
    name = "com_github_ipfs_go_ipns",
    importpath = "github.com/ipfs/go-ipns",
    sum = "h1:oq4ErrV4hNQ2Eim257RTYRgfOSV/s8BDaf9iIl4NwFs=",
    version = "v0.0.2",
)

go_repository(
    name = "com_github_ipfs_go_ipfs_util",
    importpath = "github.com/ipfs/go-ipfs-util",
    sum = "h1:Wz9bL2wB2YBJqggkA4dD7oSmqB4cAnpNbGrlHJulv50=",
    version = "v0.0.1",
)

go_repository(
    name = "com_github_ipfs_go_todocounter",
    importpath = "github.com/ipfs/go-todocounter",
    sum = "h1:9UBngSQhylg2UDcxSAtpkT+rEWFr26hDPXVStE8LFyc=",
    version = "v0.0.2",
)

################################
####  MULTIFORMATS
################################
go_repository(
    name = "com_github_multiformats_go_multiaddr",
    importpath = "github.com/multiformats/go-multiaddr",
    sum = "h1:XZLDTszBIJe6m0zF6ITBrEcZR73OPUhCBBS9rYAuUzI=",
    version = "v0.2.2",
    # version = "v0.2.2",
    # sum = ""
)

go_repository(
    name = "com_github_multiformats_go_multiaddr_net",
    importpath = "github.com/multiformats/go-multiaddr-net",
    sum = "h1:QoRKvu0xHN1FCFJcMQLbG/yQE2z441L5urvG3+qyz7g=",
    version = "v0.1.5",
)

go_repository(
    name = "com_github_multiformats_go_multiaddr_dns",
    importpath = "github.com/multiformats/go-multiaddr-dns",
    sum = "h1:YWJoIDwLePniH7OU5hBnDZV6SWuvJqJ0YtN6pLeH9zA=",
    version = "v0.2.0",
)

go_repository(
    name = "com_github_multiformats_go_varint",
    importpath = "github.com/multiformats/go-varint",
    sum = "h1:XVZwSo04Cs3j/jS0uAEPpT3JY6DzMcVLLoWOSnCxOjg=",
    version = "v0.0.5",
)

go_repository(
    name = "com_github_multiformats_go_multihash",
    importpath = "github.com/multiformats/go-multihash",
    sum = "h1:06x+mk/zj1FoMsgNejLpy6QTvJqlSt/BhLEy87zidlc=",
    version = "v0.0.13",
)

go_repository(
    name = "com_github_multiformats_go_multibase",
    importpath = "github.com/multiformats/go-multibase",
    sum = "h1:2pAgScmS1g9XjH7EtAfNhTuyrWYEWcxy0G5Wo85hWDA=",
    version = "v0.0.2",
)

go_repository(
    name = "com_github_multiformats_go_base32",
    importpath = "github.com/multiformats/go-base32",
    sum = "h1:tw5+NhuwaOjJCC5Pp82QuXbrmLzWg7uxlMFp8Nq/kkI=",
    version = "v0.0.3",
)

go_repository(
    name = "com_github_multiformats_go_multiaddr_fmt",
    importpath = "github.com/multiformats/go-multiaddr-fmt",
    sum = "h1:WLEFClPycPkp4fnIzoFoV9FVd49/eQsuaL3/CWe167E=",
    version = "v0.1.0",
)

go_repository(
    name = "com_github_multiformats_go_multistream",
    importpath = "github.com/multiformats/go-multistream",
    sum = "h1:JlAdpIFhBhGRLxe9W6Om0w++Gd6KMWoFPZL/dEnm9nI=",
    version = "v0.1.1",
)

################################
####  WHYRUSLEEPING
################################
go_repository(
    name = "com_github_whyrusleeping_base32",
    importpath = "github.com/whyrusleeping/base32",
    version = "v0.0.0-20170828182744-c30ac30633cc",
    sum = "h1:BCPnHtcboadS0DvysUuJXZ4lWVv5Bh5i7+tbIyi+ck4=",
)

go_repository(
    name = "com_github_whyrusleeping_go_logging",
    importpath = "github.com/whyrusleeping/go-logging",
    sum = "h1:fwpzlmT0kRC/Fmd0MdmGgJG/CXIZ6gFq46FQZjprUcc=",
    version = "v0.0.1",
    # sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
    # version = "v0.8.1",
)

go_repository(
    name = "com_github_whyrusleeping_mdns",
    importpath = "github.com/whyrusleeping/mdns",
    tag = "master",
    # sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
    # version = "v0.8.1",
)

go_repository(
    name = "com_github_whyrusleeping_multiaddr_filter",
    importpath = "github.com/whyrusleeping/multiaddr-filter",
    sum = "h1:E9S12nwJwEOXe2d6gT6qxdvqMnNq+VnSsKPgm2ZZNds=",
    version = "v0.0.0-20160516205228-e903e4adabd7",
)

go_repository(
    name = "com_github_whyrusleeping_timecache",
    importpath = "github.com/whyrusleeping/timecache",
    sum = "h1:lYbXeSvJi5zk5GLKVuid9TVjS9a0OmLIDKTfoZBL6Ow=",
    version = "v0.0.0-20160911033111-cfcb2f1abfee",
)

go_repository(
    name = "com_github_whyrusleeping_go_keyspace",
    importpath = "github.com/whyrusleeping/go-keyspace",
    sum = "h1:EKhdznlJHPMoKr0XTrX+IlJs1LH3lyx2nfr1dOlZ79k=",
    version = "v0.0.0-20160322163242-5b898ac5add1",
)

################################
####  GOLANG_X
################################
go_repository(
    name = "org_golang_x_net",
    importpath = "golang.org/x/net",
    sum = "h1:oWX7TPOiFAMXLq8o0ikBYfCJVlRHBcsciT5bXOrH628=",
    version = "v0.0.0-20190311183353-d8887717615a",
)

go_repository(
    name = "org_golang_x_text",
    importpath = "golang.org/x/text",
    sum = "h1:g61tztE5qeGQ89tm6NTjjM9VPIm088od1l6aSorWRWg=",
    version = "v0.3.0",
)

go_repository(
    name = "org_golang_x_sys",
    importpath = "golang.org/x/sys",
    build_file_proto_mode = "disable_global",
    sum = "h1:DYfZAGf2WMFjMxbgTjaC+2HC7NkNAQs+6Q8b9WEB/F4=",
    version = "v0.0.0-20200519105757-fe76b779f299",
)

# go_repository(
#     name = "org_golang_x_sys",
#     importpath = "golang.org/x/sys",
#     # build_file_proto_mode = "disable_global",
#     # version = "v0.0.0-20200430202703-d923437fa56d",
#     # sum = "h1:DYfZAGf2WMFjMxbgTjaC+2HC7NkNAQs+6Q8b9WEB/F4=",
#     # version = "v0.0.0-20200519105757-fe76b779f299",
# )

go_repository(
    name = "org_golang_x_crypto",
    importpath = "golang.org/x/crypto",
    sum = "h1:cg5LA/zNPRzIXIWSCxQW10Rvpy94aQh3LT/ShoCpkHw=",
    version = "v0.0.0-20200510223506-06a226fb4e37",
)

################################

go_repository(
    name = "com_github_go_errors_errors",
    importpath = "github.com/go-errors/errors",
    sum = "h1:xMxH9j2fNg/L4hLn/4y3M0IUsn0M6Wbu/Uh9QlOfBh4=",
    version = "v1.0.2",
    # sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
    # version = "v0.8.1",
)

go_repository(
    name = "com_github_btcsuite_btcd",
    importpath = "github.com/btcsuite/btcd",
    commit = "f3ec13030e4e828869954472cbc51ac36bee5c1d",
    # version = "v0.20.1-beta",
    # sum = ""
)

go_repository(
    name = "com_github_mini_sha256_simd",
    importpath = "github.com/minio/sha256-simd",
    commit = "6de4475307716de15b286880ff321c9547086fdd",
    # version = "0.1.1"
    # sum = ""
)

go_repository(
    name = "com_github_pkg_errors",
    importpath = "github.com/pkg/errors",
    sum = "h1:FEBLx1zS214owpjy7qsBeixbURkuhQAwrK5UwLGTwt4=",
    version = "v0.9.1",
)

go_repository(
    name = "com_github_gogo_protobuf",
    importpath = "github.com/gogo/protobuf",
    sum = "h1:DqDEcV5aeaTmdFBePNpYsp3FlcVH/2ISVVM9Qf8PSls=",
    version = "v1.3.1",
)

go_repository(
    name = "com_github_gogo_protobuf_gogoproto",
    importpath = "github.com/gogo/protobuf/gotoproto",
    build_file_proto_mode = "disable_global",
    sum = "h1:DqDEcV5aeaTmdFBePNpYsp3FlcVH/2ISVVM9Qf8PSls=",
    version = "v1.3.1",
)

go_repository(
    name = "com_github_davidlazar_go_crypto",
    importpath = "github.com/davidlazar/go-crypto",
    sum = "h1:BOaYiTvg8p9vBUXpklC22XSK/mifLF7lG9jtmYYi3Tc=",
    version = "v0.0.0-20190912175916-7055855a373f",
)

go_repository(
    name = "com_github_jbenet_go_cienv",
    importpath = "github.com/jbenet/go-cienv",
    sum = "h1:Vc/s0QbQtoxX8MwwSLWWh+xNNZvM3Lw7NsTcHrvvhMc=",
    version = "v0.1.0",
)

go_repository(
    name = "com_github_jbenet_goprocess",
    importpath = "github.com/jbenet/goprocess",
    sum = "h1:DRGOFReOMqqDNXwW70QkacFW0YN9QnwLV0Vqk+3oU0o=",
    version = "v0.1.4",
)

## WARNING: v0.1.0 depends on go 1.13, which breaks other code
## We're stuck at 1.12 atm
go_repository(
    name = "com_github_jbenet_go_temp_err_catcher",
    importpath = "github.com/jbenet/go-temp-err-catcher",
    # last commit with go < 1.13 dated Jan 2015
    commit = "aac704a3f4f27190b4ccc05f303a4931fd1241ff",
    # version = "v0.1.0",
    # sum = "h1:zpb3ZH6wIE8Shj2sKS+khgRvf7T7RABoLk/+KKHggpk=",
)

go_repository(
    name = "com_github_mr_tron_base58",
    importpath = "github.com/mr-tron/base58",
    sum = "h1:v+sk57XuaCKGXpWtVBX8YJzO7hMGx4Aajh4TQbdEFdc=",
    version = "v1.1.3",
)

go_repository(
    name = "org_golang_google_grpc",
    build_file_proto_mode = "disable",
    importpath = "google.golang.org/grpc",
    sum = "h1:J0UbZOIrCAl+fpTOf8YLs4dJo8L/owV4LYVtAXQoPkw=",
    version = "v1.22.0",
)

go_repository(
    name = "com_github_opentracing_opentracing_go",
    importpath = "github.com/opentracing/opentracing-go",
    sum = "h1:pWlfV3Bxv7k65HYwkikxat0+s3pV4bsqf19k25Ur8rU=",
    version = "v1.1.0",
)

go_repository(
    name = "com_github_miekg_dns",
    importpath = "github.com/miekg/dns",
    sum = "h1:xHBEhR+t5RzcFJjBLJlax2daXOrTYtr9z4WdKEfWFzg=",
    version = "v1.1.29",
)

go_repository(
    name = "org_uber_go_zap",
    importpath = "go.uber.org/zap",
    sum = "h1:ZZCA22JRF2gQE5FoNmhmrf7jeJJ2uhqDUNRYKm8dvmM=",
    version = "v1.15.0",
)

go_repository(
    name = "org_uber_go_atomic",
    importpath = "go.uber.org/atomic",
    sum = "h1:Ezj3JGmsOnG1MoRWQkPBsKLe9DwWD9QeXzTRzzldNVk=",
    version = "v1.6.0",
)

go_repository(
    name = "org_uber_go_multierr",
    importpath = "go.uber.org/multierr",
    sum = "h1:KCa4XfM8CWFCpxXRGok+Q0SS/0XBhMDbHHGABQLvD2A=",
    version = "v1.5.0",
)

go_repository(
    name = "com_github_spaolacci_murmur3",
    importpath = "github.com/spaolacci/murmur3",
    sum = "h1:7c1g84S4BPRrfL5Xrdp6fOJ206sU9y293DDHaoy0bLI=",
    version = "v1.1.0",
)

go_repository(
    name = "com_github_minio_blake2b_simd",
    importpath = "github.com/minio/blake2b-simd",
    sum = "h1:lYpkrQH5ajf0OXOcUbGjvZxxijuBwbbmlSxLiuofa+g=",
    version = "v0.0.0-20160723061019-3f5f724cb5b1",
)

go_repository(
    name = "com_github_mattn_go_colorable",
    importpath = "github.com/mattn/go-colorable",
    version = "v0.1.2",
    sum = "h1:/bC9yWikZXAL9uJdulbSfyVNIR3n3trXl+v8+1sx8mU=",
)

go_repository(
    name = "com_github_hashicorp_golang_lru",
    importpath = "github.com/hashicorp/golang-lru",
    sum = "h1:YDjusn29QI/Das2iO9M0BHnIbxPeyuCHsjMW+lJfyTc=",
    version = "v0.5.4",
)

go_repository(
    name = "com_github_hashicorp_go_multierror",
    importpath = "github.com/hashicorp/go-multierror",
    commit = "886a7fbe3eb1c874d46f623bfa70af45f425b3d1",
    # v1.1.0 requires go1.14
    # version = "v1.1.0",
    # sum = "h1:B9UzwGQJehnUY1yNrnwREHc3fGbC2xefo8g4TbElacI=",
)

go_repository(
    name = "com_github_hashicorp_errwrap",
    importpath = "github.com/hashicorp/errwrap",
    sum = "h1:hLrqtEDnRye3+sgx6z4qVLNuviH3MR5aQ0ykNJa/UYA=",
    version = "v1.0.0",
)

go_repository(
    name = "com_github_dgraph_io_badger",
    importpath = "github.com/dgraph-io/badger",
    sum = "h1:w9pSFNSdq/JPM1N12Fz/F/bzo993Is1W+Q7HjPzi7yg=",
    version = "v1.6.1",
)

go_repository(
    name = "com_github_google_uuid",
    importpath = "github.com/google/uuid",
    sum = "h1:Gkbcsh/GbpXz7lPftLA3P6TYMwjCLYm83jiFQZF/3gY=",
    version = "v1.1.1",
)

go_repository(
    name = "com_github_dustin_go_humanize",
    importpath = "github.com/dustin/go-humanize",
    sum = "h1:VSnTsYCnlFHaM2/igO1h6X3HA71jcobQuxemgkq4zYo=",
    version = "v1.0.0",
)

go_repository(
    name = "com_github_gorilla_websocket",
    importpath = "github.com/gorilla/websocket",
    sum = "h1:+/TMaTYc4QFitKJxsQ7Yye35DkWvkdLcvGKqM+x0Ufc=",
    version = "v1.4.2",
)

go_repository(
    name = "io_opencensus_go",
    importpath = "go.opencensus.io",
    sum = "h1:8sGtKOrtQqkN1bp2AtX+misvLIlOmsEsNd+9NIcPEm8=",
    version = "v0.22.3",
)

go_repository(
    name = "com_github_dgraph_io_ristretto",
    importpath = "github.com/dgraph-io/ristretto",
    sum = "h1:a5WaUrDa0qm0YrAAS1tUykT5El3kt62KNZZeMxQn3po=",
    version = "v0.0.2",
)

go_repository(
    name = "com_github_cespare_xxhash",
    importpath = "github.com/cespare/xxhash",
    sum = "h1:a6HrQnmkObjyL+Gs60czilIUGqrzKutQD6XZog3p+ko=",
    version = "v1.1.0",
)

go_repository(
    name = "com_github_andreasbriese_bbloom",
    importpath = "github.com/AndreasBriese/bbloom",
    sum = "h1:cTp8I5+VIoKjsnZuH8vjyaysT/ses3EvZeaV/1UkF2M=",
    version = "v0.0.0-20190825152654-46b345b51c96",
)

go_repository(
    name = "com_github_google_gopacket",
    importpath = "github.com/google/gopacket",
    sum = "h1:rMrlX2ZY2UbvT+sdz3+6J+pp2z+msCq9MxTU6ymxbBY=",
    version = "v1.1.17",
)

go_repository(
    name = "com_github_coreos_go_semver",
    importpath = "github.com/coreos/go-semver",
    sum = "h1:wkHLiw0WNATZnSG7epLsujiMCgPAc9xhjJ4tgnAxmfM=",
    version = "v0.3.0",
)

go_repository(
    name = "com_github_huin_goupnp",
    importpath = "github.com/huin/goupnp",
    sum = "h1:wg75sLpL6DZqwHQN6E1Cfk6mtfzS45z8OV+ic+DtHRo=",
    version = "v1.0.0",
)

go_repository(
    name = "com_github_koron_go_ssdp",
    importpath = "github.com/koron/go-ssdp",
    sum = "h1:68u9r4wEvL3gYg2jvAOgROwZ3H+Y3hIDk4tbbmIjcYQ=",
    version = "v0.0.0-20191105050749-2e1c40ed0b5d",
)

go_repository(
    name = "com_github_jackpal_go_nat_pmp",
    importpath = "github.com/jackpal/go-nat-pmp",
    sum = "h1:KzKSgb7qkJvOUTqYl9/Hg/me3pWgBmERKrTGD7BdWus=",
    version = "v1.0.2",
)

# go_repository(
#     name = "com_github_golang_sys",
#     importpath = "github.com/golang/sys",
#     sum = "h1:hBF7EAbgop26bZkb27Us6BFk1IOv+TlETGnVIFjZhso=",
#     version = "v0.0.0-20200519105757-fe76b779f299",
# )

go_repository(
    name = "com_github_mattn_go_isatty",
    importpath = "github.com/mattn/go-isatty",
    version = "v0.0.8",
    sum = "h1:HLtExJ+uU2HOZ+wI0Tt5DtUDrx8yhUqDcp7fYERX4CE="
    # sum = "h1:wuysRhFDzyxgEmMf5xjvJ2M9dZoWAXNNr5LSBS7uHXY=",
    # version = "v0.0.12",
)

################################################################
#### OCAML ####
git_repository(
    name = "obazl",
    remote = "https://github.com/mobileink/obazl",
    branch = "master",
    # commit = "e848f42ed169f69fd12d1dbacf49d5d6e38dbe15",
    # shallow_since = "1593486114 -0500"
)

load("@obazl//ocaml:deps.bzl",
     "ocaml_configure_tooling",
     # "ocaml_repositories",
     # "ocaml_home_sdk",
     "ocaml_register_toolchains")

ocaml_configure_tooling()

ocaml_register_toolchains(installation="host")

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
