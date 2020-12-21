load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository") # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

#####################
def cc_fetch_rules():
    ## Bazel is migrating to this lib instead of builtin rules_cc.
    ## Use the http_archive rule once it is released.
    maybe(
        git_repository,
        name = "rules_cc",
        remote = "https://github.com/bazelbuild/rules_cc",
        commit = "b1c40e1de81913a3c40e5948f78719c28152486d",
        shallow_since = "1605101351 -0800"
        # branch = "master"
    )

    maybe(
        http_archive,
        name = "rules_foreign_cc",
        strip_prefix="rules_foreign_cc-master",
        url = "https://github.com/bazelbuild/rules_foreign_cc/archive/master.zip",
        sha256 = "3e6b0691fc57db8217d535393dcc2cf7c1d39fc87e9adb6e7d7bab1483915110"
    )

########################
def ocaml_fetch_rules():

    maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        ],
        sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
    )

    maybe(
        git_repository,
        name = "obazl_tools_bazel",
        remote = "https://github.com/obazl/tools_bazel",
        branch = "main",
    )

    maybe(
        git_repository,
        name = "obazl_rules_opam",
        remote = "https://github.com/obazl/rules_opam",
        branch = "main",
    )

    maybe(
        git_repository,
        name = "obazl_rules_ocaml",
        remote = "https://github.com/obazl/rules_ocaml",
        branch = "main",
    )

#######################
def rust_fetch_rules():

    maybe(
        http_archive,
        name = "io_bazel_rules_rust",
        sha256 = "618cba29165b7a893960de7bc48510b0fb182b21a4286e1d3dbacfef89ace906",
        strip_prefix = "rules_rust-5998baf9016eca24fafbad60e15f4125dd1c5f46",
        urls = [
            # Master branch as of 2020-09-24
            "https://github.com/bazelbuild/rules_rust/archive/5998baf9016eca24fafbad60e15f4125dd1c5f46.tar.gz",
        ],
    )
