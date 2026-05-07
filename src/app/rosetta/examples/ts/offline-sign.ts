/**
 * Cold-signing flow. Splits the Construction API across an online and offline
 * environment:
 *
 *   ONLINE  (hot host with Rosetta access):
 *     preprocess → metadata → payloads → save unsigned to disk
 *
 *   OFFLINE (cold host, no network):
 *     read unsigned → rosettaCombinePayload(payloads, privateKey) → save to disk
 *
 *   ONLINE:
 *     read combine input → /construction/combine → /construction/submit
 *
 * For demo purposes everything happens in one process and persists through
 * temp files, but the comments mark the boundary you would split in production.
 */
import * as fs from "fs";
import * as path from "path";
import Client from "mina-signer";
import {
  RosettaClient,
  Signature,
  buildTransferOperations,
  requireEnv,
  CURVE_TYPE,
  NETWORK,
} from "./commons";

const WORK_DIR = path.resolve(__dirname, ".cold-signing");
const PAYLOADS_FILE = path.join(WORK_DIR, "payloads.json");
const COMBINE_INPUT_FILE = path.join(WORK_DIR, "combine-input.json");

async function buildPayloads() {
  const senderAddress = requireEnv("SENDER_ADDRESS");
  const senderPublicKey = requireEnv("SENDER_PUBLIC_KEY");
  const receiverAddress = requireEnv("RECEIVER_ADDRESS");
  const amount = process.env.TRANSFER_AMOUNT ?? "1000000000";
  const fee = process.env.TRANSFER_FEE ?? "10000000";

  const rosetta = new RosettaClient();
  const operations = buildTransferOperations({
    sender: senderAddress,
    receiver: receiverAddress,
    amountNanomina: amount,
    feeNanomina: fee,
  });
  const publicKeys = [{ hex_bytes: senderPublicKey, curve_type: CURVE_TYPE }];

  const { options } = await rosetta.constructionPreprocess(operations);
  const { metadata } = await rosetta.constructionMetadata(options, publicKeys);
  const payloadsResponse = await rosetta.constructionPayloads(
    operations,
    metadata,
    publicKeys,
  );

  fs.mkdirSync(WORK_DIR, { recursive: true });
  fs.writeFileSync(PAYLOADS_FILE, JSON.stringify(payloadsResponse));
  console.log(`Wrote payloads to ${PAYLOADS_FILE}`);
}

function signOffline() {
  const senderPrivateKey = requireEnv("SENDER_PRIVATE_KEY");
  const signer = new Client({
    network: NETWORK === "mainnet" ? "mainnet" : "testnet",
  });

  const payloadsResponse = JSON.parse(fs.readFileSync(PAYLOADS_FILE, "utf8"));
  const combinePayload = signer.rosettaCombinePayload(
    payloadsResponse,
    senderPrivateKey,
  );

  fs.writeFileSync(COMBINE_INPUT_FILE, JSON.stringify(combinePayload));
  console.log(`Wrote combine input to ${COMBINE_INPUT_FILE}`);
}

async function submit() {
  const rosetta = new RosettaClient();
  const combinePayload = JSON.parse(
    fs.readFileSync(COMBINE_INPUT_FILE, "utf8"),
  );
  const { signed_transaction } = await rosetta.constructionCombine(
    combinePayload.unsigned_transaction,
    combinePayload.signatures as Signature[],
  );
  const result = await rosetta.constructionSubmit(signed_transaction);
  console.log(`Submitted: ${result.transaction_identifier.hash}`);
}

async function main() {
  console.log("=== ONLINE: build unsigned payloads ===");
  await buildPayloads();

  console.log("=== OFFLINE: sign ===");
  signOffline();

  console.log("=== ONLINE: combine + submit ===");
  await submit();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
