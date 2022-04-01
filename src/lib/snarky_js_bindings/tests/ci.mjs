import Client from "../../../../frontend/mina-signer/dist/src/MinaSigner.js";
import {
  Field,
  declareState,
  declareMethodArguments,
  State,
  UInt64,
  PrivateKey,
  Scalar,
  SmartContract,
  compile,
  deploy,
  Party,
  isReady,
  shutdown,
} from "../snarkyjs/dist/server/index.js";

await isReady;
const initialBalance = 10_000_000;
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

let [isDeploy, feePayerKey, feePayerNonce] = parseCommandLineArgs();
let isUpdate = !isDeploy;

// console.log(isDeploy ? "deploy" : "update", feePayerKey, feePayerNonce);

if (isDeploy) {
  let { verificationKey } = compile(SimpleZkapp, zkappAddress);
  let partiesJson = deploy(SimpleZkapp, zkappAddress, verificationKey);
  let parties = JSON.parse(partiesJson);

  let client = new Client({ network: "testnet" });

  let feePayerAddress = client.derivePublicKey(feePayerKey);
  let feePayer = {
    feePayer: feePayerAddress,
    fee: 1_000_000,
    nonce: feePayerNonce,
  };

  let {
    data: { parties: signedParties },
  } = client.signParty({ parties, feePayer }, feePayerKey);
  console.log(signedParties);
}

if (isUpdate) {
  // compile once more, to get the provers :'/
  let { provers } = SimpleZkapp.compile(zkappAddress);
  let zkapp = new SimpleZkapp(zkappAddress);
  let { proof, statement } = await zkapp.prove(provers, "update", [Field(3)]);
  // TODO create tx during proof, add proof to it
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
