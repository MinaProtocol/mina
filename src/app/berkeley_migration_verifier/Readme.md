## Berkeley Verification app

Application for validating migrated archive schema content. Performed checks relates to:
- lack of orphaned and pending blocks in migrated db
- correct hashes for user and internal commands and block state hashes
- correctly migrated account related tables
- fork config comparison against replayer migrated output


### Usage

Basic usage :

```
mina-berkeley-migration-verifier --mainnet-archive-uri postgres://postgres:postgres@localhost:5432/source_archive --migrated-archive-uri postgres://postgres:postgres@localhost:5432/archive_migrated --migrated-replayer-output  migrated_replayer.json --fork-config-file fork_config_fixed.json 
```

where:

- **mainnet-archive-uri** is a connection string to original schema
- **migrated-archive-uri** is a connection string to already migrated schema
- **migrated-replayer-output** is an output for replayer on migrated schema
- **fork-config-file** is a state dump with forked ledger

### Dependencies

#### Postgres database

Depends on postgres database which need to be accessed from host which is running checks.

#### Compare replayer and fork files

Depends on script 'compare-replayer-and-fork-config.sh' which is downloaded from github from latest berkeley

#### File system

Depends on file system with correct permissions to create temporary folder in working directory