# Maintenance Utilities

## Dependency Analysis

Generate full dune transitive dependency graph with `./gen_deps.sh`. This script will output `deps.dot` and `deps.png`.

Once `deps.dot` is generated, you can narrow the dependency graph using `./narrow_deps.sh <node-id>`. You can inspect `deps.dot` to find the relevant node id you would like to narrow the graph to. Narrowing the graph will filter out the graph so that it only displays nodes which are dominated by the target, nodes that dominate the target, and all nodes in edges between these sets. For example, running `./narrow_deps.sh exe:./src/app/cli/src/dune:0` will generate a dependency graph for the `coda.exe` executable.
