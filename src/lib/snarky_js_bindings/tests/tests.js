import snarkyjs from "./snarkyjs.js";
await snarkyjs.snarky_ready;

let { Poseidon, Circuit, Field } = snarkyjs;

let FieldTyp = {
  sizeInFields: () => 1,
  toFields: (f) => f,
  ofFields: (f) => f,
};

// test proving a basic circuit

class Main extends Circuit {
  static snarkyMain([preimage], [hash]) {
    Poseidon.hash([preimage]).assertEquals(hash);
  }
  static snarkyWitnessTyp = FieldTyp;
  static snarkyPublicTyp = FieldTyp;
}

let preimage = Field.one;
let hash = Poseidon.hash([preimage]);

console.log("generating keypair...");
let kp = Main.generateKeypair();

console.log("prove...");
let proof = Main.prove([preimage], [hash], kp);

console.log("verify...");
let ok = Main.verify([hash], kp.verificationKey(), proof);

console.log("ok?", ok);
snarkyjs.shutdown();
