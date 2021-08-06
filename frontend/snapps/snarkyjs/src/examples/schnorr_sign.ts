import { Poseidon, Circuit as C, Group, Field, Bool, Scalar } from '../bindings/snarky';
import { public_, circuitMain, prop, CircuitValue } from '../circuit_value';

type PrivateKey = Scalar;

class Signature extends CircuitValue {
  @prop r: Field;
  @prop s: Scalar;

  constructor(r: Field, s: Scalar) {
    super();
    this.r = r;
    this.s = s;
  }

  static create(d: PrivateKey, msg: Field[]) : Signature {
    const publicKey = Group.generator.scale(d);
    const kPrime = Scalar.random();
    let { x: r, y: ry } = Group.generator.scale(kPrime);
    const k = ry.toBits()[0].toBoolean() ? kPrime.neg() : kPrime;
    const e = Scalar.ofBits(Poseidon.hash(msg.concat([publicKey.x, publicKey.y, r])).toBits());
    const s = e.mul(d).add(k);
    return new Signature(r, s)
  }

  verify(this: this, pubKey: Group, msg: Field[]): Bool {
    let e = Scalar.ofBits(Poseidon.hash(msg.concat([pubKey.x, pubKey.y, this.r])).toBits());
    let r = pubKey.scale(e).neg().add(Group.generator).scale(this.s);
    return Bool.and(
      r.x.equals(this.r),
      r.y.toBits()[0].equals(false)
    )
  }
};

class Witness extends CircuitValue {
  @prop signature: Signature;
  @prop acc: Group;
  @prop r: Scalar;

  constructor(sig: Signature, acc: Group, r: Scalar) {
    super();
    this.signature = sig;
    this.acc = acc;
    this.r = r;
  }
};

// Public input:
//  [newAcc: curve_point]
// Prove:
// I know [prevAcc: curve_point] and [signature : Signature] such that
// the signature verifies against Brave's public key and [newAcc] is
// a re-randomization of [prevAcc]

export class Main extends C {
  @circuitMain
  static main(w: Witness, @public_ newAcc: Group) {
    let H = new Group({ x: -1, y: 2 });
    let r: Scalar = C.witness(Scalar, () => w.r);
    let mask = H.scale(r);
    let prevAcc: Group = C.witness(Group, () => w.acc);
    let pubKey = Group.generator; // TODO: some literal group element
    let signature = C.witness<Signature>(Signature, () => w.signature);
    signature.verify(pubKey, [prevAcc.x, prevAcc.y, signature.r]).assertEquals(true);
    prevAcc.add(mask).assertEquals(newAcc);
  }
}

class Circ extends C {
  @circuitMain
  static main(@public_ x: Field) {
    let acc = x;
    for (let i = 0; i < 1000; ++i) {
      acc = acc.mul(acc);
    }
  }
};

function testSigning() {
  const msg = [ Field.random() ];
  const privKey = Scalar.random();
  const pubKey = Group.generator.scale(privKey);
  const s = Signature.create(privKey, msg);
  console.log('signing worked', s.verify(pubKey, msg));
}

export function main() {
  const before = new Date();
  const kp = Circ.generateKeypair();
  const after = new Date();
  testSigning();
  console.log('keypairgen', after.getTime() - before.getTime());
  console.log('random', Field.random());
  const proof = Circ.prove([], [ new Field(2) ], kp);
  console.log(proof, kp);
}
