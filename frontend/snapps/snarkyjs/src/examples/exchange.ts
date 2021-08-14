// import { MerkleCollection, MerkleProof } from '../mina.js';
import { Circuit as C, Field, Bool, AsField, Scalar } from '../bindings/snarky2';
import { public_, circuitMain, prop, CircuitValue } from '../circuit_value';
import { TradePair, Trade, HTTPSAttestation, Bytes, WebSnappRequest } from './exchange_lib';
import { Signature } from '../signature';

// Proof of bought low sold high for bragging rights
// 
// Prove I did a trade that did "X%" increase

class Witness extends CircuitValue {
  @prop pairIndex: Field;
  @prop attestation: HTTPSAttestation

  constructor(pairIndex: Field, a: HTTPSAttestation) {
    super();
    this.pairIndex = pairIndex;
    this.attestation = a;
  }
}

export class Main extends C {
  @circuitMain
  // percentGain is an integer in basis points
  static main(witness: Witness, @public_ percentChange : Field) {
    witness.attestation.verify(WebSnappRequest.ofString('api.coinbase.com/trades'));
    const tradePairs = TradePair.readAll(witness.attestation.response);

    let pair = getElt(tradePairs, witness.pairIndex);
    let buyTotal = new Field(0);
    let buyQuantities = new Field(0);
    let sellTotal = new Field(0);
    let sellQuantities = new Field(0);
    [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade1, [buyTotal, buyQuantities, sellTotal, sellQuantities]);
    [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade2, [buyTotal, buyQuantities, sellTotal, sellQuantities]);
    [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade3, [buyTotal, buyQuantities, sellTotal, sellQuantities]);
    [buyTotal, buyQuantities, sellTotal, sellQuantities] = accumulateTrade(pair.trade4, [buyTotal, buyQuantities, sellTotal, sellQuantities]);

    pair.trade1.timestamp.assertLt(pair.trade2.timestamp);
    pair.trade2.timestamp.assertLt(pair.trade3.timestamp);
    pair.trade3.timestamp.assertLt(pair.trade4.timestamp);

    const FULL_BASIS = new Field(10000);
    // sellTotal * (10000 + percentChange) > buyTotal * 10000;
    sellTotal.mul(FULL_BASIS.add(percentChange)).assertGte(
      buyTotal.mul(FULL_BASIS));
  }
}

// takes [buyTotal, buyQuantities, sellTotal, sellQuantities] returns new ones
function accumulateTrade(trade: Trade, totals: [Field, Field, Field, Field]): [Field, Field, Field, Field] {
  let [buyTotal, buyQuantities, sellTotal, sellQuantities] = totals;
  let spent = trade.quantity.mul(trade.price);
  [buyTotal, buyQuantities] = C.if(trade.isBuy, [ buyTotal.add(spent), buyQuantities.add(trade.quantity) ], [ buyTotal, buyQuantities ]);
  [sellTotal, sellQuantities] = C.if(trade.isBuy, [ sellTotal, sellQuantities ], [ sellTotal.add(spent), sellQuantities.add(trade.quantity) ]);
  return [ buyTotal, buyQuantities, sellTotal, sellQuantities ];
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

function tradePair(trades: Array<Trade>): TradePair {
  return new TradePair(trades[0], trades[1], trades[2], trades[3]);
}

export function main() {
  let before = new Date();
  const kp = Main.generateKeypair();
  let after = new Date();
  console.log('generated keypair: ', after.getTime() - before.getTime());

  const publicInput = [ new Field(25) ];
  before = new Date();
  const proof = Main.prove([
    { pairIndex: new Field(1), attestation: new HTTPSAttestation(new Bytes([
      tradePair([
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) })
      ]),
      tradePair([
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(100), price: new Field(120), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(300), price: new Field(150), quantity: new Field(5), isBuy: new Bool(false) })
      ]),
      tradePair([
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) }),
        trade({ timestamp: new Field(150), price: new Field(100), quantity: new Field(5), isBuy: new Bool(true) })
      ])
    ]), new Signature(new Field(1), Scalar.random()))  }
  ], publicInput, kp);
  after = new Date();

  console.log('generated proof: ', after.getTime() - before.getTime());
  const vk = kp.verificationKey();
  console.log(proof, kp, 'verified?', proof.verify(vk, publicInput));
};
