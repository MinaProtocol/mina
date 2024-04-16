## Berkeley Migration script

Migration Script simplifies the migration process by wrapping all 3 phases and 2 steps per each phase into single script. We try to make it as verbose as possible and give the user a hints why some parameters are needed and how to obtain them.

### Usage

Script has 3 subcommands

- initial - for running the first phase of migration, where the migrated database is an empty schema
- incremental - for running the second phase of migration, where incrementally we migrated the current mainnet
- final - for migrating data to the fork point

### Dependencies 

The script is very verbose and informs when any of the below dependencies are missing. For documentation purposes, we list them here:

#### General

- jq 
- wget
- postgres and psql
- gsutil

#### Mina related 

All mina related apps can be either downloaded in debian or docker. Advanced users can build them locally, but please remember to rename them

- mina-berkeley-migration
- mina-berkeley-migration-verifier
- mina-migration-replayer

### Testing 

The best approach to learn about the tool is to start testing it. Below, we present the end-to-end testing cycle for migration script based on umt data

#### Data preparation

Test data is available in one of o1labs bucket : `gs://umt-migration-historical-data`.
Since berkeley migration script supports all Berkeley migration phases. We need to have 3 dumps that represent all 3 stages. Besides that, we need a ledger file and precomputed blocks (which are stored in different buckets). Below are the steps required before testing the script:

1. Download and import initial dump:
```
    gsutil cp gs://umt-migration-historical-data/o1labs-umt-pre-fork-run-1-archive-dump-2024-02-26_0000.sql.tar.gz .

    tar -xzf o1labs-umt-pre-fork-run-1-archive-dump-2024-02-26_0000.sql.tar.gz o1labs-umt-pre-fork-run-1-archive-dump-2024-02-26_0000.sql

    psql -U postgres -c "create database umt_testing_initial"
    sed -i 's/archive/umt_testing_initial/g' o1labs-umt-pre-fork-run-1-archive-dump-2024-02-26_0000.sql

    psql -U postgres -d umt_testing_initial < o1labs-umt-pre-fork-run-1-archive-dump-2024-02-26_0000.sql
```


2. Download and import incremental dump:
```
    gsutil cp gs://umt-migration-historical-data/o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1200.sql.tar.gz .

    tar -xzf o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1200.sql.tar.gz o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1200.sql

    psql -U postgres  -c "create database umt_testing_increment"
    sed -i 's/archive/umt_testing_increment/g' o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1200.sql

    psql -U postgres -d umt_testing_increment < o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1200.sql
```


3. Download and import final dump:
```
    gsutil cp gs://umt-migration-historical-data/o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1516.sql.tar.gz .

    tar -xzf o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1516.sql.tar.gz o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1516.sql

    psql -U postgres  -c "create database umt_testing_final"
    sed -i 's/archive/umt_testing_final/g' o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1516.sql

    psql -U postgres -d umt_testing_final < o1labs-umt-pre-fork-run-1-archive-dump-2024-02-29_1516.sql
```


4. Create an empty berkeley dump:
```
    cd src/app/archive

    psql -U postgres -c "create database migrated"

    psql -U postgres -d "migrated" < create_schema.sql

```

5. Download Genesis ledger file
```
    gsutil cp gs://umt-migration-historical-data/o1labs-umt-pre-fork-run-1-ledger.json .
```

6. Download fork config file
```
    gsutil cp gs://umt-migration-historical-data/fork-umt-02-29-2024.json .
```

#### Initial migration

```
mina-berkeley-migration-script initial -g  ../../umt_testing/o1labs-umt-pre-fork-run-1-ledger.json -s postgres://postgres:postgres@localhost:5432/umt_testing_initial -t postgres://postgres:postgres@localhost:5432/migrated -b mina_network_block_data -bs 1000 -n o1labs-umt-pre-fork-run-1
```

This command should output migration-replayer-XXX.json which should be used in the next run

#### Incremental migration

```
mina-berkeley-migration-script incremental -g  ../../umt_testing/o1labs-umt-pre-fork-run-1-ledger.json -s postgres://postgres:postgres@localhost:5432/umt_testing_increment -t postgres://postgres:postgres@localhost:5432/migrated -b mina_network_block_data -bs 50 -n o1labs-umt-pre-fork-run-1 -r migration-checkpoint-597.json
```

where:

migration-checkpoint-597.json - is the last checkpoint from initial run

#### Final migration

```
mina-berkeley-migration-script final -g  ../../umt_testing/o1labs-umt-pre-fork-run-1-ledger.json -s postgres://postgres:postgres@localhost:5432/umt_testing_final -t postgres://postgres:postgres@localhost:5432/migrated -b mina_network_block_data -bs 50 -n o1labs-umt-pre-fork-run-1 -r migration-checkpoint-2381.json -fc ../../umt_testing/fork-umt-02-29-2024.json
```

where `3NLnD1Yp4MS9LtMXikD1YyySZNVgCXA82b5eQVpmYZ5kyTo4Xsr7` was extracted from fork config file:

```
{
  "proof": {
    "fork": {
      "state_hash": "3NLnD1Yp4MS9LtMXikD1YyySZNVgCXA82b5eQVpmYZ5kyTo4Xsr7",
      "blockchain_length": 1276,
      "global_slot_since_genesis": 2856
    }
  },
```
and `migration-checkpoint-2381.json` was the last checkpoint from the incremental run
