/**
 * Full Construction API flow: build operations → preprocess → metadata →
 * payloads → sign → combine → submit.
 *
 * Uses `mina-signer`'s `rosettaCombinePayload` helper, which takes the
 * response from `/construction/payloads` and returns the bytes that go
 * into `/construction/combine`. See `offline-sign.ts` for the
 * cold-signing variant.
 */
import 'dotenv/config';
import Client from 'mina-signer';
import {
  CURVE_TYPE,
  RosettaClient,
  buildTransferOperations,
  type Signature,
} from '@o1-labs/mina-rosetta-sdk';

async function main() {
  const senderPrivateKey = requireEnv('SENDER_PRIVATE_KEY');
  const senderAddress = requireEnv('SENDER_ADDRESS');
  const receiverAddress = requireEnv('RECEIVER_ADDRESS');
  const amount = process.env.TRANSFER_AMOUNT ?? '1000000000';
  const fee = process.env.TRANSFER_FEE ?? '10000000';
  const network = process.env.NETWORK ?? 'devnet';

  const rosetta = new RosettaClient({
    baseUrl: process.env.ROSETTA_URL ?? 'http://localhost:3087',
    network,
  });
  const signer = new Client({ network: network === 'mainnet' ? 'mainnet' : 'testnet' });

  const operations = buildTransferOperations({
    sender: senderAddress,
    receiver: receiverAddress,
    amountNanomina: amount,
    feeNanomina: fee,
  });

  const senderPublicKey = signer.derivePublicKey(senderPrivateKey);
  const senderPublicKeyHex = signer.publicKeyToRaw(senderPublicKey);
  const publicKeys = [{ hex_bytes: senderPublicKeyHex, curve_type: CURVE_TYPE }];

  console.log('[1/5] /construction/preprocess');
  const { options } = await rosetta.constructionPreprocess({ operations });

  console.log('[2/5] /construction/metadata');
  const { metadata } = await rosetta.constructionMetadata({
    options: options ?? {},
    publicKeys,
  });

  console.log('[3/5] /construction/payloads');
  const payloadsResponse = await rosetta.constructionPayloads({
    operations,
    metadata,
    publicKeys,
  });

  console.log('[4/5] sign + /construction/combine');
  const combinePayload = signer.rosettaCombinePayload(payloadsResponse, senderPrivateKey);
  const { signed_transaction } = await rosetta.constructionCombine({
    unsignedTransaction: combinePayload.unsigned_transaction,
    signatures: combinePayload.signatures as unknown as Signature[],
  });

  console.log('[5/5] /construction/submit');
  const result = await rosetta.constructionSubmit(signed_transaction);
  console.log(`Submitted: ${result.transaction_identifier.hash}`);
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
