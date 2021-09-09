# Archive Node Resurrection

This project is responsible for taking a JSON file representing blocks and converting the data into the Archive node schema for insertion. The current data provided was from a Gareth's Mongo database which is used for minaexplorer.com

## Resources Explained

Please download the resouces needed here:
`https://drive.google.com/file/d/1OjV40QTZDbUnin81vywBLUGhfMW8JU3d/view?usp=sharing`

Note: You must have a o(1) labs email to access.

`pg_dump_archive_empty`

This is a Postgres dump of the Archive node before it crashed and couldn't resync. The contents of the dump has been modified so it only includes the first block and other related information in other tables. This is so we can reset a test database to the genesis block and then restart the resurrection process.

`pg_dump_archive`

This is the intact Postgres dump of the Archive node up until it crashed (block height 307). This is used to compare the output of the resurrected database for correctness.

`blocks.json`

This is the block dataset used to resurrect the Archive node.

`test-blocks.json`

This is a smaller dataset of the block data which is used to develop against.

## Run

- Create the database and import the `pg_dump_archive_empty` dump by running the following:
  ` . make-postgres-db.sh`

- Run the node script by running the following:
  `node index.js`

- Clean the database by running the following:
  `. drop-db.sh`
