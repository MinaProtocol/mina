import { Circuit, Field, AsField, toFieldElements, ofFieldElements, sizeInFieldElements } from './plonk';
import { poseidon } from './poseidon';
import { Group, Scalar } from './group';

class Signature {
  r: Field;
  s: Scalar;
  constructor(r: Field, s: Scalar) {
    this.r = r;
    this.s = s;
  }

  static toFieldElements(this: Signature) {
    return toFieldElements([Field, Scalar], [this.r, this.s]);
  }
  static ofFieldElements(fields: Field[]) {
    let [r, s] = ofFieldElements([Field, Scalar], fields);
    return new Signature(r, s);
  }
  static sizeInFieldElements() {
    return sizeInFieldElements([Field, Scalar]);
  }
};

class Witness {
  signature: Signature;
  acc: Group;
  r: Scalar;
  constructor(sig: Signature, acc: Group, r: Scalar) {
    this.signature = sig;
    this.acc = acc;
    this.r = r;
  }
};

function verifySignature(pubKey: Group, sig: Signature, msg: Array<Field>) {
  let e = poseidon(msg).unpack();
  let r = pubKey.endoScale(e).neg().add(Group.generator().scale(sig.s));
  r.x.assertEqual(sig.r);
  r.y.unpack()[0].assertEqual(false);
}

// Public input:
//  [newAcc: curve_point]
// Prove:
// I know [prevAcc: curve_point] and [signature : Signature] such that
// the signature verifies against Brave's public key and [newAcc] is
// a re-randomization of [prevAcc]

function main(c: Circuit, w: Witness, newAcc: Group) {
  let H = new Group({ x: -1, y: 2 });
  let r: Scalar = c.witness(Scalar, () => w.r);
  let mask = H.scale(r);
  let prevAcc: Group = c.witness(Group, () => w.acc);
  let pubKey = Group.ofString("..."); // some literal group element
  let signature = c.witness(Signature, () => w.signature);
  verifySignature(pubKey, signature, [prevAcc.x, prevAcc.y, signature.r])
  prevAcc.add(mask).assertEqual(newAcc);
}

