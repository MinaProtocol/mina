Dump Blocks
===========

The `dump_blocks` utility is a tool for generating, transcribing, and
inspecting Mina blockchain blocks. It allows developers to convert blocks
between different formats (Sexp, JSON, Binary) or generate random sample blocks
for testing purposes.

This tool is particularly valuable for development and testing, as it makes it
easy to work with block data in various serialization formats and to generate
test data for block-related functionality.

Features
--------

- Generate random blocks with automatic creation of all required fields
- Convert blocks between different encoding formats
- Output full blocks or only precomputed values
- Optionally modify parent state hash in exported blocks
- Send output to files or standard output

Prerequisites
------------

This tool is primarily aimed at developers working with the Mina codebase.
You need either:

1. An existing block file in one of the supported formats (Sexp, JSON, Binary)
   that you want to convert to another format, or

2. No input file, in which case the tool will generate a random valid block.

Compilation
----------

To compile the `dump_blocks` executable, run:

```shell
$ dune build src/app/dump_blocks/dump_blocks.exe --profile=dev
```

The executable will be built at:
`_build/default/src/app/dump_blocks/dump_blocks.exe`

Usage
-----

The basic syntax for running `dump_blocks` is:

```shell
$ dump_blocks [OPTIONS]
```

### Options

- `-o <format>:<path>`: Specify output format and destination (can be repeated
  for multiple outputs). Formats are: `sexp`, `json`, or `bin`. A dash (`-`)
  denotes stdout. Example: `-o json:-`

- `-i <format>:<path>`: Specify input format and source. If omitted, a random
  block will be generated. Example: `-i sexp:block.sexp`

- `--full`: Use full blocks rather than just precomputed values. By default,
  the tool works with precomputed values.

- `--parent <statehash>` or `--parent-statehash <statehash>`: Specify a parent
  state hash to use in the output block.

### Default Behavior

If no output format is specified, the tool will output the block in both Sexp
and JSON formats to stdout.

If no input file is specified, the tool will generate one random block.

Examples
--------

Generate a random block and output to stdout in both Sexp and JSON formats
(default behavior):

```shell
$ dump_blocks
```

Generate a random block and save it in JSON format:

```shell
$ dump_blocks -o json:random_block.json
```

Convert a block from Sexp format to Binary format:

```shell
$ dump_blocks -i sexp:input_block.sexp -o bin:output_block.bin
```

Generate a random full block (not just precomputed values) and save it in
multiple formats:

```shell
$ dump_blocks --full -o sexp:block.sexp -o json:block.json
```

Generate a random block and set a specific parent state hash:

```shell
$ dump_blocks --parent 3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki \
    -o sexp:block_with_parent.sexp
```

Technical Notes
--------------

- The tool uses Mina's internal block generation and validation systems to create
  valid block structures.

- When generating random blocks, the tool currently doesn't include snark works
  or all types of transactions. These features may be added in future versions.

- The JSON encoding is not supported for full blocks, only for precomputed
  values.

- When transcribing between formats, the tool performs full deserialization and
  reserialization, which serves as a useful test of the serialization code.

- Randomly generated blocks are useful for testing when the block representation
  changes, as they can provide example data in the new format.