# mina go-libp2p helper

## libp2p_helper hints

If you are adding new `methodIdx` values, edit `generate_methodidx/main.go`
(search for `TypesAndValues`) with the names of the new values. Then, run `go
run generate_methodidx/main.go > libp2p_helper/methodidx_jsonenum.go`.

## building

### Makefile

```
$ make
$ make clean
```

### Bazel

```
$ bazel build src/generate_methodidx
$ bazel run src/generate_methodidx
$ bazel build src:codanet
$ bazel build src/libp2p_helper
```

#### using as an external repo

Add a repository rule to your root WORKSPACE(.bazel) file to import this repo.  For example, if you embed this repo as a git submodule:

```
local_repository(
    name = "libp2p_helper",
    path = "path/to/libp2p_helper"
)
```

Copy the contents of WORKSPACE.bazel to your root WORKSPACE(.bazel)
file. Change the line:

```
load("//:BUILD.bzl", "libp2p_fetch_go_rules", "libp2p_fetch_go_libs")
```

to use the fully-qualified label, e.g.

```
load("@libp2p//:BUILD.bzl", "libp2p_fetch_go_rules", "libp2p_fetch_go_libs")
```

#### maintenance

Install [Gazelle](https://github.com/bazelbuild/bazel-gazelle).

To UPDATE the bootstrap code responsible for loading Go deps, `cd
src/app/libp2p_helper` and then:

`$ bazel run //:gazelle -- update-repos -from_file=src/go.mod -to_macro WORKSPACE.bzl%libp2p_fetch_go_libs`

IMPORTANT: this will add a line, `load("@bazel_gazelle//:deps.bzl",
"go_repository")`, to the top of `WORKSPACE.bzl`. Delete this line.

Then update the build files: `$ bazel run //:gazelle update`

After runing the update you may need to restore some things:

* importpath="codanet" in `src:codanet` codanet go_library
* `"//src:codanet"` in the deps list of `src/libp2p_helper:libp2p_helper_lib`.

Run a git diff to see what's needed.

Go libs containing protobuf stuff: add `build_file_proto_mode =
"disable_global"` to the `go_library` rule in `//bzl/deps.bzl`. Also
add `# gazelle:proto disable_global` to the root WORKSPACE.bazel file.
See [Go Protocol buffers - avoiding
conflicts](https://github.com/bazelbuild/rules_go/blob/master/proto/core.rst#avoiding-conflicts): [Option 2: Use pre-generated .pb.go files](https://github.com/bazelbuild/rules_go/blob/master/proto/core.rst#option-2-use-pre-generated-pb-go-files).
for more info.
