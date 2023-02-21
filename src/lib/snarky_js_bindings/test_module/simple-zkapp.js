import {
  Field,
  declareState,
  declareMethods,
  State,
  PrivateKey,
  SmartContract,
  isReady,
  Mina,
  PublicKey,
  UInt64,
  AccountUpdate,
  Bool,
  shutdown,
  Permissions,
} from "snarkyjs";

await isReady;

class NotSoSimpleZkapp extends SmartContract {
  events = { update: Field, payout: UInt64, payoutReceiver: PublicKey };

  constructor(address) {
    super(address);
    this.x = State();
  }

  init() {
    super.init();
    this.x.set(initialState);
    this.account.permissions.set({
      ...Permissions.default(),
      send: Permissions.proof(),
      editState: Permissions.proof(),
    });
  }

  update(y) {
    let x = this.x.get();
    this.x.assertEquals(x);
    y.assertGt(0);
    this.x.set(x.add(y));
  }

  payout(caller) {
    let callerAddress = caller.toPublicKey();
    callerAddress.assertEquals(privilegedAddress);

    let callerAccountUpdate = AccountUpdate.create(callerAddress);
    callerAccountUpdate.account.isNew.assertEquals(Bool(true));

    let balance = this.account.balance.get();
    this.account.balance.assertEquals(balance);
    let halfBalance = balance.div(2);
    this.send({ to: callerAccountUpdate, amount: halfBalance });

    // emit some events
    this.emitEvent("payoutReceiver", callerAddress);
    this.emitEvent("payout", halfBalance);
  }

  deposit(amount) {
    let senderUpdate = AccountUpdate.createSigned(this.sender);
    senderUpdate.send({ to: this, amount });
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(NotSoSimpleZkapp, { x: Field });
declareMethods(NotSoSimpleZkapp, {
  update: [Field],
  payout: [PrivateKey],
  deposit: [UInt64],
});

// parse command line; for local testing, use random keys as fallback
let [feePayerKeyBase58, graphql_uri] = process.argv.slice(2);

if (!graphql_uri) throw Error("Graphql uri is undefined, aborting");
if (!feePayerKeyBase58) throw Error("Fee payer key is undefined, aborting");

let LocalNetwork = Mina.Network(graphql_uri);
Mina.setActiveInstance(LocalNetwork);

let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();

let feePayerKey = PrivateKey.fromBase58(feePayerKeyBase58);
let feePayerAddress = feePayerKey.toPublicKey();

try {
  Mina.getAccount(feePayerAddress);
} catch (error) {
  throw Error(
    `The fee payer account needs to be funded in order for the script to succeed! Please provide the private key of an already funded account. ${feePayerAddress.toBase58()}, ${feePayerKeyBase58}\n\n${
      error.message
    }`
  );
}

// a special account that is allowed to pull out half of the zkapp balance, once
let privilegedKey = PrivateKey.random();
let privilegedAddress = privilegedKey.toPublicKey();

let zkappTargetBalance = 10_000_000_000;
let initialBalance = zkappTargetBalance;
let initialState = Field(1);

console.log(
  `simple-zkapp.js: Running with zkapp key ${zkappKeyBase58}, fee payer key ${feePayerKeyBase58} and graphql uri ${graphql_uri}\n\n`
);

console.log(`simple-zkapp.js: Starting integration test\n`);

let zkapp = new NotSoSimpleZkapp(zkappAddress);
await NotSoSimpleZkapp.compile();

console.log("deploying contract\n");
let tx = await Mina.transaction(feePayerAddress, () => {
  AccountUpdate.fundNewAccount(feePayerAddress);

  zkapp.deploy();
});
await tx.prove();
await (await tx.sign([feePayerKey, zkappKey]).send()).wait();

let zkappAccount = Mina.getAccount(zkappAddress);

// we deployed the contract with an initial state of 1
expectAssertEquals(zkappAccount.appState[0], Field(1));

// the fresh zkapp account shouldn't have any funds
expectAssertEquals(zkappAccount.balance, UInt64.from(0));

console.log("deposit funds\n");
tx = await Mina.transaction(feePayerAddress, () => {
  zkapp.deposit(UInt64.from(initialBalance));
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

zkappAccount = Mina.getAccount(zkappAddress);

// we deposit 10_000_000_000 funds into the zkapp account
expectAssertEquals(zkappAccount.balance, UInt64.from(initialBalance));

console.log("update 1\n");
tx = await Mina.transaction(feePayerAddress, () => {
  zkapp.update(Field(30));
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

zkappAccount = Mina.getAccount(zkappAddress);

// no balance change expected
expectAssertEquals(zkappAccount.balance, UInt64.from(initialBalance));

// we updated the zkapp state to 31. x = x.add(y) ---- 31 = 1 + 30
expectAssertEquals(zkappAccount.appState[0], Field(31));

console.log("update 2\n");
tx = await Mina.transaction(feePayerAddress, () => {
  zkapp.update(Field(100));
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

zkappAccount = Mina.getAccount(zkappAddress);

// no balance change expected
expectAssertEquals(zkappAccount.balance, UInt64.from(initialBalance));

// we updated the zkapp state to 131
expectAssertEquals(zkappAccount.appState[0], Field(131));

console.log("payout 1\n");
tx = await Mina.transaction(feePayerAddress, () => {
  AccountUpdate.fundNewAccount(feePayerAddress);
  zkapp.payout(privilegedKey);
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

zkappAccount = Mina.getAccount(zkappAddress);

// we withdraw (payout) half of the initial balance
expectAssertEquals(zkappAccount.balance, UInt64.from(initialBalance / 2));

console.log("payout 2 (expected to fail)\n");
tx = await Mina.transaction(feePayerAddress, () => {
  AccountUpdate.fundNewAccount(feePayerAddress);
  zkapp.payout(privilegedKey);
});

// this tx should fail, but we wont know that here - so we just check that no state has changed
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

zkappAccount = Mina.getAccount(zkappAddress);

// checking that state hasn't changed - we expect the tx to fail so the state should equal previous state
expectAssertEquals(zkappAccount.balance, UInt64.from(initialBalance / 2));

function expectAssertEquals(actual, expected) {
  try {
    actual.assertEquals(expected);
  } catch (error) {
    throw Error(
      `Expected value ${expected.toString()}, but got ${actual.toString()}`
    );
  }
}

shutdown();
