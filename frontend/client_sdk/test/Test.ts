import * as CodaSDK from "../src/SDKWrapper";
import { deepStrictEqual } from "assert";

let key = CodaSDK.genKeys();
let publicKey = CodaSDK.derivePublicKey(key.privateKey);
let signed = CodaSDK.signMessage("hello", key);
CodaSDK.verifyMessage(signed);

deepStrictEqual(publicKey, key.publicKey, "Public keys do not match");

let payment1 = CodaSDK.unsafeSignAny(
    {to: key.publicKey, from: key.publicKey, amount: "1", fee: "1", nonce: "0"},
    key);


let payment2 = CodaSDK.signPayment(
    {to: key.publicKey, from: key.publicKey, amount: 1, fee: 1, nonce: 0},
    key);

deepStrictEqual(payment1, payment2, "Payment signatures don't match (string vs numeric inputs)");


deepStrictEqual(CodaSDK.verifyPaymentSignature(payment1), true, "Unsafe signed payment could not be verified.");
deepStrictEqual(CodaSDK.verifyPaymentSignature(payment2), true, "Signed payment could not be verified.");

let invalidPayment = {...payment2, publicKey: CodaSDK.genKeys().publicKey};
deepStrictEqual(CodaSDK.verifyPaymentSignature(invalidPayment), false, "Invalid signed payment was verified");

let sd1 = CodaSDK.signStakeDelegation(
    {to: key.publicKey, from: key.publicKey, fee: "1", nonce: "0"},
    key);


let sd2 = CodaSDK.signStakeDelegation(
    {to: key.publicKey, from: key.publicKey, fee: 1, nonce: 0},
    key);

deepStrictEqual(sd1, sd2, "Stake delegation signatures don't match (string vs numeric inputs)");

CodaSDK.verifyStakeDelegationSignature(sd1);
deepStrictEqual(CodaSDK.verifyStakeDelegationSignature(sd1), true, "Signed delegation could not be verified");

let invalidSd = {...sd1, publicKey: CodaSDK.genKeys().publicKey};
deepStrictEqual(CodaSDK.verifyStakeDelegationSignature(invalidSd), false, "Invalid signed delegation was verified");
