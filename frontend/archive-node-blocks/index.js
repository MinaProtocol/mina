"use strict";

const { Client } = require("pg");
const format = require("pg-format");

const {
  getPublicKeysFromBlocks,
  getSnarkedLedgerHashFromBlocks,
  getEpochDataFromBlocks,
} = require("./parse");

let client = new Client({
  user: "postgres",
  host: "localhost",
  database: "archive",
  password: "foobar",
  port: 5432,
});

async function insertAllPublicKeys() {
  try {
    let publicKeys = getPublicKeysFromBlocks();
    const sql = format("INSERT INTO public_keys (value) VALUES %L", publicKeys);
    await client.query(sql);
    console.log("SUCCESS: public_keys ");
  } catch (e) {
    console.error("FAIL: public_keys", e);
  }
}

async function insertAllSNARKHashes() {
  try {
    let hashes = getSnarkedLedgerHashFromBlocks();
    const sql = format(
      "INSERT INTO snarked_ledger_hashes (value) VALUES %L",
      hashes
    );
    await client.query(sql);
    console.log("SUCCESS: snarked_ledger_hashes");
  } catch (e) {
    console.error("FAIL: snarked_ledger_hashes");
    console.error("FAIL: snarked_ledger_hashes", e);
  }
}

async function insertEpochData() {
  let epochs = getEpochDataFromBlocks();

  for (const epoch of epochs) {
    const getSnarkedHashSQL = format(
      "SELECT id FROM snarked_ledger_hashes WHERE value = %L",
      epoch.ledgerHashId
    );
    try {
      let { rows } = await client.query(getSnarkedHashSQL);
      if (rows.length) {
        const snarkHashId = parseInt(rows[0].id);
        const insertEpochSQL = `INSERT INTO epoch_data (seed, ledger_hash_id) VALUES ('${epoch.seed}', ${snarkHashId})`;
        await client.query(insertEpochSQL);
      }
    } catch (e) {
      console.error("FAIL: epoch_data", e);
    }
  }
  console.log("SUCCESS: epoch_data ");
}

async function run() {
  await client.connect();
  await insertAllPublicKeys();
  await insertAllSNARKHashes();
  await insertEpochData();
  client.end();
}

run();
