// test proving a basic circuit

import snarkyjs from "./snarkyjs.js";
await snarkyjs.snarky_ready;
let { Poseidon, Circuit, Field } = snarkyjs;

export { basicCircuit };

let FieldArrayTyp = (size) => ({
  sizeInFields: () => size,
  toFields: (f) => f,
  ofFields: (f) => f,
  check: () => {},
});
class Main extends Circuit {
  static snarkyMain(preimage, [hash]) {
    Poseidon.hash(preimage).assertEquals(hash);
  }
  static snarkyWitnessTyp = FieldArrayTyp(4);
  static snarkyPublicTyp = FieldArrayTyp(1);
}

function basicCircuit() {
  let name = "basic circuit test";
  console.log(name);
  let preimage = [
    Field.random(),
    Field.random(),
    Field.random(),
    Field.random(),
  ];
  let hash = Poseidon.hash(preimage);

  console.log("generating keypair...");
  let kp = Main.generateKeypair();

  console.log("prove...");
  let proof = Main.prove(preimage, [hash], kp);

  console.log("verify...");
  let ok = Main.verify([hash], kp.verificationKey(), proof);

  console.log("ok?", ok);
  if (!ok) throw Error(`${name} failed`);
}
