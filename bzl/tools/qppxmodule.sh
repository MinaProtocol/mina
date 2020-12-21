#!/bin/sh

## list all packages containing ppx_executable targets

bazel query "kind(\"ppx_module rule\", $1//...:*)" --output package
