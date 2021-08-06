import { Poseidon, Group, Field, Bool, Scalar } from './bindings/snarky';
import { public_, circuitMain, prop, CircuitValue } from './circuit_value';

export class Signature extends CircuitValue {
  @prop r: Field;
  @prop s: Scalar;

  constructor(r: Field, s: Scalar) {
    super();
    this.r = r;
    this.s = s;
  }

  verify(this: this, pubKey: Group, msg: Field[]): Bool {
    let e = Scalar.ofBits(Poseidon.hash(msg).toBits());
    let r = pubKey.scale(e).neg().add(Group.generator).scale(this.s);
    return Bool.and(r.x.equals(this.r), r.y.toBits()[0].equals(false));
  }
}
