// import { MerkleCollection, MerkleProof } from '../mina.js';
import { Circuit as C, Field, Bool, AsField, Scalar } from '../bindings/snarky2';
import { public_, circuitMain, prop, CircuitValue } from '../circuit_value';
import { HTTPSAttestation, Bytes } from './exchange_lib';
import { Signature } from '../signature';

// Proof of bought low sold high for bragging rights
// 
// Prove I did a trade that did "X%" increase

class Witness extends CircuitValue {
  @prop buyIndex: Field;
  @prop sellIndex: Field;
  @prop attestation: HTTPSAttestation

  constructor(buy: Field, sell: Field, a: HTTPSAttestation) {
    super();
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

function getElt<A>(xs: Array<A>, i_ : AsField) : A {
  let i = new Field(i_);
  let [ x, found ] = xs.reduce(([acc, found], x, j) => {
    let eltHere = i.equals(j);
    return [ C.if(eltHere, x, acc), found.or(eltHere) ];
  }, [ xs[0], new Bool(false)]);
  found.assertEquals(true);
  return x;
}

export function main() {
  const before = new Date();
  const kp = Main.generateKeypair();
  const after = new Date();
  console.log('keypairgen', after.getTime() - before.getTime());
  const proof = Main.prove([
    { buyIndex: new Field(0), sellIndex: new Field(1), attestation: new HTTPSAttestation(new Bytes([
      { timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) },
      { timestamp: new Field(250), price: new Field(500), quantity: new Field(4), isBuy: new Bool(false) }
    ]), new Signature(new Field(1), Scalar.random()))  }
  ], [ new Field(25) ], kp);
  console.log(proof, kp);
};
