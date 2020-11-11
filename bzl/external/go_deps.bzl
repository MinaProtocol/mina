load("@bazel_tools//tools/build_defs/repo:git.bzl",
     "git_repository", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

all_content = """filegroup(name = "all", srcs = glob(["**"]), visibility = ["//visibility:public"])"""

def go_bootstrap():
    """This bootstraps (loads) Golang repos"""

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "b725e6497741d7fc2d55fcc29a276627d10e43fa5d0bb692692890ae30d98d00",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.24.3/rules_go-v0.24.3.tar.gz",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.24.3/rules_go-v0.24.3.tar.gz",
        ],
    )

    ## protobuf needed by some go deps
    maybe(
        git_repository,
        name = "com_google_protobuf",
        commit = "09745575a923640154bcf307fba8aedff47f240a",
        remote = "https://github.com/protocolbuffers/protobuf",
        shallow_since = "1558721209 -0700",
    )

    maybe(
        # gazelle:proto disable_global
        http_archive,
        name = "bazel_gazelle",
        sha256 = "d4113967ab451dd4d2d767c3ca5f927fec4b30f3b2c6f8135a2033b9c05a5687",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.0/bazel-gazelle-v0.22.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.0/bazel-gazelle-v0.22.0.tar.gz",
        ],
    )

