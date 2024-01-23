import * as MinaSDK from "../src/SDKWrapper";
import { deepStrictEqual } from "assert";

let key = MinaSDK.genKeys();
let publicKey = MinaSDK.derivePublicKey(key.privateKey);
let signed = MinaSDK.signMessage("hello", key);
MinaSDK.verifyMessage(signed);

deepStrictEqual(publicKey, key.publicKey, "Public keys do not match");

deepStrictEqual(
  MinaSDK.verifyKeypair(key),
  true,
  "Generated keypair could not be verified"
);

deepStrictEqual(
  typeof MinaSDK.publicKeyToRaw(key.publicKey),
  "string",
  "Conversion to valid raw public key failed"
);

let payment1 = MinaSDK.unsafeSignAny(
  { to: key.publicKey, from: key.publicKey, amount: "1", fee: "1", nonce: "0" },
  key
);

let payment2 = MinaSDK.signPayment(
  { to: key.publicKey, from: key.publicKey, amount: 1, fee: 1, nonce: 0 },
  key
);

deepStrictEqual(
  payment1,
  payment2,
  "Payment signatures don't match (string vs numeric inputs)"
);

deepStrictEqual(
  MinaSDK.verifyPaymentSignature(payment1),
  true,
  "Unsafe signed payment could not be verified"
);
deepStrictEqual(
  MinaSDK.verifyPaymentSignature(payment2),
  true,
  "Signed payment could not be verified"
);

let invalidPayment = { ...payment2, publicKey: MinaSDK.genKeys().publicKey };
deepStrictEqual(
  MinaSDK.verifyPaymentSignature(invalidPayment),
  false,
  "Invalid signed payment was verified"
);

let sd1 = MinaSDK.signStakeDelegation(
  { to: key.publicKey, from: key.publicKey, fee: "1", nonce: "0" },
  key
);

let sd2 = MinaSDK.signStakeDelegation(
  { to: key.publicKey, from: key.publicKey, fee: 1, nonce: 0 },
  key
);

deepStrictEqual(
  sd1,
  sd2,
  "Stake delegation signatures don't match (string vs numeric inputs)"
);

MinaSDK.verifyStakeDelegationSignature(sd1);
deepStrictEqual(
  MinaSDK.verifyStakeDelegationSignature(sd1),
  true,
  "Signed delegation could not be verified"
);

let invalidSd = { ...sd1, publicKey: MinaSDK.genKeys().publicKey };
deepStrictEqual(
  MinaSDK.verifyStakeDelegationSignature(invalidSd),
  false,
  "Invalid signed delegation was verified"
);

const signedRosettaTxnMock = "{\"signature\":\"C1B98ADACCEC9BB0BC7646C43A128BF83FC31B44CFC4F28BA7874489AFA7312B251D96FE23D9195C65B77430CA0D326626009C28FDBE1AA47990C4235238A436\",\"payment\":{\"to\":\"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv\",\"from\":\"B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk\",\"fee\":\"2000000000\",\"token\":\"1\",\"nonce\":\"2\",\"memo\":\"hello\",\"amount\":\"3000000000\",\"valid_until\":\"10000000\"},\"stake_delegation\":null,\"create_token\":null,\"create_token_account\":null,\"mint_tokens\":null}";

const signedGraphQLCommand =
  MinaSDK.signedRosettaTransactionToSignedCommand(signedRosettaTxnMock);
const signedRosettaTxnMockJson = JSON.parse(signedRosettaTxnMock);
const signedGraphQLCommandJson = JSON.parse(signedGraphQLCommand);

deepStrictEqual(
  signedRosettaTxnMockJson.payment.to,
  signedGraphQLCommandJson.data.payload.body[1].receiver_pk,
  "Rosetta to GraphQL transaction conversion has mismatched receiver public key"
);

deepStrictEqual(
  signedRosettaTxnMockJson.payment.from,
  signedGraphQLCommandJson.data.payload.body[1].source_pk,
  "Rosetta to GraphQL transaction conversion has mismatched source public key"
);

deepStrictEqual(
  signedRosettaTxnMockJson.payment.amount,
  signedGraphQLCommandJson.data.payload.body[1].amount,
  "Rosetta to GraphQL transaction conversion has mismatched amount"
);
