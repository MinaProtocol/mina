import {
  Field,
  declareState,
  declareMethods,
  State,
  PrivateKey,
  SmartContract,
  isReady,
  shutdown,
  Mina,
  Permissions,
  verify,
  AccountUpdate,
} from "snarkyjs";
import { tic, toc } from "./tictoc.js";

await isReady;

// declare the zkapp
const initialState = Field(1);
class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy(args) {
    super.deploy(args);
    this.account.permissions.set({
      ...Permissions.default(),
      editState: Permissions.proofOrSignature(),
    });
  }

  init() {
    super.init();
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
declareMethods(SimpleZkapp, { init: [], update: [Field] });

// setup mock mina
let Local = Mina.LocalBlockchain();
Mina.setActiveInstance(Local);
let { publicKey: sender, privateKey: senderKey } = Local.testAccounts[0];

let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();
let zkapp = new SimpleZkapp(zkappAddress);

tic("compute circuit digest");
SimpleZkapp.digest();
toc();

tic("compile smart contract");
let { verificationKey } = await SimpleZkapp.compile();
toc();

tic("create deploy transaction (with proof)");
let deployTx = await Mina.transaction(sender, () => {
  AccountUpdate.fundNewAccount(sender);
  zkapp.deploy();
});
let [, , proof] = await deployTx.prove();
deployTx.sign([zkappKey, senderKey]);
toc();

tic("verify transaction proof");
let ok = await verify(proof, verificationKey.data);
toc();
console.log("did proof verify?", ok);
if (!ok) throw Error("proof didn't verify");

tic("apply deploy transaction");
await deployTx.send();
toc();

// check that deploy and initialize txns were applied
let zkappState = zkapp.x.get();
zkappState.assertEquals(1);
console.log("got initial state: " + zkappState);

tic("create update transaction (no proof)");
let tx = await Mina.transaction(sender, () => {
  zkapp.update(Field(2));
  zkapp.requireSignature();
});
tx.sign([senderKey, zkappKey]);
toc();

tic("apply update transaction (no proof)");
await tx.send();
toc();

// check that first update txn was applied
zkappState = zkapp.x.get();
zkappState.assertEquals(3);
console.log("got updated state: " + zkappState);

tic("create update transaction (with proof)");
tx = await Mina.transaction(sender, () => {
  zkapp.update(Field(2));
});
[proof] = await tx.prove();
tx.sign([senderKey]);
toc();

tic("verify transaction proof");
ok = await verify(proof, verificationKey.data);
toc();
console.log("did proof verify?", ok);
if (!ok) throw Error("proof didn't verify");

tic("apply update transaction (with proof)");
await tx.send();
toc();

// check that second update txn was applied
zkappState = zkapp.x.get();
zkappState.assertEquals(5);
console.log("got updated state: " + zkappState);

shutdown();
