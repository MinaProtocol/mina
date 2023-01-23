import { SelfProof, Field, Experimental, isReady, shutdown } from "snarkyjs";
import { tic, toc } from "./tictoc.js";

await isReady;

let MaxProofsVerifiedZero = Experimental.ZkProgram({
  publicInput: Field,

  methods: {
    baseCase: {
      privateInputs: [],

      method(publicInput) {
        publicInput.assertEquals(Field.zero);
      },
    },
  },
});

let MaxProofsVerifiedOne = Experimental.ZkProgram({
  publicInput: Field,

  methods: {
    baseCase: {
      privateInputs: [],

      method(publicInput) {
        publicInput.assertEquals(Field.zero);
      },
    },

    mergeOne: {
      privateInputs: [SelfProof],

      method(publicInput, earlierProof) {
        earlierProof.verify();
        earlierProof.publicInput.add(1).assertEquals(publicInput);
      },
    },
  },
});

let MaxProofsVerifiedTwo = Experimental.ZkProgram({
  publicInput: Field,

  methods: {
    baseCase: {
      privateInputs: [],

      method(publicInput) {
        publicInput.assertEquals(Field.zero);
      },
    },

    mergeOne: {
      privateInputs: [SelfProof],

      method(publicInput, earlierProof) {
        earlierProof.verify();
        earlierProof.publicInput.add(1).assertEquals(publicInput);
      },
    },

    mergeTwo: {
      privateInputs: [SelfProof, SelfProof],

      method(publicInput, p1, p2) {
        p1.verify();
        p1.publicInput.add(1).assertEquals(p2.publicInput);
        p2.verify();
        p2.publicInput.add(1).assertEquals(publicInput);
      },
    },
  },
});
tic("compiling three programs..");
await MaxProofsVerifiedZero.compile();
await MaxProofsVerifiedOne.compile();
await MaxProofsVerifiedTwo.compile();
toc();

await testRecursion(MaxProofsVerifiedZero, 0);
await testRecursion(MaxProofsVerifiedOne, 1);
await testRecursion(MaxProofsVerifiedTwo, 2);

async function testRecursion(Program, maxProofsVerified) {
  console.log(`testing maxProofsVerified = ${maxProofsVerified}`);

  let ProofClass = Experimental.ZkProgram.Proof(Program);

  tic("executing base case..");
  let initialProof = await Program.baseCase(Field(0));
  toc();
  initialProof = testJsonRoundtrip(ProofClass, initialProof);
  initialProof.verify();
  initialProof.publicInput.assertEquals(Field(0));

  if (initialProof.maxProofsVerified != maxProofsVerified) {
    throw Error(
      `Expected initialProof to have maxProofsVerified = ${maxProofsVerified} but has ${initialProof.maxProofsVerified}`
    );
  }

  let p1, p2;
  if (initialProof.maxProofsVerified == 0) return;

  tic("executing mergeOne..");
  p1 = await Program.mergeOne(Field(1), initialProof);
  toc();
  p1 = testJsonRoundtrip(ProofClass, p1);
  p1.verify();
  p1.publicInput.assertEquals(Field(1));
  if (p1.maxProofsVerified != maxProofsVerified) {
    throw Error(
      `Expected p1 to have maxProofsVerified = ${maxProofsVerified} but has ${p1.maxProofsVerified}`
    );
  }

  if (initialProof.maxProofsVerified == 1) return;
  tic("executing mergeTwo..");
  p2 = await Program.mergeTwo(Field(2), initialProof, p1);
  toc();
  p2 = testJsonRoundtrip(ProofClass, p2);
  p2.verify();
  p2.publicInput.assertEquals(Field(2));
  if (p2.maxProofsVerified != maxProofsVerified) {
    throw Error(
      `Expected p2 to have maxProofsVerified = ${maxProofsVerified} but has ${p2.maxProofsVerified}`
    );
  }
}

function testJsonRoundtrip(ProofClass, proof) {
  let jsonProof = proof.toJSON();
  console.log(
    "json roundtrip",
    JSON.stringify({ ...jsonProof, proof: jsonProof.proof.slice(0, 10) + ".." })
  );
  return ProofClass.fromJSON(jsonProof);
}

shutdown();
