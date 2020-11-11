load("@bazel_tools//tools/build_defs/repo:git.bzl",
     "git_repository", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

def ocaml_bootstrap():
    """This bootstraps OCaml repos"""


    # https://github.com/bkase/tablecloth
