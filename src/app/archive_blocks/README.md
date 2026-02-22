Archive Blocks
=============

The `archive_blocks` application adds blocks in either "precomputed" or
"extensional" format to the archive database. This tool is crucial for
populating or synchronizing an archive database with historical blockchain data.

Prerequisites
------------

Before using `archive_blocks`, you need:

1. A running PostgreSQL database that has been initialized with the archive
   schema (see the instructions in `src/app/archive/README.md`).

2. Block data files in either precomputed or extensional format:
   - Precomputed blocks are stored in the bucket `mina_network_block_data`
     on Google Cloud Storage. Blocks are named NETWORK-HEIGHT-STATEHASH.json.
     Example: mainnet-100000-3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki.json.
   - Extensional blocks are typically extracted from other archive databases
     using the `extract_blocks` app.

3. Access to the Mina archive database. You'll need the connection URI in the
   format `postgres://<username>:<password>@<host>:<port>/<dbname>`.

Compilation
----------

To compile the `archive_blocks` executable, run:

```shell
$ dune build src/app/archive_blocks/archive_blocks.exe --profile=dev
```

Or use the following make command:

```shell
$ make archive_blocks
```

The executable will be built at:
`_build/default/src/app/archive_blocks/archive_blocks.exe`

Usage
-----

The basic syntax for running `archive_blocks` is:

```shell
$ archive_blocks --archive-uri URI [FLAGS] FILE1 [FILE2 ...]
```

### Required Parameters

- `--archive-uri URI`: URI for connecting to the archive database
  (e.g., postgres://username@localhost:5432/mina_archive)

### Block Format Flags (one is required)

- `--precomputed`: Specify that blocks are in precomputed format
- `--extensional`: Specify that blocks are in extensional format

### Optional Flags

- `--successful-files PATH`: Append the list of files that were processed
  successfully to the specified file
- `--failed-files PATH`: Append the list of files that failed to be processed
  to the specified file
- `--log-successful true/false`: Whether to log messages for files that were
  processed successfully (default: true)

### Arguments

- `FILES`: One or more JSON files containing block data

Examples
--------

Adding precomputed blocks from Google Cloud Storage:

```shell
$ archive_blocks --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --precomputed \
    --failed-files errors.txt \
    mainnet-100000-*.json
```

Adding extensional blocks exported from another archive:

```shell
$ archive_blocks --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --extensional \
    --successful-files processed.txt \
    --failed-files errors.txt \
    exported_blocks/*.json
```

Technical Notes
--------------

- As many blocks as are available can be added at a time, but all blocks
  must be in the same format (either all precomputed or all extensional).

- Except for blocks from the original mainnet, both precomputed and
  extensional blocks have a version in their JSON representation. That
  version must match the corresponding OCaml type in the code when this
  app was built.

- When adding blocks to the archive, the tool can handle versioned blocks
  through the `of_yojson_to_latest` conversion functions.

- To verify whether blocks were added successfully, you can query the archive
  database directly or examine the output files specified with the
  `--successful-files` and `--failed-files` flags.