// import { MerkleCollection, MerkleProof } from '../mina.js';
import { Group, Bool, Field } from '../bindings/snarky';
import { prop, CircuitValue } from '../circuit_value';
import { Signature } from '../signature';

type TradeObject = { timestamp: Field, price: Field, quantity: Field, isBuy: Bool };

export class Bytes extends CircuitValue {
  value: Array<TradeObject>

  toFieldElements(this:Bytes): Field[] { return [] }

  constructor(value: Array<TradeObject>) {
    super();
    this.value = value;
  }

  static ofString(_ : string): Bytes {
    return new Bytes([]);
  }

  static readAll<A>(ctor: { read: (bs:Bytes) => null | [Bytes, A] }, bs: Bytes): Array<A> {
    let xs = [];
    let res;
    while (true) {
      res = ctor.read(bs);
      if (res === null) {
        break;
      } else {
        let [ bsPrime, x ] = res;
        bs = bsPrime;
        xs.push(x);
      }
    }
    return xs;
  }
}

export class HTTPSAttestation extends CircuitValue {
  @prop response: Bytes;
  @prop signature: Signature;

  constructor(resp: Bytes, sig: Signature) {
    super();
    this.response = resp;
    this.signature = sig;
  }

  verify(_request: Bytes) {
    //const O1PUB: Group = Group.generator;
    //this.signature.verify(O1PUB, request.toFieldElements().concat(this.response.toFieldElements()))
  }
}


