# Best Tip Merger

The Best Tip Merger tool consolidates best tip history from multiple Mina daemon
log files into a rose tree representation. This utility helps visualize the
blockchain's fork structure across multiple nodes, making it easier to analyze
network consensus behavior and identify potential issues.

## Features

- Parses and aggregates best tip history from multiple Mina log files
- Constructs a forest of rose trees representing the network's fork structure
- Filters transitions by minimum peer count to focus on significant forks
- Provides both full and compact output formats
- Generates graphical visualizations of the blockchain tree structure
- Supports DOT format output for visualization with Graphviz

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina
- Log files containing best tip change events from Mina daemons

## Compilation

To build the utility:

```
dune build src/app/best_tip_merger/best_tip_merger.exe
```

## Usage

```
best_tip_merger --input-dir PATH --output-dir PATH [--output-format FORMAT] [--min-peers NUM]
```

### Arguments:

- `--input-dir` / `-input-dir`: Directory containing Mina best tip log files
- `--output-dir` / `-output-dir`: Directory to save the output files
- `--output-format` / `-output-format`: Format of block information (optional)
  - `Full`: Complete protocol state information
  - `Compact`: Only state hash, previous hash, blockchain length, and global slot
  - Default: `Compact`
- `--min-peers` / `-min-peers`: Minimum number of peers that must have seen a block
  for it to be included in the output (default: 1)

### Example:

```
_build/default/src/app/best_tip_merger/best_tip_merger.exe \
  --input-dir ./logs \
  --output-dir ./output \
  --output-format Compact \
  --min-peers 2
```

## Output

The tool generates several output files in the specified output directory:

1. `Result.txt`: JSON representation of the rose tree structure
2. `tree_*.dot`: DOT format files for visualization with Graphviz
3. `mina-best-tip-merger.log`: Tool execution log

To visualize the DOT files, use Graphviz:

```
dot -Tpng output/tree_0.dot -o output/tree_0.png
```

## Technical Notes

The Best Tip Merger works by parsing and aggregating best tip change events from
Mina daemon logs. It reconstructs the chain of blocks and their relationships
to create a comprehensive view of the blockchain's fork structure.

The tool represents the blockchain as a forest of rose trees, where:

- Each node represents a block state
- Each edge represents a parent-child relationship between blocks
- Multiple children of a node represent fork points
- Root nodes represent the earliest observed blocks in the logs

For each block, the tool tracks which peers observed it, allowing for filtering
based on a minimum peer count. This helps focus analysis on significant forks
that were seen by multiple nodes, while ignoring transient or isolated forks.

The visualization component uses the OCamlgraph library to generate DOT format
files, which can be rendered into graphical representations using Graphviz or
other compatible tools.