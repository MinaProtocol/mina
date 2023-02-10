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

  deploy(args) {
    super.deploy(args);
    this.x.set(initialState);
    this.balance.addInPlace(UInt64.from(initialBalance));
    this.setPermissions({
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
}
// note: this is our non-typescript way of doing what our decorators do
declareState(NotSoSimpleZkapp, { x: Field });
declareMethods(NotSoSimpleZkapp, {
  update: [Field],
  payout: [PrivateKey],
});

// parse command line; for local testing, use random keys as fallback
let [feePayerKeyBase58, graphql_uri] = process.argv.slice(2);
let zkappKeyBase58 = PrivateKey.random().toBase58();
feePayerKeyBase58 ||= PrivateKey.random().toBase58();

//if (!graphql_uri) throw Error("Graphql uri is undefined, aborting");

console.log(
  `simple-zkapp.js: Running with zkapp key ${zkappKeyBase58}, fee payer key ${feePayerKeyBase58} and graphql uri ${graphql_uri}`
);

let Local = Mina.LocalBlockchain({ proofsEnabled: true });
Mina.setActiveInstance(Local);

// ! TODO: REMOVE
feePayerKeyBase58 = Local.testAccounts[1].privateKey.toBase58();

let zkappKey = PrivateKey.fromBase58(zkappKeyBase58);
let zkappAddress = zkappKey.toPublicKey();

let feePayerKey = PrivateKey.fromBase58(feePayerKeyBase58);
let feePayerAddress = feePayerKey.toPublicKey();

// a special account that is allowed to pull out half of the zkapp balance, once
let privilegedKey = PrivateKey.random();
let privilegedAddress = privilegedKey.toPublicKey();

let zkappTargetBalance = 10_000_000_000;
let initialBalance = zkappTargetBalance;
let initialState = Field(1);

console.log(`simple-zkapp.js: Starting integration test`);

let zkapp = new NotSoSimpleZkapp(zkappAddress);
await NotSoSimpleZkapp.compile();

console.log("deploy");
let tx = await Mina.transaction(feePayerKey, () => {
  AccountUpdate.fundNewAccount(feePayerKey, {
    initialBalance: initialBalance,
  });
  zkapp.deploy({ zkappKey });
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

let accountAfterDeploy = Mina.getAccount(zkappAddress);

try {
  accountAfterDeploy.balance.assertEquals(UInt64.from(initialBalance));
} catch (error) {
  throw Error(
    `Actual balance ${accountAfterDeploy.balance.toString()} does not match expected balance of ${initialBalance}`
  );
}

try {
  accountAfterDeploy.appState[0].assertEquals(Field(1));
} catch (error) {
  throw Error(
    `Actual state ${accountAfterDeploy.appState[0].toString()} does not match expected balance of ${1}`
  );
}

console.log("update 1");
tx = await Mina.transaction(feePayerKey, () => {
  zkapp.update(Field(30));
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

let accountAfterUpdate = Mina.getAccount(zkappAddress);
accountAfterUpdate.balance.assertEquals(UInt64.from(initialBalance));
accountAfterUpdate.appState[0].assertEquals(Field(31));

console.log("update 2");
tx = await Mina.transaction(feePayerKey, () => {
  zkapp.update(Field(100));
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();

accountAfterUpdate = Mina.getAccount(zkappAddress);
accountAfterUpdate.balance.assertEquals(UInt64.from(initialBalance));
accountAfterUpdate.appState[0].assertEquals(Field(131));

console.log("payout 1");
tx = await Mina.transaction(feePayerKey, () => {
  AccountUpdate.fundNewAccount(feePayerKey);
  zkapp.payout(privilegedKey);
});
await tx.prove();
await (await tx.sign([feePayerKey]).send()).wait();
accountAfterUpdate.balance.assertEquals(UInt64.from(10000000000));

accountAfterUpdate = Mina.getAccount(zkappAddress);
accountAfterUpdate.balance.assertEquals(UInt64.from(5000000000));

console.log("payout 2 (expected to fail)");
tx = await Mina.transaction(feePayerKey, () => {
  AccountUpdate.fundNewAccount(feePayerKey);
  zkapp.payout(privilegedKey);
});

try {
  await tx.prove();
  await (await tx.sign([feePayerKey]).send()).wait();
} catch (error) {
  // ! TODO check state change
  console.log("Failed as expected");
}

accountAfterUpdate = Mina.getAccount(zkappAddress);
accountAfterUpdate.balance.assertEquals(UInt64.from(5000000000));
shutdown();
