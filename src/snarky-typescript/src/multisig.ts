import { Circuit, Field, AsField, toFieldElements, ofFieldElements, sizeInFieldElements, Bool } from './plonk';
import { poseidon } from './poseidon';
import { Group, Scalar } from './group';
import { prop, CircuitValue, Tuple } from './circuit_value';
import { MerkleCollection, MerkleProof, Amount, Nonce, Permission, Permissions, Snapp, method } from './mina';

type PublicKey = Group;

class Signature extends CircuitValue {
  @prop r: Field;
  @prop s: Scalar;

  verify(this: this, pubKey: PublicKey, msg: Field[]): Bool {
    let e = poseidon(msg).unpack();
    let r = pubKey.scale(e).neg().add(Group.generator()).scale(this.s);
    return Bool.and(
      r.x.equals(this.r),
      r.y.unpack()[0].equals(false)
    )
  }

  constructor(r: Field, s: Scalar) {
    super();
    this.r = r;
    this.s = s;
  }
};

// A snapp for 2-of-n multisig
type sigsNeeded = 2;

class SendData extends CircuitValue {
  @prop signatures: Tuple<MemberSignature, sigsNeeded>;
  @prop amount: Amount;
  @prop fee: Amount;
  @prop nonce: Nonce;
  @prop receiver: PublicKey;

  constructor(
    s: Array<MemberSignature>,
    a: Amount,
    f: Amount,
    n: Nonce,
    r: PublicKey
  ) {
    super();
    this.signatures = s;
    this.amount = a;
    this.fee = f;
    this.nonce = n;
    this.receiver = r;
  }
}

class MemberSignature extends CircuitValue {
  @prop membershipProof: MerkleProof;
  @prop signature: Signature;

  constructor(p: MerkleProof, s: Signature) {
    super();
    this.membershipProof = p;
    this.signature = s;
  }
}

class PrivateMultisig extends Snapp {
  keys: MerkleCollection<PublicKey>;

  @method init() {
    this.permissions.receive = Permission.NoAuthRequired;

    for (let i = 0; i < this.state.length; ++i) {
      this.state[i].set(Field.zero);
    }
  }

  // The arguments here are witness data used by the prover
  @method send(w: SendData) {
    // The transaction property is automatically available (via the snapp decorator)
    // and corresponds to the transaction commitment which is part of the snapp statement.
    const transaction = this.transaction();
    const self = transaction.parties.get(0);
    self.nonce.assertEqual(w.nonce);
    const msg = [transaction.commitment()];

    w.signatures.forEach(s => {
      const pubKey = this.keys.get(s.membershipProof);
      s.signature.verify(pubKey, msg).assertEqual(true);
    });

    self.balance.subInPlace(w.amount);

    // Get the second party (index 1) in this transaction, which will be the receiver
    const receiverAccount = transaction.parties.get(1);
    receiverAccount.balance.addInPlace(w.amount.sub(w.fee));
  }

  // This method is redundant given permissions
  @method receive(amount: Amount) {
    // The snapp statement also contains the snapp party-list at the current position,
    // accessible via transaction.self()
    const self = this.transaction().self();
    self.nonce.ignore();
    self.balance.addInPlace(amount);
  }

  constructor(keys: Array<PublicKey>) {
    super();
    this.keys = new MerkleCollection(() => keys);
  }
}
