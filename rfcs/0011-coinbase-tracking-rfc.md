## Summary

Right now, there are no in-SNARK checks that the coinbases included in a ledger-proof
bear any relation to those that *should* be there. In particular, one can include coinbases
which increase the supply arbitrarily and the SNARK does not rule that out (consensus of
course does). This RFC describes two approaches which provide different levels of guarantees
about the coinbases included in ledger-proofs. They both involve updating a small piece of
state in the protocol-state on each extension of the blockchain-SNARK, and adding some additional
state to the transaction-SNARK.

## Motivation

As mentioned, at the moment one can update the protocol state with a ledger-proof that contains
an arbitrary set of coinbase transactions, rather than the set of coinbase transactions one expects
given the history of the blockchain. This allows some attacks which are unlikely to happen in practice
due to these bad updates being rejected by the consensus process, but which may be possible.

The more of the ledger builder we move into the SNARK, the more of these attacks we rule out.

## Detailed design

Here are 2 designs. Design 1 provides the guarantee that the right amount of money is created.
Design 2 provides the guarantee that the right amount of money is created and given to the right
people.

### Proposal 1: Just track the amounts.

Add a field to the protocol-state which is `pending_supply_increase` and gets incremented by
`coinbase_amount` on each block. When a ledger proof `p` is merged in, subtract the supply-increase
of `p` from the current protocol state's `pending_supply_increase`.

1. **Security guarantee:**
This ensures that the ledger in the protocol-state never has more money than it should according
to the monetary policy, but it makes no guarantees about if that money went to the block winners
that it should have.

2. **Difficulty of implementation***
This proposal would be very easy to implement.

3. **Efficiency impact**
The efficiency impact of this is minimal. It involves just a few more operations in the SNARK.

### Proposal 2: Track the set of coinbases themselves.
A more sophisticated approach is to track the **set** of pending coinbases rather than their
total value. Then instead of attaching a supply-increase to a ledger proof, attach the set
of coinbases which are included in that ledger-proof, and subtract that set from the set in
the protocol-state when the proof gets merged in. Also, when updating the protocol state, add
the proposer's coinbase to the set of pending coinbases.

The difficult thing here is to make sure the operations of adding to the set and subtracting one
set from the other are efficient inside the SNARK.

Here is a proposal for making that possible. The general idea is to use a stack (actually several)
inside of the protocol-state to represent the set of pending coinbases.

Here is a pseudo-snarky interface and implementation.
```ocaml
(* Could be either a list if it's a small number or a little merkle tree *)
module Ordered_collection : sig
  type 'a t
  [@@deriving eq]

  val modify : 'a t -> Index.t -> ('a -> 'a) -> 'a t
end = ...

module Stack : sig
  type 'a t
  [@@deriving eq]

  val push : 'a t -> 'a -> 'a t
end = struct
  type 'a t = Pedersen.Digest.t

  let equal = Pedersen.Digest.equal

  let push t x = hash (to_bits t @ to_bits x)
end

module Pending_coinbases : sig
  type t
  (* semantics: multiset of (Public_key.t * Amount.t) *)

  val push
    : t -> Public_key.Compressed.t * Amount.t -> t
  (* semantics: multiset add *)

  val subtract
    : t -> t -> t
  (* semantics:
    multiset subtraction, failing if the second argument is not a subset of
    the first. *)

  val to_bits
    : t -> bool list
  (* This is just for hashing. The only semantics are that this function should
     be semantically injective *)
end = struct
  type t = Pedersen.Digest.t Ordered_collection.t

  let push t elt =
    (* Actually, the index can also be computed correctly. *)
    let index = exists Index.typ in
    Ordered_collection.modify t index (fun s -> Stack.push s elt)

  (* This is more complicated and dependent on the implementation of Ordered_collection *)
  let subtract = ...
end
```
We would 

The simplified version of the code (in pseudo-snarky would look like this
```ocaml
(* This stuff is just context *)
let winner_addr = exists Winner_address in
let account = Ledger.get ledger winner_addr in
let delegate = account.delegate in
let () = check_vrf winner_addr account in
(* End context *)
let pending_coinbases =
  Pending_coinbases.subtract
    curr_state.pending_coinbases
    (Ledger_proof.pending_coinbases ledger_proof)
in
let pending_coinbases =
  Pending_coinbases.push pending_coinbases
    (delegate, coinbase_amount)
in
...
```

We could also track the sum of the amounts in the stacks as `pending_supply_increase` which
would save us from having to separately carry that around in the transaction SNARK.

As for the design 

Optimizations:
- Avoid hashing the delegate (when pushing to the pending coinbases) by reusing the section of
  the hash of the winner's account which contains the delegate.
