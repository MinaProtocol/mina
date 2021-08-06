import { Poseidon, Group, Field, Bool, Scalar } from './bindings/snarky';
import { prop, CircuitValue } from './circuit_value';

export type PrivateKey = Scalar;

export class Signature extends CircuitValue {
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
    let r = pubKey.scale(e).neg().add(Group.generator.scale(this.s));
    return Bool.and(r.x.equals(this.r), r.y.toBits()[0].equals(false));
  }
};
