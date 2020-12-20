load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

########################
def ocaml_fetch_remote_libs():

    maybe(
        git_repository,
        name = "graphql_ppx",
        remote = "https://github.com/o1-labs/graphql_ppx",
        commit = "279b0ffd611ef635ec955d63ffe46d875a977f9f",
        shallow_since = "1608322328 +0000"
        # branch = "master"
    )

    maybe(
        git_repository,
        name = "ppx_optcomp",
        remote = "https://github.com/MinaProtocol/ppx_optcomp.git",
        commit = "96974015f19f1dd6e7d69a68678008f5df41b487",
        shallow_since = "1608322974 +0000"
        # branch = "master"
    )

    maybe(
        git_repository,
        name = "ppx_version",
        remote = "https://github.com/o1-labs/ppx_version",
        commit = "11371c53e4ad07f8fcd499ff63b3c79942698072",
        shallow_since = "1608322894 +0000"
        # branch = "master"
    )

    maybe(
        git_repository,
        name = "snarky",
        remote = "https://github.com/o1-labs/snarky",
        commit = "57832d6f9172fa18f03ba58f421e66f5c865f953",
        shallow_since = "1608323031 +0000"
        # branch = "master"
    )

    ################################################################
    maybe(
        git_repository,
        name = "ocaml_jemalloc",
        remote = "https://github.com/obazl/ocaml-jemalloc",
        branch = "bazel"
        ## TODO:
        # remote = "https://github.com/o1-labs/jemalloc",
        # branch = "mina"
    )

    maybe(
        git_repository,
        name = "ocaml_rocksdb",
        remote = "https://github.com/obazl/orocksdb",
        branch = "mina"
        ## TODO:
        # remote = "https://github.com/o1-labs/orocksdb",
        # branch = "mina"
    )

    maybe(
        git_repository,
        name = "ocaml_sodium",
        remote = "https://github.com/obazl/ocaml-sodium.git",
        branch = "bazel"
        ## TODO:
        # remote = "https://github.com/o1-labs/ocaml-sodium",
        # branch = "mina"
    )

    ################################################################
    ## opam pinned.  these are bazelized but the bazel code is not used
    # maybe(
    #     git_repository,
    #     name = "async_kernel",
    #     remote = "https://github.com/obazl/async_kernel",
    #     branch = ""
    # )
    # maybe(
    #     git_repository,
    #     name = "coda_base58",
    #     remote = "https://github.com/o1-labs/coda_base58",
    #     branch = "master"
    # )
    # maybe(
    #     git_repository,
    #     name = "ocaml_extlib",
    #     remote = "https://github.com/obazl/ocaml-extlib",
    #     branch = ""
    # )
    # maybe(
    #     git_repository,
    #     name = "rpc_parallel",
    #     remote = "https://github.com/o1-labs/rpc_parallel",
    #     branch = ""
    # )

################################################################
#######################
def ocaml_fetch_local_libs():

    native.local_repository( name = "graphql_ppx"  , path = "src/external/graphql_ppx")
    native.local_repository( name = "ocaml_rocksdb", path = "src/external/ocaml-rocksdb" )
    native.local_repository( name = "ocaml_sodium" , path = "src/external/ocaml-sodium" )
    native.local_repository( name = "ppx_optcomp"  , path = "src/external/ppx_optcomp")
    native.local_repository( name = "ppx_version"  , path = "src/external/ppx_version")
    native.local_repository( name = "snarky"       , path = "src/lib/snarky")

    ## opam-pinned repos, we do not need them in as bazel repos
    ## opam-pinned embedded (non-remoted) repos, we do not need them as bazel repos
    # local_repository( name = "async_kernel" , path = "src/external/async_kernel")
    # local_repository( name = "ocaml_extlib" , path = "src/external/ocaml_extlib")
    # local_repository( name = "rpc_parallel" , path = "src/external/rpc_parallel")

    # https://github.com/MinaProtocol/coda-automation.git
    # local_repository( name = "coda-automation" , path = "coda-automation")

    # https://github.com/bkase/tablecloth
    # local_repository( name = "tablecloth" , path = "frontend/wallet/tablecloth")

#######################
def ocaml_fetch_libs():

    ocaml_fetch_remote_libs()

    # ocaml_fetch_local_libs()
