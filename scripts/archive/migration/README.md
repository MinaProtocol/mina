## Berkeley Migration script

Migration Script which simplify migration process by wrapping all 3 phases and 2 steps per each phase into single script. We try to make it as verbose as possible and give user a hints why some parameter is needed and how to obtain it

### Usage

Script has 3 subcommands

- initial - for running first phase of migration where migrated db is an empty schema
- incremental - for running second phase of migration where incrementally we migrated current mainnet
- final - for migrating data till fork point

### Dependencies 

Script is very verbose and inform when any of below dependency is missing. For documentation purposes we list them here:

#### General

- jq 
- wget
- postgres and psql
- gsutil

#### Mina related 

All mina related apps can be either downloaded in debian or docker. Advanced users can build them locally, but please remember to rename them and use `DUNE_PROFILE=berkeley_archive_migration` env variable when building berkeley_migration

- mina-berkeley-migration
- mina-berkeley-migration-verifier
- mina-migration-replayer


### Testing 

The best approach to learn about the tool is to start testing it. Below we present end to end testing cycle for migration script based on umt data

#### Data preparation

Test data is available in one of o1labs bucket : `gs://umt-migration-historical-data`.
Since berkeley migration script supports all berkeley migration phases. We need to have 3 dumps which represents all 3 stages. Beside that we need a ledger file and precomputed blocks (which are stored in different bucket). Below steps required before testing script:

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
./scripts/archive/migration/berkeley_migration.sh initial -g  ../../umt_testing/o1labs-umt-pre-fork-run-1-ledger.json -s postgres://postgres:postgres@localhost:5432/umt_testing_initial -t postgres://postgres:postgres@localhost:5432/migrated -b mina_network_block_data -bs 1000 -n o1labs-umt-pre-fork-run-1
```

this command should output migration-replayer-XXX.json which should be used in next run

#### Incremental migration

./scripts/archive/migration/berkeley_migration.sh incremental -g  ../../umt_testing/o1labs-umt-pre-fork-run-1-ledger.json -s postgres://postgres:postgres@localhost:5432/umt_testing_increment -t postgres://postgres:postgres@localhost:5432/migrated -b mina_network_block_data -bs 50 -n o1labs-umt-pre-fork-run-1 -r migration-checkpoint-597.json 

where:

migration-checkpoint-597.json - is a last checkpoint from initial run

#### Final migration

```
./scripts/archive/migration/berkeley_migration.sh final -g  ../../umt_testing/o1labs-umt-pre-fork-run-1-ledger.json -s postgres://postgres:postgres@localhost:5432/umt_testing_final -t postgres://postgres:postgres@localhost:5432/migrated -b mina_network_block_data -bs 50 -n o1labs-umt-pre-fork-run-1 -r migration-checkpoint-2381.json -fc ../../umt_testing/fork-umt-02-29-2024.json -f 3NLnD1Yp4MS9LtMXikD1YyySZNVgCXA82b5eQVpmYZ5kyTo4Xsr7
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
and `migration-checkpoint-2381.json` was last checkpoint from incremental run