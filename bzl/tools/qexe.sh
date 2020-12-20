#!/bin/sh

## list all ocaml_executable_executable targets

bazel query "kind(\"ocaml_executable rule\", $1//...:*)" --output label_kind
