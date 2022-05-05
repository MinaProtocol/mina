import Client from "mina-signer";
import {
  Field,
  declareState,
  declareMethods,
  State,
  PrivateKey,
  SmartContract,
  compile,
  deploy,
  call,
  isReady,
  shutdown,
  signFeePayer,
} from "snarkyjs";
import { tic, toc } from "./tictoc.js";

await isReady;

// PART 1: snarkyjs

// declare the zkapp in snarkyjs
const transactionFee = 1_000_000_000;
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

  update(x) {
    this.x.set(x);
  }
}
// note: this is our non-typescript way of doing what our decorators do
declareState(SimpleZkapp, { x: Field });
declareMethods(SimpleZkapp, { update: [Field] });

// create new random zkapp keypair (with snarkyjs)
let zkappKey = PrivateKey.random();
let zkappAddress = zkappKey.toPublicKey();

// compile smart contract (= Pickles.compile)
tic("compile smart contract");
let { verificationKey, provers } = await compile(SimpleZkapp, zkappAddress);
toc();

// deploy transaction
tic("create deploy transaction");
let partiesJsonDeploy = await deploy(SimpleZkapp, {
  zkappKey,
  verificationKey,
});
toc();

// update transaction
tic("create update transaction (with proof)");
let partiesJsonUpdate = await call(
  SimpleZkapp,
  zkappAddress,
  "update",
  [Field(3)],
  provers
);
toc();

// PART 2: mina-signer
let client = new Client({ network: "testnet" });

// TODO create new random sender keypair (with mina-signer, in string format)
let feePayerKey = "EKEnXPN95QFZ6fWijAbhveqGtQZJT2nHptBMjFijJFb5ZUnRnHhg";
let feePayerAddress = client.derivePublicKey(feePayerKey);

// sign deploy txn
tic("sign deploy transaction");
let feePayerNonce = 0;
let signedDeploy = client.signTransaction(
  {
    parties: JSON.parse(partiesJsonDeploy),
    feePayer: {
      feePayer: feePayerAddress,
      fee: `${transactionFee}`,
      nonce: feePayerNonce,
    },
  },
  feePayerKey
);
toc();

// check that signature matches with the one snarkyjs creates on the same transaction
tic("sign deploy transaction (snarkyjs, for consistency check)");
let signedDeploySnarkyJs = await signFeePayer(partiesJsonDeploy, feePayerKey, {
  transactionFee,
  feePayerNonce,
});
if (
  JSON.parse(signedDeploySnarkyJs).feePayer.authorization !==
  JSON.parse(signedDeploy.data.parties).feePayer.authorization
)
  throw Error("Inconsistent fee payer signature");
toc();

feePayerNonce++;

// sign update txn
tic("sign update transaction");
let signedUpdate = client.signTransaction(
  {
    parties: JSON.parse(partiesJsonUpdate),
    feePayer: {
      feePayer: feePayerAddress,
      fee: `${transactionFee}`,
      nonce: feePayerNonce,
    },
  },
  feePayerKey
);
toc();

// check that signature matches with the one snarkyjs creates on the same transaction
tic("sign update transaction (snarkyjs, for consistency check)");
let signedUpdateSnarkyJs = await signFeePayer(partiesJsonUpdate, feePayerKey, {
  transactionFee,
  feePayerNonce,
});
if (
  JSON.parse(signedUpdateSnarkyJs).feePayer.authorization !==
  JSON.parse(signedUpdate.data.parties).feePayer.authorization
)
  throw Error("Inconsistent fee payer signature");
toc();

console.log("success! created and signed two transactions.");

shutdown();
