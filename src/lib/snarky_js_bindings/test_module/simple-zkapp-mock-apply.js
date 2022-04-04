import {
  Field,
  declareState,
  declareMethodArguments,
  State,
  UInt64,
  PrivateKey,
  SmartContract,
  compile,
  deploy,
  call,
  isReady,
  shutdown,
  Mina,
  Ledger,
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

// PART 1: snarkyjs

// declare the zkapp in snarkyjs
const transactionFee = 1_000_000_000;
const initialBalance = 10_000_000_000;
const initialState = Field(1);
class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy() {
    super.deploy();
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
let senderAccount = Local.testAccounts[0];

// create new random zkapp keypair (with snarkyjs)
let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();

// compile smart contract (= Pickles.compile)
tic("compile smart contract");
// let { verificationKey, provers } = compile(SimpleZkapp, zkappAddress);
let verificationKey = await cached(
  () => compile(SimpleZkapp, zkappAddress).verificationKey
);
toc();

// deploy transaction
tic("create deploy transaction");
let partiesJsonDeploy = deploy(SimpleZkapp, {
  zkappKey,
  verificationKey,
  initialBalance,
  initialBalanceFundingAccountKey: senderAccount.privateKey,
});
toc();

// add nonce, public key; sign feepayer
// TODO better API for setting feepayer
let parties = JSON.parse(partiesJsonDeploy);
parties.feePayer.data.predicate = "0";
parties.feePayer.data.body.publicKey = Ledger.publicKeyToString(
  senderAccount.publicKey
);
parties.feePayer.data.body.balanceChange = `${transactionFee}`;
partiesJsonDeploy = JSON.stringify(parties);

let partiesJsonDeploySigned = Ledger.signFeePayer(
  partiesJsonDeploy,
  senderAccount.privateKey
);
console.log(JSON.stringify(JSON.parse(partiesJsonDeploySigned), null, 2));

Local.applyJsonTransaction(partiesJsonDeploySigned);

// check that deploy txn was applied
let snappState = Mina.getAccount(zkappAddress).snapp.appState[0];
console.log("initial state: " + snappState);

// // update transaction
// tic("create update transaction (with proof)");
// let partiesJsonUpdate = await call(
//   SimpleZkapp,
//   zkappAddress,
//   "update",
//   [Field(3)],
//   provers
// );
// toc();

shutdown();
