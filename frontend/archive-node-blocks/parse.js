const fs = require("fs");
const blocksFile = "blocks.json";

const getPublicKeysFromBlocks = () => {
  const blocks = JSON.parse(fs.readFileSync(blocksFile, "utf8"));
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

const getSnarkedLedgerHashFromBlocks = () => {
  const blocks = JSON.parse(fs.readFileSync(blocksFile, "utf8"));
  let hashes = new Set();
  blocks.forEach((block) => {
    const snarkedLedgerHash =
      block?.protocolState?.blockchainState?.snarkedLedgerHash;
    if (snarkedLedgerHash) {
      hashes.add(snarkedLedgerHash);
    }
  });

  return Array.from(hashes).map((hash) => [hash]);
};

module.exports.getPublicKeysFromBlocks = getPublicKeysFromBlocks;
module.exports.getSnarkedLedgerHashFromBlocks = getSnarkedLedgerHashFromBlocks;
