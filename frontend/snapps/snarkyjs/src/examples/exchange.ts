// import { MerkleCollection, MerkleProof } from '../mina.js';
import { Circuit as C, Field, Bool, AsField, Scalar } from '../snarky';
import { public_, circuitMain, prop, CircuitValue } from '../circuit_value';
import { Trade, HTTPSAttestation, Bytes, WebSnappRequest } from './exchange_lib';
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

export class Main extends C {
  @circuitMain
  // percentGain is an integer in basis points
  static main(witness: Witness, @public_ percentChange : Field) {
    witness.attestation.verify(WebSnappRequest.ofString('api.coinbase.com/trades'));
    const trades = Trade.readAll(witness.attestation.response);

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

function getElt<A>(xs: Array<A>, i : Field) : A {
  let [ x, found ] = xs.reduce(([acc, found], x, j) => {
    let eltHere = i.equals(j);
    return [ C.if(eltHere, x, acc), found.or(eltHere) ];
  }, [ xs[0], new Bool(false)]);
  found.assertEquals(true);
  return x;
}

type TradeObject = { timestamp: Field, price: Field, quantity: Field, isBuy: Bool };
function trade({ timestamp, price, quantity, isBuy } : TradeObject) : Trade {
  return new Trade(isBuy, price, quantity, timestamp);
}

export function main() {
  let before = new Date();
  const kp = Main.generateKeypair();
  let after = new Date();
  console.log('generated keypair: ', after.getTime() - before.getTime());

  const publicInput = [ new Field(25) ];
  before = new Date();
  const proof = Main.prove([
    { buyIndex: new Field(0), sellIndex: new Field(1), attestation: new HTTPSAttestation(new Bytes([
      trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
      trade({ timestamp: new Field(250), price: new Field(500), quantity: new Field(4), isBuy: new Bool(false) })
    ]), new Signature(new Field(1), Scalar.random()))  }
  ], publicInput, kp);
  after = new Date();

  console.log('generated proof: ', after.getTime() - before.getTime());
  const vk = kp.verificationKey();
  console.log(proof, kp, 'verified?', proof.verify(vk, publicInput));
};
