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
import * as Coda from "@o1labs/client-sdk";

let keys = Coda.genKeys();
let signed = Coda.signMessage("hello", keys);
if (Coda.verifyMessage(signed)) {
    console.log("Message was verified successfully")
};
```

NodeJS:
```javascript
const coda = require("@o1labs/client-sdk");

let keys = coda.genKeys();
let signed = coda.signMessage("hello", keys);
if (coda.verifyMessage(signed)) {
    console.log("Message was verified successfully")
};
```

ReasonML:
```reason
let keys = CodaSdk.genKeys();
let signed = CodaSdk.signMessage("hello", keys);
if (CodaSdk.verifyMessage(signed)) {
    Js.log("Message was verified successfully")
};
```

# API Reference
- [Main API](src/CodaSDK.d.ts)
- [Other](src/SDKWrapper.d.ts)
