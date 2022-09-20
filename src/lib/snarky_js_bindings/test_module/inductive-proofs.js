import { SelfProof, Field, Experimental, isReady, shutdown } from "snarkyjs";
import { tic, toc } from "./tictoc.js";

await isReady;

let MyProgram = Experimental.ZkProgram({
  publicInput: Field,

  methods: {
    baseCase: {
      privateInputs: [],

      method(publicInput) {
        publicInput.assertEquals(Field.zero);
      },
    },

    inductiveCase: {
      privateInputs: [SelfProof],

      method(publicInput, earlierProof) {
        earlierProof.verify();
        earlierProof.publicInput.add(1).assertEquals(publicInput);
      },
    },
  },
});

tic("compiling MyProgram");
await MyProgram.compile();
toc();

tic("proving base case");
let proof = await MyProgram.baseCase(Field.zero);
toc();

tic("proving step 1");
proof = await MyProgram.inductiveCase(Field.one, proof);
toc();

tic("proving step 2");
proof = await MyProgram.inductiveCase(Field(2), proof);
toc();

console.log("ok?", proof.publicInput.toString() === "2");

shutdown();
