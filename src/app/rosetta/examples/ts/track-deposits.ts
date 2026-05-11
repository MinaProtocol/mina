/**
 * Watch a target address for incoming MINA. Filters `payment_receiver_inc`
 * operations — the canonical exchange-deposit-monitoring pattern.
 */
import 'dotenv/config';
import {
  type Block,
  type Operation,
  OperationType,
  RosettaClient,
} from '@o1-labs/mina-rosetta-sdk';

const POLL_INTERVAL_MS = 10_000;

interface Deposit {
  blockHeight: number;
  blockHash: string;
  txHash: string;
  amountNanomina: string;
}

function findDeposits(block: Block, address: string): Deposit[] {
  const deposits: Deposit[] = [];
  for (const tx of block.transactions) {
    for (const op of tx.operations) {
      if (isDeposit(op, address)) {
        deposits.push({
          blockHeight: block.block_identifier.index,
          blockHash: block.block_identifier.hash,
          txHash: tx.transaction_identifier.hash,
          amountNanomina: op.amount!.value,
        });
      }
    }
  }
  return deposits;
}

function isDeposit(op: Operation, address: string): boolean {
  return (
    op.type === OperationType.PaymentReceiverInc &&
    op.status !== 'Failed' &&
    op.account?.address === address &&
    !!op.amount
  );
}

async function main() {
  const address = requireEnv('TEST_ADDRESS');
  const client = new RosettaClient({
    baseUrl: process.env.ROSETTA_URL ?? 'http://localhost:3087',
    network: process.env.NETWORK ?? 'devnet',
  });
  const startEnv = parseInt(process.env.START_HEIGHT ?? '0', 10);

  let height = startEnv;
  if (!height) {
    const status = await client.networkStatus();
    height = status.current_block_identifier.index;
  }
  console.log(`Watching ${address} for deposits starting at block ${height}`);

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const { block } = await client.block({ index: height });
    if (!block) {
      await sleep(POLL_INTERVAL_MS);
      continue;
    }

    for (const d of findDeposits(block, address)) {
      console.log(
        `DEPOSIT  block=${d.blockHeight}  tx=${d.txHash}  amount=${d.amountNanomina} nanomina`,
      );
    }
    height += 1;
  }
}

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
