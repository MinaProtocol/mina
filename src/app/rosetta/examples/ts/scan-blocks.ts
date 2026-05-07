import { RosettaClient, sleep } from "./commons";

const POLL_INTERVAL_MS = 10_000;

async function main() {
  const client = new RosettaClient();
  const startEnv = parseInt(process.env.START_HEIGHT ?? "0", 10);

  let height = startEnv;
  if (!height) {
    const status = await client.networkStatus();
    height = status.current_block_identifier.index;
    console.log(`Starting from chain tip: ${height}`);
  } else {
    console.log(`Starting from height: ${height}`);
  }

  while (true) {
    const { block } = await client.block({ index: height });

    if (!block) {
      await sleep(POLL_INTERVAL_MS);
      continue;
    }

    console.log(
      `[${new Date(block.timestamp).toISOString()}] block ${block.block_identifier.index} ` +
        `(${block.block_identifier.hash}) — ${block.transactions.length} tx`,
    );
    for (const tx of block.transactions) {
      console.log(`  ${tx.transaction_identifier.hash}`);
    }

    height += 1;
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
