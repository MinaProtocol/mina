import { basicCircuit } from "./basic-circuit.mjs";
import { picklesProof } from "./pickles-proof.mjs";

await basicCircuit();
await picklesProof();
process.exit(0);
