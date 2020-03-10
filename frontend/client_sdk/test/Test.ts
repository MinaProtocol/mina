import * as CodaSDK from "../src/SDKWrapper";

let key = CodaSDK.genKeys();
let signed = CodaSDK.signMessage("hello", key);
CodaSDK.verifyMessage(signed);

let signedPayment = CodaSDK.unsafeSignAny(
    {"to": key.publicKey, "from": key.publicKey, "amount": "1", "fee": "1", "nonce": 0},
    key);

console.log(signedPayment);
