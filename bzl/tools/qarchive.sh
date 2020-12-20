#!/bin/sh

## list all ocaml_archive and ppx_archive targets

bazel query "kind(\".*_archive rule\", $1//...:*)" --output label_kind
