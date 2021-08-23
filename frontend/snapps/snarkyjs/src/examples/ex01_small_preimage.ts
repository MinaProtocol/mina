import { Poseidon, Field, Circuit } from '../snarky';
import { circuitMain, public_ } from '../circuit_value';

/* Exercise 1:

Public input: a hash value h
Prove:
  I know a value x < 2^32 such that hash(x) = h 
*/

class Main extends Circuit {
  @circuitMain
  static main(preimage: Field, @public_ hash: Field) {
    preimage.toBits(32);
    Poseidon.hash([preimage]).assertEquals(hash);
  }
}

const kp = Main.generateKeypair();

const preimage = Field.ofBits(Field.random().toBits().slice(0, 32));
const hash = Poseidon.hash([preimage]);
const pi = Main.prove([preimage], [hash], kp);
console.log('proof', pi);