missing_blocks_auditor
======================

The `missing_blocks_auditor` app looks for blocks without parent
blocks in an archive database.

The app also looks for blocks marked as pending that are lower (have a
lesser height) than the highest (most recent) canonical block. There
can be such blocks if blocks are added when there are missing blocks
in the database.
