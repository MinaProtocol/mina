#!/bin/sh

## browse code from BUILD file for target
## this will show the build code after analysis, with macros expanded etc.

bazel query "deps($1)" --noimplicit_deps --output=build
