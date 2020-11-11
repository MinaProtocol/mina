load("@bazel_tools//tools/build_defs/repo:git.bzl",
     "git_repository", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

all_content = """filegroup(name = "all", srcs = glob(["**"]), visibility = ["//visibility:public"])"""

def rust_bootstrap():
    """This bootstraps (loads) Golang repos"""

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

    ## once embedded git submodules are eliminated, use these instead of local_repository
    # maybe(
    #     git_repository,
    #     name = "zexe",
    #     remote = "https://github.com/o1-labs/zexe",
    #     branch = "master",
    #     # tag    = use tag instead of branch once a release tag has been published
    # )

    # maybe(
    #     git_repository,
    #     name = "marlin",
    #     remote = "https://github.com/obazl/marlin",
    #     branch = "master",
    #     # tag    = use tag instead of branch once a release tag has been published
    # )

