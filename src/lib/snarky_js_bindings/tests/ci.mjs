import Client from "../../../../frontend/mina-signer/dist/src/MinaSigner.js";
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
} from "../snarkyjs/dist/server/index.js";

await isReady;
// TODO check if floats are converted to Field correctly
const initialBalance = 10_000_000_000;
const transactionFee = 10_000_000;
const initialState = Field(1);

class SimpleZkapp extends SmartContract {
  constructor(address) {
    super(address);
    this.x = State();
  }

  deploy() {
    super.deploy();
    let amount = UInt64.fromNumber(initialBalance);
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

// create new random zkapp key
let zkappPrivateKey = PrivateKey.random();
let zkappAddress = zkappPrivateKey.toPublicKey();

let [command, feePayerKey, feePayerNonce] = parseCommandLineArgs();
feePayerKey ||= "EKEnXPN95QFZ6fWijAbhveqGtQZJT2nHptBMjFijJFb5ZUnRnHhg";

if (command === "deploy") {
  let { verificationKey } = compile(SimpleZkapp, zkappAddress);
  let partiesJson = deploy(SimpleZkapp, zkappAddress, verificationKey);
  let parties = JSON.parse(partiesJson);

  let client = new Client({ network: "testnet" });
  let feePayerAddress = client.derivePublicKey(feePayerKey);
  let feePayer = {
    feePayer: feePayerAddress,
    fee: transactionFee + initialBalance,
    nonce: feePayerNonce,
  };
  let { data } = client.signTransaction({ parties, feePayer }, feePayerKey);
  console.log(data.parties);
}

if (command === "update") {
  // compile once more, to get the provers :'/
  let { provers } = SimpleZkapp.compile(zkappAddress);
  // TODO getting length mismatch because proof to_string / of_string differ
  let partiesJson = await call(
    SimpleZkapp,
    zkappAddress,
    "update",
    [Field(3)],
    provers
  );
  // TODO sign
  console.log(partiesJson);
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
