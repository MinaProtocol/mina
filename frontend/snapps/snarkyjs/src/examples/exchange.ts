// import { MerkleCollection, MerkleProof } from '../mina.js';
import { Circuit as C, Group, Field, Bool, AsField } from '../bindings/snarky';
import { public_, circuitMain, prop, CircuitValue } from '../circuit_value';
import { Signature } from '../signature';

// Proof of bought low sold high for bragging rights
// 
// Prove I did a trade that did "X%" increase

type TradeObject = { timestamp: Field, price: Field, quantity: Field, isBuy: Bool };

class Bytes extends CircuitValue {
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

class HTTPSAttestation extends CircuitValue {
  @prop response: Bytes;
  @prop signature: Signature;

  constructor(resp: Bytes, sig: Signature) {
    super();
    this.response = resp;
    this.signature = sig;
  }

  verify(request: Bytes) {
    const O1PUB: Group = Group.generator;
    this.signature.verify(O1PUB, request.toFieldElements().concat(this.response.toFieldElements()))
  }
}

class Witness {
  @prop buyIndex: Field;
  @prop sellIndex: Field;
  @prop attestation: HTTPSAttestation

  constructor(buy: Field, sell: Field, a: HTTPSAttestation) {
    this.buyIndex = buy;
    this.sellIndex = sell;
    this.attestation = a;
  }
}

class Trade {
  timestamp: Field
  isBuy: Bool
  price: Field
  quantity: Field

  static read(bs: Bytes): [Bytes, Trade] | null {
    if (bs.value.length === 0) {
      return null;
    }
    let t = bs.value[0];
    let trade = new Trade(t.isBuy, t.price, t.quantity, t.timestamp);
    return [ new Bytes(bs.value.slice(1)), trade ];
  }

  constructor(isBuy: Bool, price: Field, quantity: Field, time: Field) {
    this.isBuy = isBuy;
    this.price = price;
    this.quantity = quantity;
    this.timestamp = time;
  }
}

function getElt<A>(xs: Array<A>, i_ : AsField) : A {
  let i = new Field(i_);
  let [ x, found ] = xs.reduce(([acc, found], x, j) => {
    let eltHere = i.equals(j);
    return [ C.if(eltHere, x, acc), found.or(eltHere) ];
  }, [ xs[0], new Bool(false)]);
  found.assertEquals(true);
  return x;
}

export class Main extends C {
  @circuitMain
  // percentGain is an integer in basis points
  static main(witness: Witness, @public_ percentChange : Field) {
    witness.attestation.verify(Bytes.ofString('api.coinbase.com/trades'));
    const trades = Bytes.readAll(Trade, witness.attestation.response);

    let buy = getElt(trades, witness.buyIndex);
    let sell = getElt(trades, witness.sellIndex);
    buy.isBuy.assertEquals(true);
    sell.isBuy.assertEquals(false);

    buy.timestamp.assertLt(sell.timestamp);
    sell.quantity.assertLt(buy.quantity);

    let buyTotal = sell.quantity.mul(buy.price);
    let sellTotal = sell.quantity.mul(sell.price);

    const FULL_BASIS = new Field(10000);
    // sellTotal * (10000 + percentChange) > buyTotal * 10000;
    sellTotal.mul(FULL_BASIS.add(percentChange)).assertGte(
      buyTotal.mul(FULL_BASIS));
  }
}
