var coda = require("../../../../_build/default/src/app/client_sdk/client_sdk.bc.js").codaSDK;

var keypair = {
  privateKey:
    "EKEjf4cZcaUScpV3iAE8r9PaEj4dbPbyUhzWryhhxQqjTTSCfyo8",
  publicKey:
    "B62qom56dHZvJvuZRZ2cCGRqB2UdCjoDRQjQRKfZyxX1SBTbF24L7Pt",
};

var receiver =
  "B62qkZCRBPiTtcq62o9G4NAuAb12ZzUobicLLvNkcWZjxymxKDVd7pv";

var newDelegate =
  "B62qo4biEn36khSQcQiCioznuqXFE5nyUasEfUXVqyxdPissUEReCvL";

var payments = [
    {
      paymentPayload: {source: keypair.publicKey, receiver, amount: "42"},
      common: {fee: "3", feePayer: keypair.publicKey, nonce: "200", validUntil:"10000", memo: "this is a memo"},
    },
    {
      paymentPayload: {source: keypair.publicKey, receiver, amount: "2048"},
      common: {fee: "15", feePayer: keypair.publicKey, nonce: "212", validUntil:"305", memo: "this is not a pipe"},
    },
    {
      paymentPayload: {source: keypair.publicKey, receiver, amount: "109"},
      common: {fee: "2001", feePayer: keypair.publicKey, nonce: "3050", validUntil:"9000", memo: "blessed be the geek"},
    },
  ];

var delegations = [
    {
      delegationPayload: {delegator: keypair.publicKey, newDelegate},
      common: {fee: "3", feePayer: keypair.publicKey, nonce: "10", validUntil:"4000", memo: "more delegates, more fun"},
    },
    {
      delegationPayload: {delegator: keypair.publicKey, newDelegate},
      common: {fee: "10", feePayer: keypair.publicKey, nonce: "1000", validUntil:"8192", memo: "enough stake to kill a vampire"},
    },
    {
      delegationPayload: {delegator: keypair.publicKey, newDelegate},
      common: {fee: "8", feePayer: keypair.publicKey, nonce: "1010", validUntil:"100000", memo: "another memo"},
    },
  ];

var printSignature = s => console.log(`  { field: '${s.field}'\n  , scalar: '${s.scalar}'\n  },`);

var payment_signatures = payments.map (t => coda.signPayment(keypair.privateKey, t))

var delegation_signatures = delegations.map (t => coda.signStakeDelegation(keypair.privateKey, t))

// verify signatures before printing them
payment_signatures.forEach (t => { if (!coda.verifyPaymentSignature (t)) { console.error ("Payment signature did not verify"); process.exit (1) } })
delegation_signatures.forEach (t => { if (!coda.verifyStakeDelegationSignature (t)) { console.error ("Delegation signature did not verify"); process.exit (1) } })

console.log("[");
payment_signatures.forEach(t => printSignature (t.signature))
delegation_signatures.forEach(t => printSignature (t.signature))
console.log("]");
