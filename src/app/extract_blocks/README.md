extract_blocks
==============

The `extract_blocks` app pulls out individual blocks from an archive
database in "extensional" format. Such blocks can be added to other
archive databases using the `archive_blocks` app.

Blocks are extracted into files with name <state-hash>.json.

The app offers the choice to extract all canonical blocks, or a
subchain specified with starting state hash, or a subchain specified
with starting and ending state hashes.
