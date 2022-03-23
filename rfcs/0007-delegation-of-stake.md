# Summary
[summary]: #summary

We want to support the possibility of delegating one's stake to another public-key, so
that the delegate's probability of winning increases (with the intention, whether it be
enforced on chain or not, that they would receive some of the block reward as in a mining
pool).

Some goals for such a design are the following:
- We want as much stake used directly or delegated to active stakers as possible. This is
  how the security of the network is ensured.
- It should not be too expensive inside the SNARK.
- It should not be too expensive outside the SNARK.

# Detailed design
[detailed-design]: #detailed-design

In general, let's model the "delegation state" of Coda at any given time as a function
`delegate : Public_key -> Public_key`. There are a few different semantics we could hope to give
delegation.

1. Non-transitive stake delegation. The amount of stake delegated to public-key `p` is
  `\sum_{x \in delegate^{-1}(p)} stake(x)`. I.e., people are partitioned according
  to their delegate, and that delegate's virtual stake is the sum of the delegators'
  stake.
2. Transitive stake delegation. Let's say a key is a "terminal delegate" if `delegate p = p`.
  For such `p`, say `q` is a delegator of `p` if `delegate q = p` or if
  for some `q'` a delegator of `p` we have `delegate q = q'`. Then `p`'s virtual stake
  is defined to be the sum of its delegates' stakes.

`2` seems *very* difficult to implement and it's dubious to me whether it would be
much better than `1`, at least for now.

As such, here are three non-transitive designs. Discussion on this has converged
on going with design 1 for now.

## Design 1: Better in the SNARK, but worse everywhere else
- Add to `Account.t` a field `delegate : Public_key.Compressed.t`
- Create a new transaction type which allows one to set this field (maybe we stuff
  a fee transfer in there too so we don't waste the merkle lookup...).
- A proposer maintains a list of all the people who are delegating for them,
  incrementally updating it when they see new transactions.
- When the randomness and ledger for the next epoch is locked in, the proposer
  performs one VRF evaluation for each account delegating to them. They evaluate
  on the concatenation of
  whatever we were evaluating it on before, plus the
  merkle-tree address of the delegator's account (this is just cheaper than using
  the public-key).
- When a proposer extends the blockchain, they can use any of the VRF evaluations
  made in the prior step.

The main reason this design is bad is that you have to perform a number of VRF
evaluations proportional to the number of people staking for you, and in practice
it might be costly causing you to not even evaluate the VRF on smaller accounts
which have delegated to you. You also need to maintain a large amount of additional
state (the set of people delegating to you).

The main thing this design has going for it is that it would barely increase the
size of the circuit. It's also nice that it makes it very easy to delegate your
stake. Just set it and forget it.

## Design 2: Worse in the SNARK, but better everywhere else.
- Add to `Account.t` two fields
  - `delegate : Public_key.Compressed.t`
  - `delegated_stake : Currency.Amount.t`

  The invariant we maintain is that for any account corresponding to public key $p$, `delegated_stake` is the sum
  `\sum_{a : Account.t, a.delegate = p} a.balance`.

- Create a new transaction type which allows one to set the `delegate` field.
  It would also have the following effect:
```ocaml
apply_transaction (Set_delegate new_delegate) account =
  let old_delegate = account.delegate in
  let old_delegate_account = find old_delegate in
  set account.public_key
    { account with delegate = new_delegate };
  set old_degate
    { old_delegate_account with delegated_stake -= account.balance };
  set new_delegate
    { new_delegate_account with delegated_stake += account.balance };
```
  so basically 3 Merkle lookups.
- Change normal transactions to increment/decrement the `delegated_stake` fields of
  delegates of accounts modified as needed. This will require them to do the following
  lookups:
  - sender
  - sender delegate
  - receiver
  - receiver delegate

  I predict this means that Base transaction
  SNARKs will be like ~1.5-2x more costly.
- Just evaluate the VRF on one's own account, but with the threshold being based on
  `delegated_stake` rather than balance.

The main thing this design has going for it is you only need to do one VRF evaluation.

## Design 3: Not worse in the SNARK, with similar advantages to design 2, but delegation is explicit.
- Add to `Account.t` three fields
  - `delegate : Public_key.Compressed.t`
  - `delegated_to_me : Currency.Amount.t`
  - `delegated_by_me : Currency.Amount.t`

  The invariants we maintain are
  - For any account corresponding to public key `p`, `delegated_stake` is the sum
    `\sum_{a : Account.t, a.delegated_by_me = p} a.delegated_to_me`.
  - For any account `a`, `a.delegated_by_me <= a.balance`.

- Normal transactions do not affect the new fields.
- We will have a new transaction `Update_delegated_stake (p, delta)` with the following
  semantics:
```ocaml
apply_transaction (Update_delegated_stake (p, delta)) =
  let account = find p in
  let delegated_by_me = account.delegated_by_me + delta in
  assert (delegated_by_me <= account.balance);
  set p { account with delegated_by_me = delegated_by_me };
  let delegate = find p.delegate in
  set p.delegate { delegate with delegated_to_me += delta };
```
  This has two Merkle lookups so we can shoehorn this into the existing base SNARK.
- We will have a new transaction `Set_new_delegate (p, new_delegate)` with the
  following semantics
```ocaml
apply_transaction (Set_new_delegate (p, new_delegate)) =
  let account = find p in
  set p
    { account with delegate = new_delegate; delegated_by_me = 0 };
  let old_delegate_account = find account.delegate;
  set account.delegate
    { old_delegate_account with delegated_to_me -= account.delegated_by_me };
```
- We basically waste one Merkle lookup when switching ones' delegation, but
  it isn't so bad. (We do in 4 lookups what we could do in 3.)
- VRF evaluation is checked against the threshold implied by `delegated_to_me`.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

This approach has a lot of disadvantages.

The main alternative (at a high level) is to use transitive stake delegation.
This is hard because checking the `is_delegate` relation seems (in principle)
to require one of
- touching O(n) accounts whenever someone changes their delegate,
- touching O(n) accounts whenever you want to confirm that someone is a transitive delegate
  of someone else.

Which makes it a non-starter in the SNARK, where we need to do both.

I think design 3 has acceptable trade-offs in terms of usability (you have to explcitly
update your delegation amount which sucks), but doesn't hurt the efficiency of the SNARK
and we still only have to do one VRF evaluation outside the SNARK.

# Prior art
[prior-art]: #prior-art

Prior art is pretty scarce, but here are Tezos and Cardano's docs.

- Tezos: [Docs](https://tezos.gitlab.io/active/proof_of_stake.html#delegation).
  As far as I can tell uses non-transitive stake delegation.
- Cardano: [Docs](https://cardanodocs.com/technical/delegation).
  Uses transitive stake delegation.
