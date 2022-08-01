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
} from "snarkyjs";
import { tic, toc } from "./tictoc.js";
import cached from "./cached.js";

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
    this.x.set(initialState);
  }

  update(x) {
    this.x.set(x);
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethods(SimpleZkapp, { update: [Field] });

// setup mock mina
let Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
let sender = Local.testAccounts[0];

// create new random zkapp keypair (with snarkyjs)
let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();

// compile smart contract (= Pickles.compile)
tic("compile smart contract");
let verificationKey = await cached(
  async () => (await SimpleZkapp.compile(zkappAddress)).verificationKey
);
toc();

tic("create deploy transaction");
let jsonDeploy = await deploy(SimpleZkapp, {
  zkappKey,
  verificationKey,
  initialBalance,
  feePayer: { feePayerKey: sender.privateKey, fee: transactionFee },
});
toc();

tic("apply deploy transaction");
Local.applyJsonTransaction(jsonDeploy);
toc();

// check that deploy txn was applied
let zkapp = new SimpleZkapp(zkappAddress);
let zkappState = zkapp.x.get();
zkappState.assertEquals(1);
console.log("got initial state: " + zkappState);

tic("create update transaction (no proof)");
let transaction = await Mina.transaction(() => {
  // if we sign the transaction, no proof will be created
  zkapp.sign(zkappKey);
  zkapp.update(Field(3));
});
await transaction.sign().prove();
let jsonUpdate = transaction.toJSON();
jsonUpdate = signFeePayer(jsonUpdate, sender.privateKey, { transactionFee });
toc();

tic("apply update transaction (no proof)");
Local.applyJsonTransaction(jsonUpdate);
toc();

// check that first update txn was applied
zkappState = zkapp.x.get();
zkappState.assertEquals(3);
console.log("got updated state: " + zkappState);

shutdown();
