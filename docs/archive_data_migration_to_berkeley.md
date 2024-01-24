# Migrating Mainnet Database to Berkeley

Before you start planning the migration of your Mainnet database into the Berkeley version of the Mina network, read this document in entirety.

## Migration apps

Two applications are required to migrate the Mainnet database into the Berkeley version of the Mina network. 

These applications are shipped by MF/O1 Labs:

- **berkeley-migration**

  The berkeley-migration application migrates as much data as possible from the Mainnet database and downloads precomputed blocks to get the window density data. 
  
  This application runs against the Mainnet and the new database.

- **replayer app in migration mode**

  The replayer app in migration mode replays the transactions in the partially migrated database and populates the `accounts_accessed` and `accounts_created` tables. This application also performs the checks performed by the standard replayer, except that ledger hashes are not checked because the hard fork ledger has greater depth, which results in different hashes. This application runs only against the new database.

## How to migrate

To get a fully migrated database:

1. First, run the berkeley-migration application.
2. Next, run replayer app in migration mode. 

The applications are able to work incrementally so that part of the Mainnet database can be migrated and, as new blocks are added to the Mainnet, the new data in the database can be migrated.

To obtain that incrementality, the berkeley-migration application can look at the migrated database and determine the most recent migrated block. It can continue migrating starting at the next block in the Mainnet data. The replayer app in migration mode can use the checkpoint mechanism already in place for the replayer. A checkpoint file indicates the global slot since genesis for starting the replay and the ledger to use for that replay. The application writes new checkpoint files as it proceeds.

To take advantage of the incrementality, you can run a cron job that migrates a day's worth of data at a time (or some other interval). With the cron job in place, at the time of the actual hard fork, only a small amount of data will need to be migrated.

## Requirements

To successfully migrate the Mainnet database into the Berkeley version of the Mina network, the foundational requirements are:

### Database server

- Database: PostgreSQL database in version 15.0 or later.

### Migration machine

- (Optional) Docker in version 23.0 or later
- If Docker is used, then any of the supported OS by Mina (Bullseye, Focal, or Buster)
at least 32 GB of RAM
- gsutil application from Google Cloud Suite in version 5 or later

## Prerequisites

### (Optional) Download and import Mainnet dump

If you don't have an existing database with Mainnet archive data, you can always download it from our Google Cloud bucket. 

1. Download the Mainnet archive data using cURL or gsutils:

   - To use cURL to download the Tar archive:

   ```sh
   curl https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-{date}_0000.sql.tar.gz
   ```

   You can filter the dumps by date. Replace `{date}` using the required yyyy-dd-mm format. For example, for January 15, 2024: `2024-01-15`

   > :warning: In some cases, the 0000 suffix in the date might be different (0001).


   - To use gsutils, change the date in this example:
   
      ```sh
      gsutil cp gs://mina-archive-dumps/mainnet-archive-dump-2024-01-15* .
      ```

2. Extract the tar package.

3. Import the Mainnet archive dump into the Berkeley database.

   Run this command at the database server:

   `psql -U {user} -f mainnet-archive-dump-{date}_0000.sql`

   An *archive_balances_migrated* schema is created with the Mainnet archive.

### Validate the Mainnet database

The correct Mainnet database state is crucial for a successful migration. 

Missing blocks or invalid ledger hashes are the most frequent issues when dealing with the Mainnet archive. Although this step is optional, it is strongly recommended to verify the archive condition before you start the migration process.

### Known issues

## Missing blocks on archive node

The daemon node unavailability can cause the archive node to miss some of the blocks. 

If you are uploading the missing blocks to Google Cloud, the missing blocks can be reapplied from precomputed blocks () and preserve chain continuity. 

To automatically verify and patch missing blocks, use the [download_missing_blocks.sh]() script. Because the `download-missing-blocks` script uses localhost as the database host, you must run it from within the database host.

1. Install the required `mina-archive-blocks` and `mina-missing-blocks-auditor` scripts that are packed in the `minaprotocol/mina-rosetta:1.4.0-c980ba8-bullseye` Docker image.

2. Export the `BLOCKS_BUCKET`:

   ```sh
   export BLOCKS_BUCKET="https://storage.googleapis.com/my_bucket_with_precomputed_blocks"

3. Run the `mina-missing-blocks-auditor` script from the database host:

   ```sh
   download-missing-blocks.sh mainnet {db_user} {db_password}
   ```

##### Bad ledger hashes

To verify Mainnet archive data, the replayer application was developed. You must run the replayer application against your existing Mainnet database to verify the blockchain state.

To run replayer:

```sh
mina-replayer --archive-uri {db_connection_string} --input-file reference_replayer_input.json --output-file reference_replayer_output.json --checkpoint-interval 100
```

> :warning: Running a replayer from scratch on a Mainnet database can take up to a couple of days. The recommended best practice is to break the replayer into smaller parts by using the checkpoint capabilities of the replayer.

> :warning: You must run replayer from the Mainnet version. You can run it from the Docker image at minaprotocol/mina-archive:1.4.0-c980ba8-bullseye

### Google Cloud bucket with Mainnet precomputed blocks

The Mainnet to Berkeley archive data migration requires access to precomputed blocks that are uploaded by daemons connected to the Mainnet network. The Berkeley migration app uses the gsutil app to download blocks. If you didn't store precomputed blocks during first phase of migration, you can use the precomputed blocks provided by Mina Foundation:

`gs://mina_network_block_data`

The best practice is to collect precomputed blocks by yourself or by other third parties to preserve idea of decentralization. 

## Migration applications

Migration applications are distributed as part of the Docker archive, daemon Dockers, or Debian packages.

You can choose packages as you wish. The following commands help you install Debian packages or Docker images.

### Debian packages

```
CODENAME=bullseye
CHANNEL=unstable
# Berkeley nightly version
VERSION=2.0.0rampup8-berkeley-b9e1116

echo "deb [trusted=yes] http://packages.o1test.net $CODENAME $CHANNEL" | tee /etc/apt/sources.list.d/mina.list
apt-get update
apt-get install --allow-downgrades -y "mina-berkeley=$VERSION" "mina-replayer=$VERSION"
```

### Docker images

The Berkeley migration app:

```
docker pull gcr.io/o1labs-192920/mina-berkeley:2.0.0rampup8-berkeley-b9e1116-bullseye-berkeley
```

Replayer:

```
docker pull gcr.io/o1labs-192920/mina-archive:2.0.0rampup8-berkeley-b9e1116-bullseye
```

## Mainnet Genesis Ledger

## Berkeley database schema files


## Migration Steps

### 1. Before you start the migration, gather the information:

- Mainnet database connection string: 

 In the form of `postgres://{user}:{password}@{host}:{port}/{schema}`

- Migrated database connection string

   In the form of `postgres://{user}:{password}@{host}:{port}/{schema}`

- Bucket with precomputed blocks

   In form of name, like `mina_mainnet_blocks`

- Genesis ledger: 

   In form of path to file, like `ledger/genesis_ledger.json`

- Berkeley create schema files:

   In form of path to file, like `create_schema.sql` with `zkapp_tables.sql` located in the same folder

### 2. Create a new schema for migration data.

   ```
   psql {connection_string} -c CREATE DATABASE migrated;
   psql {} -a -f create_schema.sql
   ```

### 3. Download the Mainnet genesis ledger and new schema files

1. Download from sources:

   To the resources directly from GitHub, using the following commands:

   - Mainnet genesis ledger

   ```
   wget https://raw.githubusercontent.com/MinaProtocol/mina/rampup/genesis_ledgers/mainnet.json
   ```

   - schema sources files

   ```sh
   wget https://raw.githubusercontent.com/MinaProtocol/mina/rampup/src/app/archive/create_schema.sql

   wget https://raw.githubusercontent.com/MinaProtocol/mina/rampup/src/app/archive/zkapp_tables.sql
   ```

2. Download resources from packages or from Docker:

   To download from installed debian packages:

   - mainnet genesis ledger

   `/etc/mina/test/genesis_ledgers/mainnet.json`

   - schema sources files

   `/etc/mina/rosetta/archive/create_schema.sql`
   
   `/etc/mina/rosetta/archive/zkapp_tables.sql`

   To download resources from Docker:

   ```sh
   docker pull gcr.io/o1labs-192920/mina-daemon:2.0.0rampup8-berkeley-4422a5b-bullseye-berkeley

   id=$(docker create gcr.io/o1labs-192920/mina-daemon:2.0.0rampup8-berkeley-4422a5b-bullseye-berkeley)

   # mainnet genesis ledger

   docker cp $id:/etc/mina/test/genesis_ledgers/mainnet.json - > mainnet.json

   #schema sources files

   docker cp $id:/etc/mina/rosetta/archive/create_schema.sql - > create_schema.sql

   docker cp $id:/etc/mina/rosetta/archive/zkapp_tables.sql - > zkapp_tables.sql

   docker rm -v $id
   ```

### Migration Phase 1: Berkeley migration app run

Run the provided Berkeley migration application:

```
mina-berkeley-migration --batch-size 100 --config-file genesis_ledgers/mainnet.json
--mainnet-archive-uri {mainnet_connection_string} --migrated-archive-uri {migrated_connection_string} --mainnet-blocks-bucket 
{bucket name}
```

### Migration Phase 2: Replayer in migration mode runs

Run the provided replayer app in migration mode:

1. Prepare replayer config file.

   Replayer config must contain the Mainnet ledger as starting point:

   ```
   jq '.ledger.accounts' mainnet.json | jq  '{genesis_ledger: {accounts: .}}' > replayer_input_config.json"

   ```

2. Run the import in migration mode:

   ```
   mina-replayer --migration-mode --archive-uri {migrated_connection_string}  --input-file replayer_input_config.json --checkpoint-interval 100 --output-file  replayer_output.json 
   ```

### Example steps using Mina Foundation data

1. Download and import archive dump:

   ```sh
   wget -c https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-2023-11-02_0000.sql.tar.gz

   tar -xf mainnet-archive-dump-2023-11-02_0000.sql.tar.gz 

   psql -U postgres -a -f mainnet-archive-dump-2023-11-02_0000.sql
   ```

2. Download migration software:

   ```
   CODENAME=bullseye
   CHANNEL=unstable
   # Berkeley nightly version
   VERSION=2.0.0rampup8-berkeley-b9e1116


   echo "deb [trusted=yes] http://packages.o1test.net $CODENAME $CHANNEL" | tee /etc/apt/sources.list.d/mina.list
   apt-get update
   apt-get install --allow-downgrades -y "mina-berkeley=$VERSION" "mina-replayer=$VERSION"
   ```

3. Create migrated schema:

   ```sh
   cd /etc/mina/rosetta/archive

   psql  -U postgres -c "CREATE DATABASE berkeley_migrated;"

   psql -U postgres -d berkeley_migrated -a -f create_schema.sql"
   ```

4. Phase 1:

   ```sh
   mina-berkeley_migration.exe -- --batch-size 2 --config-file /etc/mina/genesis_ledgers/mainnet.json --mainnet-archive-uri postgres://postgres:postgres@localhost/archive_balances_migrated --migrated-archive-uri postgres://postgres:postgres@localhost/berkeley_migrated--mainnet-blocks-bucket mina_network_block_data 
   ```

4. Phase 2:

   ```sh
   jq '.ledger.accounts' mainnet.json | jq  '{genesis_ledger: {accounts: .}}' > replayer_input_config.json"

   mina-replayer -- --migration-mode --archive-uri postgres://postgres:postgres@localhost/ --input-file replayer_config_input.json --checkpoint-interval 100  --checkpoint-file-prefix migration
   ```

## How to Verify a Successful Migration

o1Labs and the Mina Foundation make every effort to provide reliable tools of high quality. However, it is not possible to eliminate all errors and test all possible Mainnet archives variations. 

Follow this checklist to perform major verifications after migration to ensure data correctness. 

#### The Replayer from the Mainnet version generates the same ledger hash as the migrated

Ensure that replayer from Mainnet and berkeley generate the same ledger for the migrated and the Mainnet database. 

1. To verify, start the Mainnet replayer with the same input config as Berkeley. 

2. When you run replayer from Mainnet version on Mainnet, archive it with the `--output-config` option to generate a reference replayer output that can be compared with the migrated replayer output.

#### All transaction (user command and internal command) hashes are left intact

Verify that the `user_command` and `internal_command` tables have the Mainnet format of hashes. For example, `CkpZirFuoLVV...`.

#### Parent-child block relationship is preserved

Verify that a given block in the migrated archive has the same parent in the Mainnet archive (`state_hash` and `parent_hash` columns).

#### Account balances remain the same

Verify the same balance exists for a given block in Mainnet and migrated databases.

## Notes on migration approach

We are aware that the migration process can be very long, (a couple of days). Therefore, we encourage using cron jobs that migrate data incrementally. The cron job requires access to Google Cloud buckets (or other storage):

- A bucket to store migrated-so-far database dumps
- A bucket to store checkpoint files

To prime the cron job, upload an initial database dump and an initial checkpoint file. 

To create the files, run these steps locally:

1. Download a Mainnet archive dump and load it into PostgreSQL.
2. Create a new, empty database using the new archive schema.
3. Run the berkeley-migration app against the Mainnet and new databases.
4. Run the replayer app in migration mode with the --checkpoint-interval set to some suitable value (perhaps 100) and start with the original Mainnet ledger in the input file.
5. Use pg_dump to dump the migrated database and upload it.
6. Upload the most recent checkpoint file.

The cron job performs the same steps in an automated fashion:

1. Pulls the latest Mainnet archive dump and loads it into PostgresQL.
2. Pulls the latest migrated database and loads it into PostgreSQL.
3. Pulls the latest checkpoint file.
4. Runs the berkeley-migration app against the two databases.
5. Runs the replayer app in migration mode using the downloaded checkpoint file; the checkpoint interval should be smaller (perhaps 50) because there are typically only 200 or so blocks in a day.
7. Uploads the migrated database.
8. Uploads the most recent checkpoint file.

Be sure to monitor the cron job in case there are errors.

Just before the hard fork, migrate the last few blocks by running locally:

1. Download the Mainnet archive data directly from the k8s PostgreSQL node, not from the archive dump, and load it into PostgreSQL.
2. Download the most recent migrated database and load it into PostgresQL.
3. Download the most recent checkpoint file.
4. Run the berkeley-migration app against the two databases.
5. Run the replayer app in migration mode using the most recent checkpoint file.

It is worthwhile to perform these last steps as a dry run to make sure all goes well. You can run these steps as many times as needed.

### Known migration problems

#### Berkeley migration app is consuming all of my resources

When running a full migration, you can stumble on memory leaks that prevent you from cleanly performing the migration in one pass. A machine with 64 GB of RAM can be frozen after ~40k migrated blocks. Each 200 blocks inserted into the database increases the memory leak by 4–10 MB.

A potential workaround is to split migration into smaller parts using cron jobs or automation scripts.

Related Github issues:
- [#13714](https://github.com/MinaProtocol/mina/issues/13714)
- [#14924](https://github.com/MinaProtocol/mina/issues/14924)

## FAQ

#### Migrated database is missing orphaned blocks

By design, Berkeley migration omits orphaned blocks and, by default, migrates only canonical blocks.

#### Migrated database missing pending blocks

By design, the Berkeley migration app does not migrate pending blocks. If you want to migrate pending blocks, use the `--end-global-slot` parameter with the value of the requested slot. Ensure that pending blocks that exist on requested slots as archive node convert the old pending blocks to orphaned blocks.

#### Replayer in migration mode overrides my old checkpoints

Replayer by default dumps the checkpoint to the current folder. All checkpoint files have a similar format:

`replayer-checkpoint-{number}.json.`

To modify the output folder and prefix, you can use the `--checkpoint-output-folder` and `--checkpoint-file-prefix` parameters to prevent override of old checkpoints.

#### Receipt chain hashes mismatch between Mainnet and Berkeley schemas

Receipt chain hashes are expressed in a new format in the Berkeley version. They contain the same value, though.

#### Replayer in migration mode exits the process in the middle of the run

Most likely, there are some missing blocks in the Mainnet database. Ensure that you patched the Mainnet archive before the migration process. Alternatively, you can provide `--continue-on-error` parameter.

#### How to migrate Mainnet pending blocks

In the first phase of migration use the `--end-global-slot` parameter. 

In the second phase of migration, add property `target_epoch_ledgers_state_hash` with the expected `state_hash` value:

```json
{
   "target_epoch_ledgers_state_hash":"{target_state_hash}",
   "genesis_ledger": "..."
}
```

#### How to start replayer migration from latest checkpoint

Instead of using Mainnet ledger as input config, provide the checkpoint for the `--input-config` parameter.

### Migration app parameters reference

For more advanced users and operators, all the parameters that can influence the migration process are listed here:

##### Berkeley migration app

- Batch-size NN is used when downloading precomputed blocks. The bigger the buffer, the more precomputed blocks are downloaded in a single fetch.
- End-global-slot NN (Optional) Last global slot since genesis to include in the migration (if omitted, the default is to migrate only canonical blocks).

##### Replayer in migration mode

- checkpoint-interval NN - Write a checkpoint file for every NN slot.
- continue-on-error - Continue processing after errors
