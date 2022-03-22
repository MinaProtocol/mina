import { shutdown } from "./snarkyjs.js";
import { basicCircuit } from "./basic-circuit.mjs";
import { picklesProof } from "./pickles-proof.mjs";

await basicCircuit();
await picklesProof();
shutdown();
