/**
 * Smoke test for /account/balance. The simplest example of the SDK in use.
 */
import 'dotenv/config';
import { RosettaClient } from '@o1-labs/mina-rosetta-sdk';

async function main() {
  const address = requireEnv('TEST_ADDRESS');
  const client = new RosettaClient({
    baseUrl: process.env.ROSETTA_URL ?? 'http://localhost:3087',
    network: process.env.NETWORK ?? 'devnet',
  });

  const { block_identifier, balances } = await client.accountBalance({ address });
  console.log(`Address: ${address}`);
  console.log(`As of block ${block_identifier.index} (${block_identifier.hash})`);
  for (const b of balances) {
    console.log(`  ${b.value} ${b.currency.symbol} (${b.currency.decimals} decimals)`);
  }
}

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
