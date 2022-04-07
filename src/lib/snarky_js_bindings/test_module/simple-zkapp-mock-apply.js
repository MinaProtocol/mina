import {
  Field,
  declareState,
  declareMethodArguments,
  State,
  PrivateKey,
  SmartContract,
  compile,
  deploy,
  callUnproved,
  isReady,
  shutdown,
  Mina,
  signJsonTransaction,
  Perm,
  call,
} from "snarkyjs";
import cached from "./cached.js";

await isReady;

// helper for printing timings

let timingStack = [];
let i = 0;
function tic(label = `Run command ${i++}`) {
  process.stdout.write(`${label}... `);
  timingStack.push([label, Date.now()]);
}
function toc() {
  let [label, start] = timingStack.pop();
  let time = (Date.now() - start) / 1000; // in seconds
  process.stdout.write(`\r${label}... ${time.toFixed(3)} sec\n`);
}

// declare the zkapp
const transactionFee = 1_000_000_000;
const initialBalance = 10_000_000_000;
const initialState = Field(1);
class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy() {
    this.self.update.permissions.setValue({
      editState: Perm.proofOrSignature(),
    });
    this.x.set(initialState);
  }

  update(x) {
    this.x.set(x);
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethodArguments(SimpleZkapp, { update: [Field] });

// setup mock mina
let Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
let sender = Local.testAccounts[0];

// create new random zkapp keypair (with snarkyjs)
let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();

// compile smart contract (= Pickles.compile)
tic("compile smart contract");
let { verificationKey, provers } = await compile(SimpleZkapp, zkappAddress);
// let verificationKey = await cached(
//   () => compile(SimpleZkapp, zkappAddress).verificationKey
// );
toc();

tic("create deploy transaction");
let partiesJsonDeploy = await deploy(SimpleZkapp, {
  zkappKey,
  verificationKey,
  initialBalance,
  initialBalanceFundingAccountKey: sender.privateKey,
  shouldSignFeePayer: true,
  feePayerKey: sender.privateKey,
  transactionFee,
});
toc();

console.log(JSON.stringify(JSON.parse(partiesJsonDeploy), null, 2));

tic("apply deploy transaction");
Local.applyJsonTransaction(partiesJsonDeploy);
toc();

// check that deploy txn was applied
let zkappState = Mina.getAccount(zkappAddress).snapp.appState[0];
zkappState.assertEquals(1);
console.log("got initial state: " + zkappState);

tic("create update transaction (no proof)");
let partiesJsonUpdate = await callUnproved(
  SimpleZkapp,
  zkappAddress,
  "update",
  [Field(3)],
  zkappKey
);
partiesJsonUpdate = await signJsonTransaction(
  partiesJsonUpdate,
  sender.privateKey,
  { transactionFee }
);
toc();

tic("apply update transaction (no proof)");
Local.applyJsonTransaction(partiesJsonUpdate);
toc();

tic("create update transaction (with proof)");
let partiesJsonUpdateWithProof = await call(
  SimpleZkapp,
  zkappAddress,
  "update",
  [Field(5)],
  provers
);
partiesJsonUpdateWithProof = await signJsonTransaction(
  partiesJsonUpdateWithProof,
  sender.privateKey,
  { transactionFee }
);
toc();

tic("apply update transaction (with proof)");
Local.applyJsonTransaction(partiesJsonUpdateWithProof);
toc();

// check that deploy txn was applied
zkappState = Mina.getAccount(zkappAddress).snapp.appState[0];
zkappState.assertEquals(5);
console.log("got updated state: " + zkappState);

shutdown();
