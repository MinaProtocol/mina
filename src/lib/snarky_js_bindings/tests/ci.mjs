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
declareState(SimpleZkapp, { x: Field });
declareMethodArguments(SimpleZkapp, { update: [Field] });

// create new random zkapp key
let zkappPrivateKey = PrivateKey.random();
let zkappAddress = zkappPrivateKey.toPublicKey();

let [isDeploy, feePayerKey, feePayerNonce] = parseCommandLineArgs();

console.log(isDeploy ? "deploy" : "update", feePayerKey, feePayerNonce);

if (isDeploy) {
  let { verificationKey } = compile(SimpleZkapp, zkappAddress);
  let partiesJson = deploy(SimpleZkapp, zkappAddress, verificationKey);
  let parties = JSON.parse(partiesJson);

  let feePayerKeySnarky = new PrivateKey(Scalar.fromJSON(feePayerKey));
  let feePayerAddress = feePayerKeySnarky.toPublicKey();
  let feePayer = {
    feePayer: "TODO string derived from feePayerAddress",
    fee: 1_000_000,
    nonce: feePayerNonce,
  };

  let client = new Client({ network: "testnet" });
  let {
    data: { parties: signedParties },
  } = client.signParty({ parties, feePayer }, feePayerKey);
  console.log(signedParties);
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
