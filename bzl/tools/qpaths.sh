#!/bin/sh

## print dependency paths between two targests

bazel query "allpaths($1, $2)" --notool_deps --output graph --noimplicit_deps
