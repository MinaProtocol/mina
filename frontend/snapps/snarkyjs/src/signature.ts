import * as Snarky from './bindings/snarky';
import { public_, circuitMain, prop, CircuitValue } from './circuit_value';

export class Signature extends CircuitValue {
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
    return Snarky.Bool.and(r.x.equals(this.r), r.y.toBits()[0].equals(false));
  }
}
