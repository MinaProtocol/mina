import * as Snarky from '../bindings/snarky';
import { public_, circuitMain, prop, CircuitValue } from '../circuit_value';

class Signature extends CircuitValue {
  @prop r: Snarky.Field;
  @prop s: Snarky.Scalar;

  constructor(r: Snarky.Field, s: Snarky.Scalar) {
    super();
    this.r = r;
    this.s = s;
  }

  verify(this: this, pubKey: Snarky.Group, msg: Snarky.Field[]): Snarky.Bool {
    let e = Snarky.Scalar.ofBits(Snarky.Poseidon.hash(msg).toBits());
    let r = pubKey.scale(e).neg().add(Snarky.Group.generator).scale(this.s);
    return Snarky.Bool.and(
      r.x.equals(this.r),
      r.y.toBits()[0].equals(false)
    )
  }
};

class Witness extends CircuitValue {
  @prop signature: Signature;
  @prop acc: Snarky.Group;
  @prop r: Snarky.Scalar;

  constructor(sig: Signature, acc: Snarky.Group, r: Snarky.Scalar) {
    super();
    this.signature = sig;
    this.acc = acc;
    this.r = r;
  }
};

console.log(Object.keys(Witness));

// Public input:
//  [newAcc: curve_point]
// Prove:
// I know [prevAcc: curve_point] and [signature : Signature] such that
// the signature verifies against Brave's public key and [newAcc] is
// a re-randomization of [prevAcc]

export class Main extends Snarky.Circuit {
  @circuitMain
  static main(w: Witness, @public_ newAcc: Snarky.Group) {
    let H = new Snarky.Group({ x: -1, y: 2 });
    let r: Snarky.Scalar = Snarky.Circuit.witness(Snarky.Scalar, () => w.r);
    let mask = H.scale(r);
    let prevAcc: Snarky.Group = Snarky.Circuit.witness(Snarky.Group, () => w.acc);
    let pubKey = Snarky.Group.generator; // TODO: some literal group element
    let signature = Snarky.Circuit.witness<Signature>(Signature, () => w.signature);
    signature.verify(pubKey, [prevAcc.x, prevAcc.y, signature.r]).assertEquals(true);
    prevAcc.add(mask).assertEquals(newAcc);
  }
}

class Circ extends Snarky.Circuit {
  @circuitMain
  static main(@public_ x: Snarky.Field) {
    let acc = x;
    for (let i = 0; i < 1000; ++i) {
      acc = acc.mul(acc);
    }
  }
}

export function main() {
  const before = new Date();
  const kp = Circ.generateKeypair();
  const after = new Date();
  console.log('keypairgen', after.getTime() - before.getTime());
  console.log('random', Snarky.Field.random());
  const proof = Circ.prove([], [ new Snarky.Field(2) ], kp);
  console.log(proof, kp);
};
