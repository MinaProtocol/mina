import Client from "mina-signer";
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
  addCachedAccount,
  Mina,
  verify,
} from "snarkyjs";

await isReady;
const zkappTargetBalance = 10_000_000_000;
const initialBalance = zkappTargetBalance;
const transactionFee = 10_000_000;
const initialState = Field(1);

class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy(args) {
    super.deploy(args);
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
declareMethods(SimpleZkapp, { update: [Field] });

// parse command line; for local testing, use random keys as fallback
let [zkappKeyBase58, feePayerKeyBase58, graphql_uri] = process.argv.slice(2);
zkappKeyBase58 ||= PrivateKey.random().toBase58();
feePayerKeyBase58 ||= PrivateKey.random().toBase58();

console.log(
  `simple-zkapp.js: Running with zkapp key ${zkappKeyBase58}, fee payer key ${feePayerKeyBase58} and graphql uri ${graphql_uri}`
);

let zkappKey = PrivateKey.fromBase58(zkappKeyBase58);
let zkappAddress = zkappKey.toPublicKey();

console.log(`simple-zkapp.js: Starting integration test`);

throw Error("invalid something");
