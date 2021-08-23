import { Poseidon, Field, Circuit } from '../snarky';
import { circuitMain, public_ } from '../circuit_value';

/* Exercise 0:

Public input: a hash value h
Prove:
  I know a value x such that hash(x) = h 
*/

class Main extends Circuit {
  @circuitMain
  static main(preimage: Field, @public_ hash: Field) {
    Poseidon.hash([preimage]).assertEquals(hash);
  }
}

const kp = Main.generateKeypair();

const preimage = Field.random();
const hash = Poseidon.hash([preimage]);
const pi = Main.prove([preimage], [hash], kp);
console.log('proof', pi);