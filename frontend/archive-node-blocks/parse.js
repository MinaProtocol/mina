const fs = require("fs");
const blocksFile = "blocks.json";
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

const getSnarkedLedgerHashFromBlocks = () => {
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

const getEpochDataFromBlocks = () => {
  let epochs = [];
  blocks.forEach((block) => {
    const stakingSeed =
      block?.protocolState?.consensusState?.stakingEpochData?.seed;

    const stakingLedgerHash =
      block?.protocolState?.blockchainState?.snarkedLedgerHash;

    if (stakingSeed && stakingLedgerHash) {
      epochs.push({ seed: stakingSeed, ledgerHash: stakingLedgerHash });
    }

    const nextEpochSeed =
      block?.protocolState?.consensusState?.nextEpochData?.seed;

    const nextEpochLedgerHash =
      block?.protocolState?.consensusState?.nextEpochData?.ledger.hash;

    if (nextEpochSeed && nextEpochLedgerHash) {
      epochs.push({ seed: nextEpochSeed, ledgerHash: nextEpochLedgerHash });
    }
  });
  return epochs;
};

const getBlockDataFromBlocks = () => {
  let blocksData = [];
  blocks.forEach((block) => {
    const stateHash = block.stateHash;

    const creatorPK = block.creator;

    const snarkedLedgerHash =
      block.protocolState.blockchainState.snarkedLedgerHash;

    const stakingEpochDataSeed =
      block.protocolState.consensusState.stakingEpochData.seed;

    const nextEpochDataSeed =
      block.protocolState.consensusState.nextEpochData.seed;

    const stagedLedgerHash =
      block.protocolState.blockchainState.stagedLedgerHash;

    const height = block.protocolState.consensusState.blockHeight;

    const globalSlot = block?.protocolState?.consensusState?.slot;

    const dateTime = new Date(block?.dateTime).valueOf();

    blocksData.push({
      stateHash,
      creatorPK,
      snarkedLedgerHash,
      stakingEpochDataSeed,
      nextEpochDataSeed,
      stagedLedgerHash,
      height,
      globalSlot,
      dateTime,
    });
  });
  return blocksData;
};

module.exports.getPublicKeysFromBlocks = getPublicKeysFromBlocks;
module.exports.getSnarkedLedgerHashFromBlocks = getSnarkedLedgerHashFromBlocks;
module.exports.getEpochDataFromBlocks = getEpochDataFromBlocks;
module.exports.getBlockDataFromBlocks = getBlockDataFromBlocks;
