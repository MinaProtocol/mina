load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def rust_fetch_libs():

    # native.local_repository( name = "zexe" , path = "src/lib/marlin/zexe")
    maybe(
        git_repository,
        name = "zexe",
        remote = "https://github.com/o1-labs/zexe",
        commit = "0ce97035781551ddf9dd0bec017d29de227d7d42",
        shallow_since = "1608332456 +0000"
        # remote = "https://github.com/obazl/zexe",
        # branch = "bazel"
        # branch = "master",
     )

    # native.local_repository( name = "marlin" , path = "src/lib/marlin")
    maybe(
        git_repository,
        name = "marlin",
        remote = "https://github.com/o1-labs/marlin.git",
        commit = "282c76f278c5744bd9c27d53cc6cdb0ca768ac00",
        shallow_since = "1608343138 +0000"
        # branch = "master",

        # remote = "https://github.com/obazl/marlin",
        # branch = "mina"
    )
