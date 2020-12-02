"use strict";

const { Client } = require("pg");
const format = require("pg-format");

const {
  getPublicKeysFromBlocks,
  getSnarkedLedgerHashFromBlocks,
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
    let { rows } = await client.query(sql);
    console.log(rows);
  } catch (e) {
    console.error(e);
  }
}

async function insertAllSNARKHashes() {
  try {
    let hashes = getSnarkedLedgerHashFromBlocks();
    const sql = format(
      "INSERT INTO snarked_ledger_hashes (value) VALUES %L",
      hashes
    );
    let { rows } = await client.query(sql);
    console.log(rows);
  } catch (e) {
    console.error(e);
  }
}

// Add all public keys in the block data to postgres
async function run() {
  await client.connect();
  await insertAllPublicKeys();
  await insertAllSNARKHashes();
  client.end();
}

run();
