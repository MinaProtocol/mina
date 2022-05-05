import {
  Field,
  declareState,
  declareMethods,
  State,
  PrivateKey,
  SmartContract,
  compile,
  deploy,
  callUnproved,
  isReady,
  shutdown,
  Mina,
  signFeePayer,
  call,
  Permissions,
} from "snarkyjs";
import { tic, toc } from "./tictoc.js";

await isReady;

// declare the zkapp
const transactionFee = 1_000_000_000;
const initialBalance = 10_000_000_000;
const initialState = Field(1);
class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy(args) {
    super.deploy(args);
    // TODO: this is bad.. we have to fetch current permissions and enable to update just one of them
    this.self.update.permissions.setValue({
      ...Permissions.default(),
      editState: Permissions.proofOrSignature(),
    });
  }

  initialize() {
    this.x.set(initialState);
  }

  update(x) {
    this.x.set(x);
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethods(SimpleZkapp, { initialize: [], update: [Field] });

// setup mock mina
let Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
let sender = Local.testAccounts[0];

// create new random zkapp keypair (with snarkyjs)
let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();

// compile smart contract (= Pickles.compile)
tic("compile smart contract");
let { verificationKey, provers, verify } = await compile(
  SimpleZkapp,
  zkappAddress
);
toc();

tic("create deploy transaction");
let partiesJsonDeploy = await deploy(SimpleZkapp, {
  zkappKey,
  verificationKey,
  initialBalance,
  feePayerKey: sender.privateKey,
  shouldSignFeePayer: true,
  transactionFee,
});
toc();

tic("apply deploy transaction");
Local.applyJsonTransaction(partiesJsonDeploy);
toc();

tic("create initialize transaction (with proof)");
let partiesJsonInitialize = await call(
  SimpleZkapp,
  zkappAddress,
  "initialize",
  [],
  provers,
  verify
);
partiesJsonInitialize = await signFeePayer(
  partiesJsonInitialize,
  sender.privateKey,
  { transactionFee }
);
toc();

tic("apply initialize transaction");
Local.applyJsonTransaction(partiesJsonInitialize);
toc();

// check that deploy and initialize txns were applied
let zkappState = Mina.getAccount(zkappAddress).zkapp.appState[0];
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
partiesJsonUpdate = await signFeePayer(partiesJsonUpdate, sender.privateKey, {
  transactionFee,
});
toc();

tic("apply update transaction (no proof)");
Local.applyJsonTransaction(partiesJsonUpdate);
toc();

// check that first update txn was applied
zkappState = Mina.getAccount(zkappAddress).zkapp.appState[0];
zkappState.assertEquals(3);
console.log("got updated state: " + zkappState);

tic("create update transaction (with proof)");
let partiesJsonUpdateWithProof = await call(
  SimpleZkapp,
  zkappAddress,
  "update",
  [Field(5)],
  provers,
  verify
);
partiesJsonUpdateWithProof = await signFeePayer(
  partiesJsonUpdateWithProof,
  sender.privateKey,
  { transactionFee }
);
toc();

tic("apply update transaction (with proof)");
Local.applyJsonTransaction(partiesJsonUpdateWithProof);
toc();

// check that second update txn was applied
zkappState = Mina.getAccount(zkappAddress).zkapp.appState[0];
zkappState.assertEquals(5);
console.log("got updated state: " + zkappState);

shutdown();
