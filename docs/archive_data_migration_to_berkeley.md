# Abstract


To migrate the mainnet database into the Berkeley version, you will need two applications, which are shipped by MF/O1 Labs:


The first application, **berkeley-migration** application migrates as much data as possible from the mainnet database and downloads precomputed blocks to get the window density data. The accounts_accessed and accounts_created tables are not populated in this step. This application runs against the mainnet and the new database.


The second application, the **replayer app in migration mode**, replays the transactions in the partially migrated database and populates the accounts_accessed and accounts_created tables. This application also performs the checks performed by the standard replayer, except that ledger hashes are not checked because the hard fork ledger has greater depth, which results in different hashes. This application runs only against the new database.


These applications can be run in sequence to get a fully migrated database. They should be able to work incrementally so that part of the mainnet database can be migrated and, as new blocks are added to the mainnet, the new data in the database can be migrated.


To obtain that incrementality, the first application can look at the migrated database and determine the most recent migrated block. It can continue migrating starting at the next block in the mainnet data. The second application can use the checkpoint mechanism already in place for the replayer. A checkpoint file indicates the global slot since genesis for starting the replay and the ledger to use for that replay. The application writes new checkpoint files as it proceeds.


To take advantage of such incrementality, there can be a cron job that migrates a day's worth of data at a time (or some other interval). With the cron job in place, at the time of the actual hard fork, only a small amount of data will need to be migrated.


# Requirements


#### Database server
- Database: PostgreSQL database in version 15.0 or later.


### Migration Machine
- (Optional) Docker in version 23.0 or later
- If Docker is used, then any of the supported OS by Mina (Bullseye, Focal, or Buster)
at least 32 GB of RAM
- Gsutil application (from Google Cloud Suite) in version 5 or later


# Prerequisitives
#### (Optional) Download and Import Mainnet Dump
If you don't have an existing database with mainnet archive data, you can always download it from our Google Cloud bucket.


1. Download the Tar archive.


Dumps can be filtered by date and downloaded using curl:


`curl https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-{date}_0000.sql.tar.gz`
where
{date} can be replaced by the proper yyyy-dd-mm format. For example, for January 15, 2024: `2024-01-15`


> :warning: In some cases, the 0000 suffix in the date can be different (0001).


or using gsutils. For example:
```
gsutil cp gs://mina-archive-dumps/mainnet-archive-dump-2024-01-15* .
```


2. Untar package


3. Import dump


Assuming you are at the database server, you can import the database using command:


`psql -U {user} -f mainnet-archive-dump-{date}_0000.sql`


As a result, there will be an *archive_balances_migrated* schema created with the mainnet archive.


### Mainnet database state validation (optional but recommended)


The correct mainnet database state is crucial for a successful migration. Missing blocks or invalid ledger hashes are the most popular issues when dealing with the mainnet archive. It is recommended to verify the archive condition before starting the migration process.


##### Missing blocks issue


The deamon node unavailability causes, that the archive node can miss some of the blocks. Those blocks can be reapplied from precomputed blocks (if you are uploading them to Google Cloud) and preserve chain continuity. In order to automatically verify and patch missing blocks, you can use the [download_missing_blocks.sh]() script.


example of usage:


```
export BLOCKS_BUCKET="https://storage.googleapis.com/my_bucket_with_precomputed_blocks"


download-missing-blocks.sh mainnet {db_user} {db_password}
```


> :warning: **download-missing-blocks script assumes that you are running it from within the database host (it uses localhost as the database host). Also, mina-archive-blocks and mina-missing-blocks-auditor need to be installed. Everything is packed in our docker. minaprotocol/mina-rosetta:1.4.0-c980ba8-bullseye
**

##### Bad ledger hashes


In order to verify mainnet archive data, the replayer application was developed. You can run it against your existing mainnet database to verify the blockchain state.


> :warning: ** Running a replayer from scratch on a mainnet database can take up to a couple of days. We recommend splitting execution into smaller parts by using the checkpoint capabilities of the replayer.


In order to run replayer, the below command can be used:


```
mina-replayer --archive-uri {db_connection_string} --input-file reference_replayer_input.json --output-file reference_replayer_output.json --checkpoint-interval 100
```


> :warning: ** Please remember to run replayer from the mainnet version. It can be run from the Docker image:
minaprotocol/mina-archive:1.4.0-c980ba8-bullseye
**



### Gcloud bucket with mainnet precomputed blocks


Mainnet to Berkeley archive data migration requires access to precomputed blocks, which should be uploaded by daemons connected to Mainnet network. The Berkeley migration app uses the Gsutil app to download blocks. If you didn't store precomputed blocks during first phase of migration. If you don't have such setup you can use the Mina Foundation one:


`gs://mina_network_block_data`

However, we encourage collecting precomputed block by your own or other third parties to preserve idea of decentralization

### Migration applications


Migration applications are distributed as part of the Docker archive and daemon Dockers or Debian packages.

You can choose packages as you wish. Below are the commands that will help you install Debian packages or Docker images

#### Debian packages
```
CODENAME=bullseye
CHANNEL=unstable
# Berkeley nightly version
VERSION=2.0.0rampup8-berkeley-b9e1116


echo "deb [trusted=yes] http://packages.o1test.net $CODENAME $CHANNEL" | tee /etc/apt/sources.list.d/mina.list
apt-get update
apt-get install --allow-downgrades -y "mina-berkeley=$VERSION" "mina-replayer=$VERSION"
```


#### Dockers


The Berkeley migration app:

```
docker pull gcr.io/o1labs-192920/mina-berkeley:2.0.0rampup8-berkeley-b9e1116-bullseye-berkeley
```


Replayer:


```
docker pull gcr.io/o1labs-192920/mina-archive:2.0.0rampup8-berkeley-b9e1116-bullseye
```

#### Mainnet Genesis Ledger


#### Berkeley database schema files

# Migration Steps


The below steps assume that you have gathered the below information:


- mainnet database connection string: 

 In the form of `postgres://{user}:{password}@{host}:{port}/{schema}`
- migrated database connection string


In the form of `postgres://{user}:{password}@{host}:{port}/{schema}`

- bucket with precomputed blocks

In form of name like `mina_mainnet_blocks`

- genesis ledger: 

In form of path to file like `ledger/genesis_ledger.json`

- berkeley create schema files:

In form of path to file like `create_schema.sql` with `zkapp_tables.sql` located in the same folder

### Create a new schema for migration data.

```
psql {connection_string} -c CREATE DATABASE migrated;
psql {} -a -f create_schema.sql
```

### Download the mainnet genesis ledger and new schema files.

1. Download from sources

You can download mentioned resources directly from github by using below commands:

- mainnet genesis ledger

```
wget https://raw.githubusercontent.com/MinaProtocol/mina/rampup/genesis_ledgers/mainnet.json
```
- schema sources files

```

wget https://raw.githubusercontent.com/MinaProtocol/mina/rampup/src/app/archive/create_schema.sql

wget https://raw.githubusercontent.com/MinaProtocol/mina/rampup/src/app/archive/zkapp_tables.sql


```

2. download from packages resources

a) from installed debian packages

- mainnet genesis ledger

`/etc/mina/test/genesis_ledgers/mainnet.json`

- schema sources files

 `/etc/mina/rosetta/archive/create_schema.sql`
  
 `/etc/mina/rosetta/archive/zkapp_tables.sql`


b) from docker

```
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


```
mina-berkeley-migration --batch-size 100 --config-file genesis_ledgers/mainnet.json
--mainnet-archive-uri {mainnet_connection_string} --migrated-archive-uri {migrated_connection_string} --mainnet-blocks-bucket 
{bucket name}
```

### Migration Phase 2: Replayer in migration mode runs

a) Prepare replayer config file

Replayer config should contains mannet ledger as starting point

```
 jq '.ledger.accounts' mainnet.json | jq  '{genesis_ledger: {accounts: .}}' > replayer_input_config.json"

```

b) Execute import

```
mina-replayer --migration-mode --archive-uri {migrated_connection_string}  --input-file replayer_input_config.json --checkpoint-interval 100 --output-file  replayer_output.json 
```

## Example steps using Mina Foundation data

1. Download and Import dump

```
wget -c https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-2023-11-02_0000.sql.tar.gz

tar -xf mainnet-archive-dump-2023-11-02_0000.sql.tar.gz 

psql -U postgres -a -f mainnet-archive-dump-2023-11-02_0000.sql

```

2. Download migration software

```
CODENAME=bullseye
CHANNEL=unstable
# Berkeley nightly version
VERSION=2.0.0rampup8-berkeley-b9e1116


echo "deb [trusted=yes] http://packages.o1test.net $CODENAME $CHANNEL" | tee /etc/apt/sources.list.d/mina.list
apt-get update
apt-get install --allow-downgrades -y "mina-berkeley=$VERSION" "mina-replayer=$VERSION"
```


2. Create migrated schema

```
cd /etc/mina/rosetta/archive

psql  -U postgres -c "CREATE DATABASE berkeley_migrated;"

psql -U postgres -d berkeley_migrated -a -f create_schema.sql"

```

3. Phase 1:

```
mina-berkeley_migration.exe -- --batch-size 2 --config-file /etc/mina/genesis_ledgers/mainnet.json --mainnet-archive-uri postgres://postgres:postgres@localhost/archive_balances_migrated --migrated-archive-uri postgres://postgres:postgres@localhost/berkeley_migrated--mainnet-blocks-bucket mina_network_block_data 

```

4. Phase 2:

```

jq '.ledger.accounts' mainnet.json | jq  '{genesis_ledger: {accounts: .}}' > replayer_input_config.json"

mina-replayer -- --migration-mode --archive-uri postgres://postgres:postgres@localhost/ --input-file replayer_config_input.json --checkpoint-interval 100  --checkpoint-file-prefix migration
```


# How to Verify a Successful Run


O1 Labs and the Mina Foundation made every effort to provide reliable tools of high quality. However, it is not possible to eliminate all errors and test all possible mainnet archives variations. Therefore, below we present a checklist that contains major verifications, that you can perform after migration to ensure data correctness:


#### The Replayer from the mainnet version generates the same ledger hash as the migrated

Both replayer from mainnet and berkeley should generate the same ledger no matter we are using migrated or mainnet database. Mainnet Replayer can started with the same input config as Berkeley one. If you will ran replayer from mainnet version on mainnet archive it with `--output-config` option you can ganerate a reference replayer output which can be compared with migrated one 

#### All transaction (user command and internal command) hashes are left intact.

You can verify that user_command and internal_command tables have still the mainnet format of hashes (for example `CkpZirFuoLVV...`)


#### Parent-Child Block Relationship is Preserved

You can verify that for given block in migrated archive there is the same parent in mainnet archive (`state_hash` and `parent_hash` columns)

#### Account balances remain the same.

For given account there is the same balance in given block in mainnet and migrated datbase


# Notes on Migration approach


We are aware that the migration process can be very long (a couple of days). Therefore, we encourage using cron jobs, which will migrate data incrementally. The cron job will need access to Google Cloud buckets (or other storage):


a bucket to store migrated-so-far database dumps
a bucket to store checkpoint files


To prime the cron job, upload an initial database dump and an initial checkpoint file. Those can be created via these steps, run locally:


1. Download a mainnet archive dump and load it into PostgreSQL
2. Create a new, empty database using the new archive schema.
3. Run the first migration app against the mainnet and new databases.
4. Run the second migration app with the --checkpoint-interval set to some suitable value (perhaps 100) and start with the original mainnet ledger in the input file.
5. Use pg_dump to dump the migrated database and upload it.
6. Upload the most recent checkpoint file.


The cron job will perform these same steps in an automated fashion:


1. Pull the latest mainnet archive dump and load it into PostgresQL.
2. Pull the latest migrated database and load it into PostgreSQL.
3. Pull the latest checkpoint file.
4. Run the first migration app against the two databases.
5. Run the second migration app using the downloaded checkpoint file; the checkpoint interval should be smaller (perhaps 50). 6. Because there are typically only 200 or so blocks in a day.
7. Upload the migrated database.
8. Upload the most recent checkpoint file.


There should be monitoring of the cron job in case there are errors.


Just before the hard fork, the last few blocks can be migrated by running locally:


1. Download the mainnet archive data directly from the k8s PostgreSQL node, not from the archive dump, and load it into PostgreSQL.
2. Download the most recent migrated database and load it into PostgresQL.
3. Download the most recent checkpoint file.
4. Run the first migration application against the two databases.
5. Run the second migration application using the most recent checkpoint file.


It is worthwhile to perform these last steps as a dry run to make sure all goes well. Those steps can be run as many times as needed.



## Known problems


###### Berkeley migration app is consuming all of my resources.


When running full migration, you can stumble on memory leaks that prevent you from cleanly performing migration in one go. A machine with 64GB of RAM can be frozen after ~40k migrated blocks. Each 200 blocks inserted into the database increases the memory leak by 4–10 MB.


A potential workaround is to split migration into smaller parts using cron jobs or automation scripts.


Related Github issues:
- [#13714](https://github.com/MinaProtocol/mina/issues/13714)
-  [#14924](https://github.com/MinaProtocol/mina/issues/14924)


## FAQ


#### Migrated database is missing orphaned blocks


By design, Berkeley migration omits orphaned blocks and, by default, migrates only canonical blocks.


#### Migrated database missing pending blocks


By design, the Berkeley migration app does not migrate pending blocks. If you want to migrate pending blocks, please use the --end-global-slot parameter with the value of the requested slot. Please also ensure that pending blocks existing on requested slots as archive node converts old pending blocks to orphaned


#### Replayer in migration mode overrides my old checkpoints.


Replayer by default dumps the checkpoint to the current folder. All checkpoint files have a similar format:


`replayer-checkpoint-{number}.json.`


In order to modify the output folder and prefix, you can use the `--checkpoint-output-folder` and `--checkpoint-file-prefix` parameters to control the mentioned behavior.


#### Receipt chain hashes mismatch between Mainnet and Berkeley schemas

Receipt chain hashes are expressed in a new format in the Berkeley version. They contain the same value, though.

#### Replayer in migration mode exits the process in the middle of the run.

Most likely, there are some missing blocks in the mainnet database. Please ensure that you patched the Mainnet archive before the migration process. Alternatively you can provide `--continue-on-error` parameter 

#### How to migrate mainnet pending blocks

In first Phase of migration please use --end-global-slot parameter. 

In second Phase of migration please add property `target_epoch_ledgers_state_hash` with expected `state_hash` value 

```json
{
   "target_epoch_ledgers_state_hash":"{target_state_hash}",
   "genesis_ledger": "..."
}
```

#### How to start replayer migration from latest checkpoint

Instead of using mainnet ledger as input config. Just provide checkpoint as --input-config parameter

### Migration app parameters reference

For more advanced users and operators, below we present all the parameters that can influence the migration process:

##### Berkeley migration app
- Batch-size NN -  is used when downloading precomputed blocks. The bigger the buffer, the more precomputed blocks will be downloaded in a single fetch.
- End-global-slot NN (Optional) Last global slot since genesis to include in the migration (if omitted, only canonical blocks will be migrated)

##### Replayer in migration mode:
- checkpoint-interval NN - Write a checkpoint file for every NN slot.
- continue-on-error - Continue processing after errors
