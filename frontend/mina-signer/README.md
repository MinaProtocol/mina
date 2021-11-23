# Mina Signer SDK

This is a NodeJS client SDK that allows you to sign transactions and strings using Mina's keypairs for various specified networks.

# Install

```bash
yarn add mina-signer
# or with npm:
npm install --save mina-signer
```

# Usage

Typescript:

```typescript
import Client from "mina-signer";
const client = new Client({ network: "mainnet" });
let keys = client.genKeys();
let signed = client.signMessage("hello", keys);
if (client.verifyMessage(signed)) {
  console.log("Message was verified successfully");
}

let signedPayment = client.signPayment(
  {
    to: keys.publicKey,
    from: keys.publicKey,
    amount: 1,
    fee: 1,
    nonce: 0,
  },
  keys.privateKey
);
```

NodeJS:

```javascript
const Client = require("mina-signer");
const client = new Client({ network: "mainnet" });
let keys = client.genKeys();
let signed = client.signMessage("hello", keys);
if (client.verifyMessage(signed)) {
  console.log("Message was verified successfully");
}

let signedPayment = client.signPayment(
  {
    to: keys.publicKey,
    from: keys.publicKey,
    amount: 1,
    fee: 1,
    nonce: 0,
  },
  keys.privateKey
);
```

# API Reference

- [Main API](src/MinaSDK.d.ts)
- [Types](src/TSTypes.ts)
