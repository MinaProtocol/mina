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
  verify,
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
    this.x.assertEquals(x);
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

tic("compute circuit digest");
let digest = SimpleZkapp.digest(zkappAddress);
toc();

// compile smart contract (= Pickles.compile)
tic("compile smart contract");
let { verificationKey } = await SimpleZkapp.compile(zkappAddress);
toc();

tic("create deploy transaction");
let zkappCommandJsonDeploy = await deploy(SimpleZkapp, {
  zkappKey,
  initialBalance,
  feePayer: { feePayerKey: sender.privateKey, fee: transactionFee },
});
toc();

tic("apply deploy transaction");
Local.applyJsonTransaction(zkappCommandJsonDeploy);
toc();

tic("create initialize transaction (with proof)");
let transaction = await Mina.transaction(() => {
  new SimpleZkapp(zkappAddress).initialize();
});
let [proof] = await transaction.prove();
let zkappCommandJsonInitialize = transaction.toJSON();
zkappCommandJsonInitialize = signFeePayer(zkappCommandJsonInitialize, senderKey, {
  transactionFee,
});
toc();

// verify the proof
tic("verify transaction proof");
let ok = await verify(proof, verificationKey.data);
toc();
console.log("did proof verify?", ok);
if (!ok) throw Error("proof didn't verify");

tic("apply initialize transaction");
Local.applyJsonTransaction(zkappCommandJsonInitialize);
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
let zkappCommandJsonUpdate = transaction.toJSON();
zkappCommandJsonUpdate = signFeePayer(zkappCommandJsonUpdate, senderKey, {
  transactionFee,
});
toc();

tic("apply update transaction (no proof)");
Local.applyJsonTransaction(zkappCommandJsonUpdate);
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
let zkappCommandJsonUpdateWithProof = transaction.toJSON();
zkappCommandJsonUpdateWithProof = signFeePayer(
  zkappCommandJsonUpdateWithProof,
  senderKey,
  { transactionFee }
);
toc();

tic("apply update transaction (with proof)");
Local.applyJsonTransaction(zkappCommandJsonUpdateWithProof);
toc();

// check that second update txn was applied
zkappState = zkapp.x.get();
zkappState.assertEquals(5);
console.log("got updated state: " + zkappState);

shutdown();
