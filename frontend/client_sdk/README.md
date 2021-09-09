# Coda Client Javascript SDK

This is a NodeJS client SDK that allows you to sign transactions and strings using Coda's keypairs.
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
import * as CodaSDK from "@o1labs/client-sdk";

let keys = CodaSDK.genKeys();
let signed = CodaSDK.signMessage("hello", keys);
if (CodaSDK.verifyMessage(signed)) {
    console.log("Message was verified successfully")
};

let signedPayment = CodaSDK.signPayment({
    to: keys.publicKey,
    from: keys.publicKey,
    amount: 1,
    fee: 1,
    nonce: 0
  }, keys);
```

NodeJS:
```javascript
const CodaSDK = require("@o1labs/client-sdk");

let keys = CodaSDK.genKeys();
let signed = CodaSDK.signMessage("hello", keys);
if (CodaSDK.verifyMessage(signed)) {
    console.log("Message was verified successfully")
};

let signedPayment = CodaSDK.signPayment({
    to: keys.publicKey,
    from: keys.publicKey,
    amount: 1,
    fee: 1,
    nonce: 0
  }, keys);
```

ReasonML:
- Install gentype: `yarn add -D gentype`
- Install bs-platform: `yarn add -D bs-platform`
- Build dependencies: `yarn bsb -make-world`

```reason
module CodaSDK = O1labsClientSdk.CodaSDK;

let keys = CodaSDK.genKeys();
let signed = CodaSDK.signMessage(. "hello", keys);
if (CodaSDK.verifyMessage(. signed)) {
  Js.log("Message was verified successfully");
};

let signedPayment = CodaSDK.signPayment({
    to_: keys.publicKey,
    from: keys.publicKey,
    amount: "1",
    fee: "1",
    nonce: "0"
  }, keys);

```

# API Reference
- [Main API](src/CodaSDK.d.ts)
- [Other](src/SDKWrapper.d.ts)
