import { Field, Scalar, Group, Circuit } from '../snarky'; 
import { public_, circuitMain, prop, CircuitValue } from '../circuit_value';
import { Signature } from '../signature';

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

export class Main extends Circuit {
  @circuitMain
  static main(w: Witness, @public_ newAcc: Group) {
    let H = new Group({ x: -1, y: 2 });
    let r: Scalar = Circuit.witness(Scalar, () => w.r);
    let mask = H.scale(r);
    let prevAcc: Group = Circuit.witness(Group, () => w.acc);
    let pubKey = Group.generator; // TODO: some literal group element
    let signature = Circuit.witness<Signature>(Signature, () => w.signature);
    //signature.verify(pubKey, [prevAcc.x, prevAcc.y, signature.r]).assertEquals(true);
    prevAcc.add(mask).assertEquals(newAcc);
  }
}

class Circ extends Circuit {
  @circuitMain
  static main(@public_ x: Field) {
    let acc = x;
    for (let i = 0; i < 1000; ++i) {
      acc = acc.mul(acc);
    }
  }
}

function testSigning() {
  const _msg = [ Field.random() ];
  const privKey = Scalar.random();
  const _pubKey = Group.generator.scale(privKey);
  //const s = Signature.create(privKey, msg);
  //console.log('signing worked', s.verify(pubKey, msg).toBoolean());
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
};
