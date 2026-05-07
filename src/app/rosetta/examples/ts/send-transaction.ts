/**
 * Full Construction API flow: build operations → preprocess → metadata
 * → payloads → sign → combine → submit.
 *
 * Uses mina-signer's `rosettaCombinePayload` helper, which takes the response
 * from /construction/payloads and produces the bytes you POST to
 * /construction/combine. See offline-sign.ts for the cold-signing variant.
 */
import Client from "mina-signer";
import {
  RosettaClient,
  Signature,
  buildTransferOperations,
  requireEnv,
  CURVE_TYPE,
  NETWORK,
} from "./commons";

async function main() {
  const senderPrivateKey = requireEnv("SENDER_PRIVATE_KEY");
  const senderAddress = requireEnv("SENDER_ADDRESS");
  const receiverAddress = requireEnv("RECEIVER_ADDRESS");
  const amount = process.env.TRANSFER_AMOUNT ?? "1000000000";
  const fee = process.env.TRANSFER_FEE ?? "10000000";

  const rosetta = new RosettaClient();
  const signer = new Client({
    network: NETWORK === "mainnet" ? "mainnet" : "testnet",
  });

  const operations = buildTransferOperations({
    sender: senderAddress,
    receiver: receiverAddress,
    amountNanomina: amount,
    feeNanomina: fee,
  });

  const senderPublicKey = signer.derivePublicKey(senderPrivateKey);
  const senderPublicKeyHex = signer.publicKeyToRaw(senderPublicKey);
  const publicKeys = [{ hex_bytes: senderPublicKeyHex, curve_type: CURVE_TYPE }];

  console.log("[1/5] /construction/preprocess");
  const { options } = await rosetta.constructionPreprocess(operations);

  console.log("[2/5] /construction/metadata");
  const { metadata } = await rosetta.constructionMetadata(options, publicKeys);

  console.log("[3/5] /construction/payloads");
  const payloadsResponse = await rosetta.constructionPayloads(
    operations,
    metadata,
    publicKeys,
  );

  console.log("[4/5] sign + /construction/combine");
  const combinePayload = signer.rosettaCombinePayload(
    payloadsResponse,
    senderPrivateKey,
  );
  const { signed_transaction } = await rosetta.constructionCombine(
    combinePayload.unsigned_transaction,
    combinePayload.signatures as unknown as Signature[],
  );

  console.log("[5/5] /construction/submit");
  const result = await rosetta.constructionSubmit(signed_transaction);
  console.log(`Submitted: ${result.transaction_identifier.hash}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
