import { RosettaClient, requireEnv } from "./commons";

async function main() {
  const address = requireEnv("TEST_ADDRESS");
  const client = new RosettaClient();

  const { block_identifier, balances } = await client.accountBalance(address);
  console.log(`Address: ${address}`);
  console.log(`As of block ${block_identifier.index} (${block_identifier.hash})`);
  for (const b of balances) {
    console.log(`  ${b.value} ${b.currency.symbol} (${b.currency.decimals} decimals)`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
