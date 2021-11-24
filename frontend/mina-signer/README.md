# Mina Signer

This is a NodeJS SDK that allows you to sign strings, payments, and delegations using Mina's key pairs for various specified networks.

# Install

```bash
yarn add mina-signer
# or with npm:
npm install --save mina-signer
```

# Usage

```js
import Client from "mina-signer";
const client = new Client({ network: "mainnet" });

// Generate keys
let keypair = client.genKeys();

// Sign and verify message
let signed = client.signMessage("hello", keypair);
if (client.verifyMessage(signed)) {
  console.log("Message was verified successfully");
}

// Sign and verify a payment
let signedPayment = client.signPayment(
  {
    to: keypair.publicKey,
    from: keypair.publicKey,
    amount: 1,
    fee: 1,
    nonce: 0,
  },
  keypair.privateKey
);
if (client.verifyPayment(signedPayment)) {
  console.log("Payment was verified successfully");
}

// Sign and verify a stake delegation
const signedDelegation = client.signStakeDelegation(
  {
    to: keypair.publicKey,
    from: keypair.publicKey,
    fee: "1",
    nonce: "0",
  },
  keypair.privateKey
);
if (client.verifyStakeDelegation(signedDelegation)) {
  console.log("Delegation was verified successfully");
}
```
