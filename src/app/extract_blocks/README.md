Extract Blocks
=============

The `extract_blocks` application extracts individual blocks from a Mina archive
database in "extensional" format. These extracted blocks can then be imported
into other archive databases using the `archive_blocks` app. This enables
migration, backup, or transfer of blockchain data between different archive
instances.

Prerequisites
------------

Before using `extract_blocks`, you need:

1. A running PostgreSQL database that contains Mina archive data. This database
   should have been populated by running an archive node.

2. Access to the Mina archive database from which you want to extract blocks.
   You'll need the connection URI in the format 
   `postgres://<username>:<password>@<host>:<port>/<dbname>`.

3. An output directory where the extracted block files will be saved.

Compilation
----------

To compile the `extract_blocks` executable, run:

```shell
$ dune build src/app/extract_blocks/extract_blocks.exe --profile=dev
```

Or use the following make command:

```shell
$ make extract_blocks
```

The executable will be built at:
`_build/default/src/app/extract_blocks/extract_blocks.exe`

Usage
-----

The basic syntax for running `extract_blocks` is:

```shell
$ extract_blocks --archive-uri URI [OPTIONS]
```

### Required Parameters

- `--archive-uri URI`: URI for connecting to the archive database
  (e.g., postgres://username@localhost:5432/mina_archive)

### Block Selection Options (choose one)

- `--all-blocks`: Extract all blocks in the archive database
- `--end-state-hash HASH`: Extract a subchain ending with the specified state hash
- `--start-state-hash HASH --end-state-hash HASH`: Extract a subchain starting
  from one state hash and ending with another

### Optional Parameters

- `--output-folder PATH`: Directory where block files will be written
  (default: current directory)
- `--network NAME`: Network name which will be added as a prefix to each
  individual file
- `--include-block-height-in-name`: Include block height in the output filename

### Output Format

Blocks are extracted into individual JSON files with names following the pattern:
`[network-][height-]<state-hash>.json`

For example:
- Without options: `3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki.json`
- With network: `mainnet-3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki.json`
- With network and height: `mainnet-100000-3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki.json`

Examples
--------

Extract all blocks from an archive database:

```shell
$ extract_blocks --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --all-blocks \
    --output-folder "./extracted_blocks"
```

Extract a chain ending with a specific block:

```shell
$ extract_blocks --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --end-state-hash "3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki" \
    --output-folder "./extracted_blocks"
```

Extract a specific subchain between two blocks:

```shell
$ extract_blocks --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --start-state-hash "3NLMECimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDP9QTro" \
    --end-state-hash "3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki" \
    --network "mainnet" \
    --include-block-height-in-name \
    --output-folder "./extracted_blocks"
```

Technical Notes
--------------

- When extracting with `--end-state-hash` without specifying a start hash, the
  system will extract a chain from an unparented block (possibly the genesis
  block) to the specified end block.

- The extracted blocks are saved in "extensional" format, which includes all
  necessary data to reconstruct the block, including transactions, internal
  commands, and account information.

- Each extracted block file is versioned using the `Stable.Latest` versioning
  system, ensuring compatibility with the `archive_blocks` import tool.

- The tool will automatically collect and include all related data for each
  block, including:
  - User commands (transactions)
  - Internal commands
  - ZkApp commands
  - Accounts accessed
  - Accounts created
  - Tokens used