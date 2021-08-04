import * as Snarky from './bindings/snarky';

const MerkleProofFactory = (depth: number) => {
  return class MerkleProof {
    path: Array<[Snarky.Bool, Snarky.Field]>;

    verify(rootHash: Snarky.Field, eltHash: Snarky.Field) {
      // TODO
    }

    constructor(path: Array<[Snarky.Bool, Snarky.Field]>) {
      this.path = path;
    }

    static sizeInFieldElements(): number {
      return depth;
    }

    static toFieldElements(t: MerkleProof): Snarky.Field[] {
      return t.path.flatMap(([a, h]) => [a.toField(), h]);
    }

    static ofFieldElements(xs: Snarky.Field[]): MerkleProof {
      let res: Array<[Snarky.Bool, Snarky.Field]> = [];
      if (xs.length !== 2 * depth) {
        throw new Error('Wrong path length');
      }

      for (let i = 0; i < depth; ++i) {
        res.push([Snarky.Bool.Unsafe.ofField(xs[2 * i]), xs[2 * i + 1]]);
      }
      return new MerkleProof(res);
    }

    static check(t: MerkleProof) {
      t.path.forEach(([b, _]) => {
        b.toField().assertBoolean();
      });
    }
  };
};
