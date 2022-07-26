import {
  Field,
  declareState,
  declareMethods,
  State,
  PublicKey,
  PrivateKey,
  SmartContract,
  isReady,
  shutdown,
  Mina,
  Permissions,
  Party,
  UInt64,
  Ledger,
  Token,
  getDefaultTokenId,
} from "snarkyjs";

function sendTransaction(tx) {
  // console.log("DEBUG -- TXN\n", JSON.stringify(partiesToJson(tx.transaction)));
  tx.send();
}

await isReady;

// declare the zkapp
class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy(args) {
    super.deploy(args);
    this.setPermissions({
      ...Permissions.default(),
      editState: Permissions.proofOrSignature(),
    });
    this.balance.addInPlace(UInt64.fromNumber(initialBalance));
    this.x.set(initialState);
    this.tokenSymbol.set("TEST_TOKEN");
    console.log(
      "Current tokenId while deploying: ",
      Ledger.fieldToBase58(this.tokenId)
    );
  }

  update(y) {
    let x = this.x.get();
    this.x.set(x.add(y));
  }

  initialize() {
    this.x.set(initialState);
  }

  mint(receiverAddress) {
    let amount = UInt64.from(1_000_000);
    this.token().mint({
      address: receiverAddress,
      amount,
    });
    console.log(`Minting ${amount} to ${receiverAddress.toBase58()}`);
  }

  burn(receiverAddress) {
    let amount = UInt64.from(1_000);
    this.token().burn({
      address: receiverAddress,
      amount,
    });
    console.log(`Burning ${amount} to ${receiverAddress.toBase58()}`);
  }

  send(senderAddress, receiverAddress) {
    let amount = UInt64.from(1_000);
    this.token().send({
      from: senderAddress,
      to: receiverAddress,
      amount,
    });
    console.log(`Sending ${amount} to ${receiverAddress.toBase58()}`);
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethods(SimpleZkapp, {
  initialize: [],
  update: [Field],
  send: [PublicKey, PublicKey],
  mint: [PublicKey],
  burn: [PublicKey],
});

let Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);

// a test account that pays all the fees, and puts additional funds into the zkapp
let feePayer = Local.testAccounts[0].privateKey;

// the zkapp account
let zkappKey = PrivateKey.fromBase58(
  "EKEfEZpMctKoyon4nxhqFBiKyUsCyyZReF9fbs21nDrrTgGMTcok"
);
let zkappAddress = zkappKey.toPublicKey();

let tokenAccount1Key = Local.testAccounts[1].privateKey;
let tokenAccount1 = tokenAccount1Key.toPublicKey();

let tokenAccount2Key = Local.testAccounts[2].privateKey;
let tokenAccount2 = tokenAccount2Key.toPublicKey();

let initialBalance = 10_000_000_000;
let initialState = Field(1);
let zkapp = new SimpleZkapp(zkappAddress);
let tx;

console.log("deploy");
tx = await Local.transaction(feePayer, () => {
  Party.fundNewAccount(feePayer, { initialBalance });
  zkapp.deploy({ zkappKey });
});
sendTransaction(tx);

console.log(`initial balance: ${zkapp.account.balance.get().div(1e9)} MINA`);

// Log custom token info
const customToken = new Token({ tokenOwner: zkappAddress });
console.log("---FEE PAYER", feePayer.toPublicKey().toBase58());
console.log("---TOKEN OWNER", zkappAddress.toBase58());
console.log("---CUSTOM TOKEN", Ledger.fieldToBase58(customToken.id));
console.log(`---TOKEN SYMBOL ${Mina.getAccount(zkappAddress).tokenSymbol}`);
console.log("---TOKEN ACCOUNT1", tokenAccount1.toBase58());
console.log("---TOKEN ACCOUNT2", tokenAccount2.toBase58());
console.log(
  "---CUSTOM TOKEN CHECKED",
  Ledger.fieldToBase58(
    Ledger.customTokenIdChecked(zkappAddress, getDefaultTokenId())
  )
);
console.log(
  "---CUSTOM TOKEN UNCHECKED",
  Ledger.fieldToBase58(Ledger.customTokenId(zkappAddress, getDefaultTokenId()))
);

console.log("----------token minting----------");
tx = await Local.transaction(feePayer, () => {
  Party.fundNewAccount(feePayer);
  zkapp.mint(tokenAccount1);
  zkapp.sign(zkappKey);
});
sendTransaction(tx);

console.log(
  `tokenAccount1 balance: ${Mina.getBalance(
    tokenAccount1,
    customToken.id
  )} custom tokens`
);

console.log("----------token burning----------");
tx = await Local.transaction(feePayer, () => {
  zkapp.burn(tokenAccount1);
  zkapp.sign(zkappKey);
});
tx = tx.sign([tokenAccount1Key]);
sendTransaction(tx);

console.log(
  `tokenAccount1 balance: ${Mina.getBalance(
    tokenAccount1,
    customToken.id
  )} custom tokens`
);

console.log("----------token transfer----------");
tx = await Local.transaction(feePayer, () => {
  Party.fundNewAccount(feePayer);
  zkapp.send(tokenAccount1, tokenAccount2);
  zkapp.sign(zkappKey);
});
tx = tx.sign([tokenAccount1Key, tokenAccount2Key]);
sendTransaction(tx);

console.log(
  `tokenAccount1 balance: ${Mina.getBalance(
    tokenAccount1,
    customToken.id
  )} custom tokens`
);
console.log(
  `tokenAccount2 balance: ${Mina.getBalance(
    tokenAccount2,
    customToken.id
  )} custom tokens`
);

shutdown();
