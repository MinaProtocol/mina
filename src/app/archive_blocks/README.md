archive_blocks
==============

The `archive_blocks` app adds blocks in either "precomputed" or
"extensional" format to the archive database.

Precomputed blocks are stored in the bucket `mina_network_block_data`
on Google Cloud Storage. Blocks are named NETWORK-HEIGHT-STATEHASH.json.
Example: mainnet-100000-3NKLvMCimUjX1zjjiC3XPMT34D1bVQGzkKW58XDwFJgQ5wDQ9Tki.json.

Extensional blocks are extracted from other archive databases using
the `extract_blocks` app.

As many blocks as are available can be added at a time, but all blocks
must be in the same format.

Except for blocks from the original mainnet, both precomputed and
extensional blocks have a version in their JSON representation. That
version must match the corresponding OCaml type in the code when this
app was built.
