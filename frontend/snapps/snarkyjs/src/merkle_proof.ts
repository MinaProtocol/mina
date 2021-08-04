
import { Field, Bool } from './bindings/snarky';

const MerkleProofFactory = (depth : number) => {
  return class MerkleProof {
    path: Array<[Bool, Field]>

    verify(rootHash: Field, eltHash: Field) {
      // TODO
    }

    constructor(path: Array<[Bool, Field]>) {
      this.path = path;
    }

    static sizeInFieldElements(): number {
      return depth;
    }

    static toFieldElements(t : MerkleProof) : Field[] {
      return t.path.flatMap(([a, h]) => [a.toField(), h]);
    }

    static ofFieldElements(xs: Field[]) : MerkleProof {
      let res : Array<[Bool, Field]> = [];
      if (xs.length !== 2 * depth) {
        throw (new Error('Wrong path length'))
      }

      for (let i = 0; i < depth; ++i) {
        res.push(
          [ Bool.Unsafe.ofField(xs[2 * i]), xs[2 * i + 1] ]);
      }
      return new MerkleProof(res);
    }

    static check(t: MerkleProof) {
      t.path.forEach(([b, _]) => {
        b.toField().assertBoolean();
      });
    }
  }
};
