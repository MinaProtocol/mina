// import { MerkleCollection, MerkleProof } from '../mina.js';
import { Circuit, Scalar, Group, Bool, Field } from '../bindings/snarky2';
import { prop, CircuitValue } from '../circuit_value';
import { Signature } from '../signature';

// type TradeObject = { timestamp: Field, price: Field, quantity: Field, isBuy: Bool };

export class Trade extends CircuitValue {
  @prop isBuy: Bool
  @prop price: Field
  @prop quantity: Field
  @prop timestamp: Field

  constructor(isBuy: Bool, price: Field, quantity: Field, timestamp: Field) {
    super();
    this.isBuy = isBuy;
    this.price = price;
    this.quantity = quantity;
    this.timestamp = timestamp;
  }
}

// TODO: Make this an array of trades too
export class TradePair extends CircuitValue {
  @prop trade1: Trade
  @prop trade2: Trade
  @prop trade3: Trade
  @prop trade4: Trade

  constructor(trade1: Trade, trade2: Trade, trade3: Trade, trade4: Trade) {
    super();
    this.trade1 = trade1;
    this.trade2 = trade2;
    this.trade3 = trade3;
    this.trade4 = trade4;
  }

  static readAll(bytes: Bytes) : Array<TradePair> {
    return bytes.value;
  }
}

console.log('trade size', Trade.sizeInFieldElements());

const numTradePairs = 3;

export class Bytes extends CircuitValue {
  value: Array<TradePair>

  constructor(value: Array<TradePair>) {
    super();
    console.assert(value.length === numTradePairs);
    this.value = value;
  }
}

(Bytes.prototype as any)._fields = [ ['value', Circuit.array(TradePair, numTradePairs) ] ];

export class WebSnappRequest extends CircuitValue {
  constructor() {
    super()
  }

  static ofString(_ : string): WebSnappRequest {
    return new WebSnappRequest();
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

  verify(_request: WebSnappRequest) {
    //const O1PUB: Group = Group.generator;
    //this.signature.verify(O1PUB, request.toFieldElements().concat(this.response.toFieldElements()))
  }
}


