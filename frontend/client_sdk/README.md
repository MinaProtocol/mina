# Mina Client Javascript SDK

This is a NodeJS client SDK that allows you to sign transactions and strings using Mina's keypairs.
The project contains Typescript and ReasonML typings but can be used from plain NodeJS as well.

# Install

```bash
yarn add @o1labs/client-sdk
# or with npm:
npm install --save @o1labs/client-sdk
```

# Usage

Typescript:

```typescript
import * as MinaSDK from "@o1labs/client-sdk";

let keys = MinaSDK.genKeys();
let signed = MinaSDK.signMessage("hello", keys);
if (MinaSDK.verifyMessage(signed)) {
  console.log("Message was verified successfully");
}

let signedPayment = MinaSDK.signPayment(
  {
    to: keys.publicKey,
    from: keys.publicKey,
    amount: 1,
    fee: 1,
    nonce: 0,
  },
  keys
);
```

NodeJS:

```javascript
const MinaSDK = require("@o1labs/client-sdk");

let keys = MinaSDK.genKeys();
let signed = MinaSDK.signMessage("hello", keys);
if (MinaSDK.verifyMessage(signed)) {
  console.log("Message was verified successfully");
}

let signedPayment = MinaSDK.signPayment(
  {
    to: keys.publicKey,
    from: keys.publicKey,
    amount: 1,
    fee: 1,
    nonce: 0,
  },
  keys
);
```

ReasonML:

- Install gentype: `yarn add -D gentype`
- Install bs-platform: `yarn add -D bs-platform`
- Build dependencies: `yarn bsb -make-world`

```reason
module MinaSDK = O1labsClientSdk.MinaSDK;

let keys = MinaSDK.genKeys();
let signed = MinaSDK.signMessage(. "hello", keys);
if (MinaSDK.verifyMessage(. signed)) {
  Js.log("Message was verified successfully");
};

let signedPayment = MinaSDK.signPayment({
    to_: keys.publicKey,
    from: keys.publicKey,
    amount: "1",
    fee: "1",
    nonce: "0"
  }, keys);

```

# API Reference

- [Main API](src/MinaSDK.d.ts)
- [Other](src/SDKWrapper.d.ts)
