"use strict";

const { Client } = require("pg");
const format = require("pg-format");

const {
  getPublicKeysFromBlocks,
  getSnarkedLedgerHashFromBlocks,
  getEpochDataFromBlocks,
  getBlockDataFromBlocks,
} = require("./parse");

let client = new Client({
  user: "postgres",
  host: "localhost",
  database: "archive_backup",
  password: "foobar",
  port: 5432,
});

async function insertAllPublicKeys() {
  try {
    let publicKeys = getPublicKeysFromBlocks();
    const insertPublicKeys = format(
      "INSERT INTO public_keys (value) VALUES %L",
      publicKeys
    );
    await client.query(insertPublicKeys);
    console.log("SUCCESS: public_keys ");
  } catch (e) {
    console.error("FAIL: public_keys", e);
  }
}

async function insertAllSNARKHashes() {
  try {
    let hashes = getSnarkedLedgerHashFromBlocks();
    const insertSnarkLedgers = format(
      "INSERT INTO snarked_ledger_hashes (value) VALUES %L",
      hashes
    );
    await client.query(insertSnarkLedgers);
    console.log("SUCCESS: snarked_ledger_hashes");
  } catch (e) {
    console.error("FAIL: snarked_ledger_hashes", e);
  }
}

async function insertEpochData() {
  let epochs = getEpochDataFromBlocks();

  for (const epoch of epochs) {
    const getSnarkedHashId = format(
      "SELECT id FROM snarked_ledger_hashes WHERE value = %L",
      epoch.ledgerHash
    );
    try {
      let { rows } = await client.query(getSnarkedHashId);
      if (rows.length) {
        const snarkHashId = parseInt(rows[0].id);
        const insertEpochData = `INSERT INTO epoch_data (seed, ledger_hash_id) VALUES ('${epoch.seed}', ${snarkHashId})`;
        await client.query(insertEpochData);
      }
    } catch (e) {
      console.error("FAIL: epoch_data", e);
    }
  }
  console.log("SUCCESS: epoch_data ");
}

async function insertBlockData() {
  let blocks = getBlockDataFromBlocks();

  for (const block of blocks) {
    const getParentBlockId = format("SELECT count(id) as id FROM blocks");

    const getCreatorId = format(
      "SELECT id from public_keys WHERE value = %L",
      block.creatorPK
    );

    const getSnarkedLedgerHashId = format(
      "SELECT id FROM snarked_ledger_hashes WHERE value = %L",
      block.snarkedLedgerHash
    );

    const getStakingEpochDataId = `SELECT id FROM epoch_data WHERE seed = '${block.stakingEpochDataSeed}'`;

    const getNextEpochDataId = `SELECT id FROM epoch_data WHERE seed = '${block.nextEpochDataSeed}'`;

    try {
      let parentBlockId = await client.query(getParentBlockId);

      let creatorId = await client.query(getCreatorId);

      let snarkLedgerHashId = await client.query(getSnarkedLedgerHashId);

      let stakingEpochDataId = await client.query(getStakingEpochDataId);

      let nextEpochDataId = await client.query(getNextEpochDataId);

      const insertBlocks = `
      INSERT INTO blocks (
        state_hash,
        parent_id,
        creator_id,
        snarked_ledger_hash_id,
        staking_epoch_data_id,
        next_epoch_data_id,
        ledger_hash,
        height,
        global_slot,
        timestamp
        )
        VALUES (
          '${block.stateHash}',
           ${parentBlockId.rows[0].id},
           ${creatorId.rows[0].id},
           ${snarkLedgerHashId.rows[0].id},
           ${stakingEpochDataId.rows[0].id},
           ${nextEpochDataId.rows[0].id},
           '${block.stagedLedgerHash}',
           ${block.height},
           ${block.globalSlot},
           ${block.dateTime}
        )`;
      await client.query(insertBlocks);
    } catch (e) {
      console.error("FAIL: blocks", e);
    }
  }
  console.log("SUCCESS: blocks");
}

async function run() {
  await client.connect();
  await insertAllPublicKeys();
  await insertAllSNARKHashes();
  await insertEpochData();
  await insertBlockData();
  client.end();
}

run();
