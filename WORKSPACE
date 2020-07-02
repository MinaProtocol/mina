load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")

################################################################
#### OCAML ####
git_repository(
    name = "obazl",
    remote = "https://github.com/mobileink/obazl",
    branch = "master",
    # commit = "feef897197b36b14b65ffdf00b9badcbdb8f42f4",
    # shallow_since = "1593623637 -0500"
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
