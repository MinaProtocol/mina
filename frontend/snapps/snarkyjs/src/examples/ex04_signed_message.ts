import { Field, Circuit } from '../snarky';
import { CircuitValue, prop, public_, circuitMain } from "../circuit_value";
import { Signature, PrivateKey, PublicKey } from "../signature";

class Transaction extends CircuitValue {
  @prop sender: PublicKey
  @prop receiver: PublicKey
  @prop amount: Field

  constructor(sender: PublicKey, receiver: PublicKey, amount: Field) {
    super();
    this.sender = sender;
    this.receiver = receiver;
    this.amount = amount;
  }
}

/* Exercise 4:

Public input: a field element `lowerBound`
Prove:
  I know a signed transaction, sent to a public key that I control, for an amount > x.
*/

class Main extends Circuit {
  @circuitMain
  static main(
    transaction: Transaction,
    s: Signature,
    receiverPrivKey: PrivateKey,
    @public_ lowerBound: Field)
  {
    s.verify(transaction.sender, transaction.toFieldElements()).assertEquals(true);
    transaction.receiver.assertEquals(receiverPrivKey.toPublicKey());
    transaction.amount.assertGt(lowerBound);
  }
}
