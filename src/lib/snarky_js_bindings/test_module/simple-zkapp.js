import Client from "mina-signer";
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
  PublicKey,
} from "snarkyjs";
import cached from "./cached.js";

await isReady;
const transactionFee = 10_000_000;
const initialBalance = 10_000_000_000 - transactionFee;
const initialState = Field(1);

class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy() {
    super.deploy();
    let amount = new UInt64(Field(`${initialBalance}`));
    this.balance.addInPlace(amount);
    this.x.set(initialState);
  }

  update(x) {
    this.x.set(x);
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethodArguments(SimpleZkapp, { update: [Field] });

// create new random zkapp key, or read from cache
let keyPair = await cached(() => {
  let privateKey = PrivateKey.random();
  let publicKey = privateKey.toPublicKey().toJSON();
  return { privateKey: privateKey.toJSON(), publicKey };
});
let zkappAddress = PublicKey.fromJSON(keyPair.publicKey);
let zkappKey = PrivateKey.fromJSON(keyPair.privateKey);

let [command, feePayerKey, feePayerNonce] = parseCommandLineArgs();
feePayerKey ||= "EKEnXPN95QFZ6fWijAbhveqGtQZJT2nHptBMjFijJFb5ZUnRnHhg";

if (command === "deploy") {
  // snarkyjs part
  let { verificationKey } = compile(SimpleZkapp, zkappAddress);
  let partiesJson = deploy(SimpleZkapp, zkappKey, verificationKey);

  // mina-signer part
  let client = new Client({ network: "testnet" });
  let feePayerAddress = client.derivePublicKey(feePayerKey);
  let feePayer = {
    feePayer: feePayerAddress,
    fee: `${transactionFee + initialBalance}`,
    nonce: feePayerNonce,
  };
  let parties = JSON.parse(partiesJson); // TODO shouldn't mina-signer just take the json string?
  let { data } = client.signTransaction({ parties, feePayer }, feePayerKey);
  console.log(data.parties);
}

if (command === "update") {
  // snarkyjs part
  let { provers } = SimpleZkapp.compile(zkappAddress);
  let partiesJson = await call(
    SimpleZkapp,
    zkappAddress,
    "update",
    [Field(3)],
    provers
  );

  // mina-signer part
  let client = new Client({ network: "testnet" });
  let feePayerAddress = client.derivePublicKey(feePayerKey);
  let feePayer = {
    feePayer: feePayerAddress,
    fee: transactionFee,
    nonce: feePayerNonce,
  };
  let parties = JSON.parse(partiesJson);
  let { data } = client.signTransaction({ parties, feePayer }, feePayerKey);
  console.log(data.parties);
}

shutdown();

function parseCommandLineArgs() {
  return process.argv.slice(2).map((arg) => {
    try {
      return JSON.parse(arg);
    } catch {
      return arg;
    }
  });
}
