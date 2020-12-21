#!/bin/sh

## print all dependencies of target. first arg is pkg or target, second is output option

## --output options:  https://docs.bazel.build/versions/master/query.html#output-formats
# some useful outputs:
#  build    prints out the build rule with macros etc. expanded
#  label
#  label_kind
#  package   normally all dep targets are printed, this just prints the pkgs
#  graph   - output can be piped into dot to produce a graph

OUTPUT=label_kind
if [[ ! -z $2 ]]
then
    OUTPUT=$2
fi

bazel query "deps($1)" --notool_deps --noimplicit_deps --output $OUTPUT
