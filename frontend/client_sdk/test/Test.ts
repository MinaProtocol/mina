import * as CodaSDK from "../src/SDKWrapper";
import { deepStrictEqual } from "assert";

let key = CodaSDK.genKeys();
let signed = CodaSDK.signMessage("hello", key);
CodaSDK.verifyMessage(signed);


let payment1 = CodaSDK.unsafeSignAny(
    {to: key.publicKey, from: key.publicKey, amount: "1", fee: "1", nonce: "0"},
    key);


let payment2 = CodaSDK.signPayment(
    {to: key.publicKey, from: key.publicKey, amount: 1, fee: 1, nonce: 0},
    key);

deepStrictEqual(payment1, payment2, "Payment signatures don't match (string vs numeric inputs)");

let sd1 = CodaSDK.signStakeDelegation(
    {to: key.publicKey, from: key.publicKey, fee: "1", nonce: "0"},
    key);


let sd2 = CodaSDK.signStakeDelegation(
    {to: key.publicKey, from: key.publicKey, fee: 1, nonce: 0},
    key);

deepStrictEqual(sd1, sd2, "Stake delegation signatures don't match (string vs numeric inputs)");