#!/bin/sh

## list all ppx_executable targets

bazel query "kind(\"ppx_executable rule\", $1//...:*)" --output label_kind
