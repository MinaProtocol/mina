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
    y.assertGt(0);
    this.x.set(x.add(y));
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethods(SimpleZkapp, { update: [Field] });

// parse command line; for local testing, use random keys as fallback
let [command, zkappKeyBase58, feePayerKeyBase58, feePayerNonce] =
  process.argv.slice(2);
zkappKeyBase58 ||= PrivateKey.random().toBase58();
feePayerKeyBase58 ||= PrivateKey.random().toBase58();
feePayerNonce ||= command === "update" ? "2" : "0";
console.log(
  `simple-zkapp.js: Running "${command}" with zkapp key ${zkappKeyBase58}, fee payer key ${feePayerKeyBase58} and fee payer nonce ${feePayerNonce}`
);

let zkappKey = PrivateKey.fromBase58(zkappKeyBase58);
let zkappAddress = zkappKey.toPublicKey();

if (command === "deploy") {
  // snarkyjs part
  let feePayerKey = PrivateKey.fromBase58(feePayerKeyBase58);
  addCachedAccount({
    publicKey: feePayerKey.toPublicKey(),
    nonce: feePayerNonce,
  });

  let { verificationKey } = await SimpleZkapp.compile(zkappAddress);
  let partiesJson = await deploy(SimpleZkapp, {
    zkappKey,
    verificationKey,
    initialBalance,
    feePayerKey,
  });

  // mina-signer part
  let client = new Client({ network: "testnet" });
  let feePayerAddress = client.derivePublicKey(feePayerKeyBase58);
  let feePayer = {
    feePayer: feePayerAddress,
    fee: transactionFee,
    nonce: feePayerNonce,
  };
  let parties = JSON.parse(partiesJson);
  let { data } = client.signTransaction(
    { parties, feePayer },
    feePayerKeyBase58
  );
  console.log(data.parties);
}

if (command === "update") {
  // snarkyjs part
  addCachedAccount({
    publicKey: zkappAddress,
    zkapp: { appState: [initialState, 0, 0, 0, 0, 0, 0, 0] },
  });
  await SimpleZkapp.compile(zkappAddress);
  let transaction = await Mina.transaction(() => {
    new SimpleZkapp(zkappAddress).update(Field(2));
  });
  let partiesJson = (await transaction.prove()).toJSON();

  // mina-signer part
  let client = new Client({ network: "testnet" });
  let feePayerAddress = client.derivePublicKey(feePayerKeyBase58);
  let feePayer = {
    feePayer: feePayerAddress,
    fee: transactionFee,
    nonce: feePayerNonce,
  };
  let parties = JSON.parse(partiesJson);
  let { data } = client.signTransaction(
    { parties, feePayer },
    feePayerKeyBase58
  );
  console.log(data.parties);
}

shutdown();
