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

const signedRosettaTnxMock = `
{
    "signature": "389ac7d4077f3d485c1494782870979faa222cd906b25b2687333a92f41e40b925adb08705eddf2a7098e5ac9938498e8a0ce7c70b25ea392f4846b854086d43",
    "payment": {
      "to": "B62qnzbXmRNo9q32n4SNu2mpB8e7FYYLH8NmaX6oFCBYjjQ8SbD7uzV",
      "from": "B62qnzbXmRNo9q32n4SNu2mpB8e7FYYLH8NmaX6oFCBYjjQ8SbD7uzV",
      "fee": "10000000",
      "token": "1",
      "nonce": "0",
      "memo": null,
      "amount": "1000000000",
      "valid_until": "4294967295"
    },
    "stake_delegation": null,
    "create_token": null,
    "create_token_account": null,
    "mint_tokens": null
  }
`;

const signedGraphQLCommand =
  MinaSDK.signedRosettaTransactionToSignedCommand(signedRosettaTnxMock);
const signedRosettaTnxMockJson = JSON.parse(signedRosettaTnxMock);
const signedGraphQLCommandJson = JSON.parse(signedGraphQLCommand);

deepStrictEqual(
  signedRosettaTnxMockJson.payment.to,
  signedGraphQLCommandJson.data.payload.body[1].receiver_pk,
  "Rosetta to GraphQL transaction conversion has mismatched receiver public key"
);

deepStrictEqual(
  signedRosettaTnxMockJson.payment.from,
  signedGraphQLCommandJson.data.payload.body[1].source_pk,
  "Rosetta to GraphQL transaction conversion has mismatched source public key"
);

deepStrictEqual(
  signedRosettaTnxMockJson.payment.amount,
  signedGraphQLCommandJson.data.payload.body[1].amount,
  "Rosetta to GraphQL transaction conversion has mismatched amount"
);
