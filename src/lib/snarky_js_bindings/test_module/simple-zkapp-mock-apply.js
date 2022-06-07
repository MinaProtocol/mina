import {
  Field,
  declareState,
  declareMethods,
  State,
  PrivateKey,
  SmartContract,
  deploy,
  isReady,
  shutdown,
  Mina,
  signFeePayer,
  Permissions,
  Ledger,
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
    this.setPermissions({
      ...Permissions.default(),
      editState: Permissions.proofOrSignature(),
    });
  }

  initialize() {
    this.x.set(initialState);
  }

  update(y) {
    let x = this.x.get();
    y.assertGt(0);
    this.x.set(x.add(y));
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethods(SimpleZkapp, { initialize: [], update: [Field] });

// setup mock mina
let Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
let sender = Local.testAccounts[0];
let senderKey = sender.privateKey;

// create new random zkapp keypair (with snarkyjs)
let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();

// compile smart contract (= Pickles.compile)
tic("compile smart contract");
let { verificationKey } = await SimpleZkapp.compile(zkappAddress);
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
let transaction = await Mina.transaction(() => {
  new SimpleZkapp(zkappAddress).initialize();
});
await transaction.prove();
let partiesJsonInitialize = transaction.toJSON();
partiesJsonInitialize = signFeePayer(partiesJsonInitialize, senderKey, {
  transactionFee,
});
toc();

// verify the proof
tic("verify transaction proof");
let parties = JSON.parse(partiesJsonInitialize);
let proof = parties.otherParties[0].authorization.proof;
let statement = Ledger.transactionStatement(partiesJsonInitialize, 0);
let ok = await Ledger.verifyPartyProof(statement, proof, verificationKey.data);
toc();
console.log("did proof verify?", ok);
if (!ok) console.log("proof didn't verify");

tic("apply initialize transaction");
Local.applyJsonTransaction(partiesJsonInitialize);
toc();

// check that deploy and initialize txns were applied
let zkapp = new SimpleZkapp(zkappAddress);
let zkappState = zkapp.x.get();
zkappState.assertEquals(1);
console.log("got initial state: " + zkappState);

tic("create update transaction (no proof)");
transaction = await Mina.transaction(() => {
  zkapp.update(Field(2));
  zkapp.sign(zkappKey);
});
transaction.sign();
let partiesJsonUpdate = transaction.toJSON();
partiesJsonUpdate = signFeePayer(partiesJsonUpdate, senderKey, {
  transactionFee,
});
toc();

tic("apply update transaction (no proof)");
Local.applyJsonTransaction(partiesJsonUpdate);
toc();

// check that first update txn was applied
zkappState = zkapp.x.get();
zkappState.assertEquals(3);
console.log("got updated state: " + zkappState);

tic("create update transaction (with proof)");
transaction = await Mina.transaction(() => {
  new SimpleZkapp(zkappAddress).update(Field(2));
});
await transaction.prove();
let partiesJsonUpdateWithProof = transaction.toJSON();
partiesJsonUpdateWithProof = signFeePayer(
  partiesJsonUpdateWithProof,
  senderKey,
  { transactionFee }
);
toc();

tic("apply update transaction (with proof)");
Local.applyJsonTransaction(partiesJsonUpdateWithProof);
toc();

// check that second update txn was applied
zkappState = zkapp.x.get();
zkappState.assertEquals(5);
console.log("got updated state: " + zkappState);

shutdown();
