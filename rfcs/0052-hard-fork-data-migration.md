p## Summary
[summary]: #summary

This document describes a strategy for migrating mainnet archive data
to a new archive data for use at the hard fork.

## Motivation
[motivation]: #motivation

We wish to have archive data available from mainnet, so that the
archive database at the hard fork contains a complete history of
blocks and transactions.

## Detailed design
[detailed-design]: #detailed-design

There are significant differences between the mainnet and proposed
hard fork database schemas. Most notably, the `balances` table in the
mainnet schema no longer exists, and is replaced in the new schema
with the table `accounts_accessed`. The data in `accounts_accessed`
cannot be determined statically from the mainnet data.  There is also
a new table `accounts_created`, which might be determinable statically
The new schema also has the columns `min_window_density` and
`sub_window_densities` in the `blocks` table; those columns do not
exist in the `blocks` table for mainnet.

To populate the new database, there can be two applications:

- The first application migrates as much data as possible from the
mainnet database, and downloads precomputed blocks to get the window
density data. The `accounts_accessed` and `accounts_created` tables
are not populated in this step. This application runs against
the mainnet and the new database.

- The second application, based on the replayer app, replays the
transactions in the partially-migrated database, and populates the
`accounts_accessed` and `accounts_created` tables. This application
also performs the checks performed by the standard replayer, except
that ledger hashes are not checked, because the hard fork ledger has
greater depth, which results in different hashes. This application
runs only against the new database.

These applications can be run in sequence to get a fully-migrated
database. They should be able to work incrementally, so that part of
the mainnet database can be migrated and, as new blocks are added on
mainnet, the new data in the databannnnnse can be migrated.

To obtain that incrementality, the first application can look at the
migrated database, and determine the most recent migrated block. It
can continue migrating starting at the next block in the mainnet
data. The second application can use the checkpointing mechanism
already in place for the replayer. A checkpoint file indicates the
global slot since genesis for starting the replay, and the ledger to
use for that replay. The application writes new checkpoint files as it
proceeds.

To take advantage of such incrementality, there can be a cron job
that migrates a day's worth of data at a time (or some other interval).
With the cron job in place, at the time of the actual hard fork, only a small
amount of data will need to be migrated.

The cron job will need Google Cloud buckets (or other storage):

 - a bucket to store migrated-so-far database dumps
 - a bucket to store checkpoint files

To prime the cron job, upload an initial database dump, and an
initial checkpoint file. Those can be created via these steps,
run locally:
 - download a mainnet archive dump, and loading it into PostgreSQL
 - create a new, empty database using the new archive schema
 - run the first migration app against the mainnet and new databases
 - run the second migration app with the `--checkpoint-interval` set
    to some suitable value (perhaps 100), and starting with the
	original mainnet ledger in the input file
 - use `pg_dump` to dump the migrated database, upload it
 - upload the most recent checkpoint file

The cron job will perform these same steps in an automated fashion:
 - pull latest mainnet archive dump, load into PostgresQL
 - pull latest migrated database, load into PostgreSQL
 - pull latest checkpoint file
 - run first migration app against the two databases
 - run second migration app, using the downloaded checkpoint file; checkpoint interval
    should be smaller (perhaps 50), because there are typically only 200 or so blocks in a day
 - upload migrated database
 - upload most recent checkpoint file

There should be monitoring of the cron job, in case there are errors.

Just before the hard fork, the last few blocks can be migrated by running locally:
- download the mainnet archive data directly from the k8s PostgreSQL node, not from
  the archive dump, load it into PostgreSQL
- download the most recent migrated database, load it into PostgresQL
- download the most recent checkpoint file
- run the first migration application against the two database
- run the second migration application using the most recent checkpoint file

It is worthwhile to perform these last steps as a `dry run` to make sure all goes
well. Those steps can be run as many times as needed.

## Drawbacks
[drawbacks]: #drawbacks

If we want mainnet data to be available after the hard fork, there
needs to be migration of that data.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

It may be possible to add or delete columns in the original schema to
perform some of the migration without transferring data between
databases. It would still be necessary to add the windowing data from
precomputed blocks, and to have a separate pass to populate the
`accounts...` tables.

## Prior art
[prior-art]: #prior-art

There are preliminary implementations of the two applications:

- The first application is in branch `feature/berkeley-db-migrator`.
Downloading precomputed blocks appears to be the main bottleneck there,
so those blocks are downloaded in batches, which helps considerably.

- The second application is in branch `feature/add-berkeley-accounts-tables`.

There has been some local testing of these applications.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

How do we limit the migration to the final block of mainnet? There could be
flags to the migration apps to stop at a given state hash or height.

The second application populates the `accounts_created` table, but the
first application could do so, by examining the
`...account_creation_fee_paid` columns of the `blocks_user_commands`
table in the mainnet schema. The current implementation relies on
dynamic behavior, rather than static data, which overcomes potential
errors in that data.
