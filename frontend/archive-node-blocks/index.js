"use strict";

const { Client } = require("pg");
const format = require("pg-format");
const fs = require("fs");

const blocksFile = "blocks.json";

let client = new Client({
  user: "postgres",
  host: "localhost",
  database: "archive",
  password: "foobar",
  port: 5432,
});

async function insertAllPublicKeys() {
  const blocks = JSON.parse(fs.readFileSync(blocksFile, "utf8"));

  const getPublicKeysFromBlocks = () => {
    let public_keys = new Set();
    blocks.forEach((block) => {
      const creatorPK = block?.creator;
      if (creatorPK) {
        public_keys.add(creatorPK);
      }
      const coinbaseReceiverPK =
        block?.transactions?.coinbaseReceiverPK?.publicKey;

      if (coinbaseReceiverPK) {
        public_keys.add(coinbaseReceiverPK);
      }

      block.transactions.feeTransfer.forEach((feeTransfer) => {
        public_keys.add(feeTransfer.recipient);
      });

      block.transactions.userCommands.forEach((userCommand) => {
        public_keys.add(userCommand.from);
        public_keys.add(userCommand.receiver.publicKey);
        public_keys.add(userCommand.source.publicKey);
        public_keys.add(userCommand.to);
      });
    });

    return Array.from(public_keys).map((publicKey) => [publicKey]);
  };

  try {
    await client.connect();
    let publicKeys = getPublicKeysFromBlocks();
    const sql = format("INSERT INTO public_keys (value) VALUES %L", publicKeys);
    let { rows } = await client.query(sql);
    console.log(rows);
  } catch (e) {
    console.error(e);
  } finally {
    client.end();
  }
}

// Add all public keys in the block data to postgres
insertAllPublicKeys();
