# `stake_change` — non-zkApp transaction spec

This note specifies how `stake_change` is computed for every non-zkApp
transaction tag (Payment, Stake_delegation, Fee_transfer, Coinbase), in two
forms:

- **Expanded form** — the *definition* as a sum of per-account deltas. No
  algebraic cancellation, no case analysis. This is the ground truth.
- **Reduced form** — the same quantity collapsed into the smallest static
  expression usable as a SNARK constraint.

The reduced form is what the transaction-union base circuit asserts against
the advice supplied by unchecked application.

zkApp transactions are **out of scope** for this doc — they walk a
call-forest of per-account_update contributions and don't fit a closed form.
See `zkapp_command_logic.ml`.

## Notation

Unprimed symbols denote pre-transaction state; primed symbols denote
post-transaction state. For example, `fp_bal` is the fee_payer's balance
before the tx; `fp_bal'` is the same account's balance after the tx.

## Preconditions

- **User command invariant**: `fee_payer == source` is unconditionally
  asserted by the circuit (`transaction_snark.ml:2339`). A transaction where
  they differ is rejected outright — it's not "marked failed", it simply
  fails to prove. All formulas below assume this.

## Definition

`total_stake` is the sum over all accounts `a` of `balance(a) · is_staked(a)`,
where `is_staked(a) = 1` iff `a.delegate` is set (≠ `empty_pk`).

For a transaction `tx` touching some set of accounts `A(tx)`:

```
stake_change(tx) = Σ_{a ∈ A(tx)}  balance'(a) · is_staked'(a)
                 − Σ_{a ∈ A(tx)}  balance (a) · is_staked (a)
```

Accounts outside `A(tx)` contribute zero by construction (both balance and
delegate unchanged), so the sum over the whole ledger reduces to the sum
over touched accounts.

For non-zkApp tags, `A(tx) = {fee_payer, receiver}` (possibly identical — see
encoding notes below). The two-slot encoding is set up by
`Transaction_union.of_transaction` (`transaction_union.ml:32`).

## Variables

| Symbol                        | Meaning                                                                                            |
|-------------------------------|----------------------------------------------------------------------------------------------------|
| `fp_staked`  / `fp_staked'`   | Is `fee_payer.delegate` set, before / after the tx.                                                |
| `fp_bal`     / `fp_bal'`      | `fee_payer.balance`, before / after the tx.                                                        |
| `Δfp_bal`                     | `fp_bal' − fp_bal`, the signed balance delta the circuit actually applies to the fp slot — *after* all permission and failure gates.                                                                                                        |
| `rcv_staked`                  | Is `receiver.delegate` set. No non-zkApp tag touches it, so pre = post.                            |
| `rcv_bal`    / `rcv_bal'`     | `receiver.balance`, before / after the tx.                                                         |
| `Δrcv_bal`                    | `rcv_bal' − rcv_bal`, signed; same gating story as `Δfp_bal`.                                      |
| `is_user_command`             | `1` for Payment / Stake_delegation; `0` for Fee_transfer / Coinbase. Used only in the derived `fp_staked'` formula. |
| `is_stake_delegation`         | `1` for Stake_delegation; `0` otherwise. Same.                                                     |
| `user_command_fails`          | `1` if one of the 8 strict failures in `User_command_failure.t` fired; `0` otherwise. Used only in the derived `fp_staked'` formula. |
| `source_delegation_permitted` | `1` iff the fee_payer's `set_delegate` permission accepts signature auth. Used only in the derived `fp_staked'` formula. |
| `set_to_unstaked`             | For stake_delegation, does `payload.body.receiver_pk` equal `empty_pk`?                            |
| `fee`                         | `payload.common.fee` (as an unsigned `Amount`).  |
| `payload.body.amount`         | The body amount field. meaning depends on tag — see coverage table.                                |
| `receiver_increase`           | Amount the circuit *intends* to credit to the receiver, before permission gating                   |
| `payment_permitted`           | `1` iff the body actually transferred funds — i.e., source's `access`/`send` and receiver's `access`/`receive` permissions all allow it.                                                                                                            |

### Why `Δfp_bal` / `Δrcv_bal` already absorb permission failures

`Δfp_bal` and `Δrcv_bal` are *post-gate* — they are the signed amounts
that actually hit the slot's balance once the circuit has finished
applying it. Every permission and failure gate composes into these two
numbers. The relevant gates:

- **fp slot, user command** — fee debit always applies. The circuit
  hard-asserts `permitted_to_access`, `permitted_to_send`, and
  `permitted_to_increment_nonce` for the fee_payer
  (`transaction_snark.ml:2529-2548`), so a user command that wouldn't
  pass these isn't merely Failed — it's *unprovable* (see "Cases that
  never reach the SNARK" below).
- **fp slot, internal command** — fp's *credit* is gated by
  `permitted_to_receive` for the fp account (the fp slot of an internal
  command is a recipient, see `[^fp-slot]` and `[^fee-credit]`). When
  rejected, the credit is burned and `Δfp_bal = 0`
  (`transaction_snark.ml:2556-2562`).
- **rcv slot, user command** — gated by `payment_permitted` (source
  `access`/`send` and receiver `access`/`receive` all allow it) and by
  the root rollback when `user_command_fails` (one of the 8 strict
  failures in `User_command_failure.t`). The rollback path is the
  `final_root` reset at `transaction_snark.ml:3213`. Permission gate is
  at `transaction_snark.ml:2992`.
- **rcv slot, internal command** — gated by `permitted_to_receive` /
  `update_account` at `transaction_snark.ml:2727-2738`.

The delegate write is a separate operation from the balance updates and
does not fold into `Δfp_bal`. Its gates determine `fp_staked'` directly
— see "Derived: `fp_staked'`" below.

So a "Payment, body didn't transfer" with a rejecting receiver is
`Δrcv_bal = 0`. An internal command whose recipient burns the credit is
`Δfp_bal = 0` or `Δrcv_bal = 0`. The reduced form below doesn't need a
case split because the case split has already happened by the time we
consume `Δfp_bal` / `Δrcv_bal`.

### Derived: `fp_staked'`

Equal to `fp_staked` unless the transaction writes the delegate field. When
it does, the new delegate is `payload.body.receiver_pk`, so `fp_staked'`
reduces to whether that is non-empty:

```
writes_delegate_field = is_stake_delegation
                         ∧ ¬user_command_fails
                         ∧ source_delegation_permitted

fp_staked' = writes_delegate_field ? ¬set_to_unstaked
                                      : fp_staked
```

The write may be a no-op (e.g. re-delegating to the same address), but the
formula stays correct: when it's a no-op, `fp_staked' = fp_staked` anyway.

## Expanded form

Apply the definition directly. `rcv_staked` is constant across a non-zkApp
tx, so the receiver term factors.

```
stake_change =
    fp_bal'  · fp_staked'
  − fp_bal   · fp_staked
  + (rcv_bal' − rcv_bal) · rcv_staked
```

Balance transitions by tag family:

| Family         | `fp_bal'`                                                                       | `rcv_bal' − rcv_bal`                                |
|----------------|---------------------------------------------------------------------------------|-----------------------------------------------------|
| User command   | `fp_bal − fee − (payment_permitted ∧ ¬user_command_fails) · amount`             | `(payment_permitted ∧ ¬user_command_fails) · amount` |
| Internal       | `fp_bal + fee` [^fp-slot] [^fee-credit]                                         | `receiver_increase`                                 |

For user commands `fp_staked'` can differ from `fp_staked` (see derivation
above). For internal commands `fp_staked' = fp_staked`.

Substituting the balance transitions into the definition gives one
stake_change expression per family, still with no cancellation. That is the
form the unchecked implementation mirrors.

## Reduced form

The expanded form rearranges into a single closed-form expression that
covers every non-zkApp tag, every success/failure mode, and every
permission outcome:

```
stake_change =   fp_bal  · (fp_staked' − fp_staked)     -- delegate transition
               + Δfp_bal · fp_staked'                   -- fp slot's actual balance change
               + Δrcv_bal · rcv_staked                  -- rcv slot's actual balance change
```

### Derivation

For non-zkApp tags `rcv_staked` is unchanged, so the receiver term in the
expanded form is `Δrcv_bal · rcv_staked` directly. For the fp slot:

```
fp_bal' · fp_staked' − fp_bal · fp_staked
  = (fp_bal + Δfp_bal) · fp_staked' − fp_bal · fp_staked
  = fp_bal · (fp_staked' − fp_staked) + Δfp_bal · fp_staked'
```

## Coverage table

Each row records:
- the encoding of the tag (which account each slot points to, and what
  goes into `fee` / `body.amount`),
- the *post-gate* `Δfp_bal` and `Δrcv_bal` for the success case,
- `fp_staked' − fp_staked`,
- the resulting reduced-form expression by substitution.

The `#` column is the row number. Tests for each row are tagged
`(* unstaking_tx_case_<#>[.<sub>] *)` in
`src/lib/transaction_logic/test/transaction_logic/stake_change.ml` and
`src/lib/transaction_snark/test/stake_change_snark/stake_change_snark.ml`.

For any row, if a permission gate rejects, the corresponding Δ becomes
`0` — no separate row needed. See the variants list following the table.

| #  | Tag                                     | `fee_payer` slot        | `receiver` slot        | `fee`     | `body.amount` | `Δfp_bal`           | `Δrcv_bal`         | `fp_staked' − fp_staked` | Reduced form collapses to                              |
|----|-----------------------------------------|-------------------------|------------------------|-----------|---------------|---------------------|--------------------|--------------------------|--------------------------------------------------------|
| 1  | Payment, success                        | sender                  | payee                  | `fee`     | amount        | `−fee − amount`     | `+amount`          | `0`                      | `−fee·fp_staked + amount·(rcv_staked − fp_staked)`     |
| 2  | Payment, body didn't transfer           | sender                  | payee                  | `fee`     | amount        | `−fee`              | `0`                | `0`                      | `−fee·fp_staked`                                       |
| 3  | Stake_delegation, Some→Some             | delegator               | new delegate           | `fee`     | `0`           | `−fee`              | `0`                | `0`                      | `−fee`                                                 |
| 4  | Stake_delegation, Some→None (opt-out)   | delegator               | `empty_pk`             | `fee`     | `0`           | `−fee`              | `0`                | `−1`                     | `−fp_bal`                                              |
| 5  | Stake_delegation, None→Some (opt-in)    | delegator               | new delegate           | `fee`     | `0`           | `−fee`              | `0`                | `+1`                     | `fp_bal − fee`                                         |
| 6  | Stake_delegation, None→None             | delegator               | `empty_pk`             | `fee`     | `0`           | `−fee`              | `0`                | `0`                      | `0`                                                    |
| 7  | Stake_delegation, not permitted/failed  | delegator               | anything               | `fee`     | `0`           | `−fee`              | `0`                | `0` [^delegate-fail]     | `−fee·fp_staked`                                       |
| 8  | Fee_transfer, one single                | `fee_payer ≡ receiver`  | `fee_payer ≡ receiver` | `0`       | `fee`         | `0`                 | `+fee`             | `0`                      | `fee·rcv_staked`                                       |
| 9  | Fee_transfer, two singles               | `pk₂` [^fp-slot]        | `pk₁`                  | `fee₂` [^fee-credit] | `fee₁` | `+fee₂`             | `+fee₁`            | `0`                      | `fee₂·fp_staked + fee₁·rcv_staked`                     |
| 10 | Coinbase, no fee_transfer               | block producer          | block producer         | `0`       | `full`        | `0`                 | `+full`            | `0`                      | `full · rcv_staked`                                    |
| 11 | Coinbase, with fee_transfer             | snark worker [^fp-slot] | block producer         | `ft_fee` [^fee-credit] | `full` | `+ft_fee`           | `+(full − ft_fee)` | `0`                      | `ft_fee·fp_staked + (full − ft_fee)·rcv_staked`        |

### Permission-rejection variants (no extra rows)

For each row above, an internal-command receive rejection or a
user-command body-transfer rejection zeroes out the corresponding Δ. A
few representative cases:

- Row 1, receiver `receive` rejects: collapses to row 2 (`Δrcv_bal = 0`).
  (Source `send`/`access` rejections don't appear here — they reject the
  whole txn; see "Cases that never reach the SNARK".)
- Row 8, receiver `receive` rejects: `Δrcv_bal = 0` → stake_change `0`.
- Row 9, fp slot's `receive` rejects: `Δfp_bal = 0` → stake_change
  `fee₁·rcv_staked`. Symmetrically on the rcv side.
- Row 11, snark worker's `receive` rejects: `Δfp_bal = 0` → stake_change
  `(full − ft_fee)·rcv_staked`. Block producer side analogous.

[^fp-slot]: For internal commands, `Transaction_union` reuses the
    `fee_payer_pk` field as a generic account slot — it is *not* a real fee
    payer. See `Transaction_union.of_transaction`: the Coinbase-with-ft
    mapping at `transaction_union.ml:41-67` puts the snark worker in
    `fee_payer_pk`/`source_pk` and the block producer in `receiver_pk`; the
    Fee_transfer two-singles mapping at `transaction_union.ml:68-91` puts
    `pk₂` in `fee_payer_pk` and `pk₁` in `receiver_pk`. The whole encoding
    is documented at `transaction_union.ml:23-31`.

[^fee-credit]: For internal commands the apply logic *credits* (rather than
    debits) the fp slot by `fee`. The sign is flipped at
    `transaction_snark.ml:2576`:
    ```ocaml
    let sgn = Sgn.Checked.neg_if_true is_user_command in
    Amount.Signed.create_var ~magnitude:(Amount.Checked.of_fee fee) ~sgn
    ```
    With `is_user_command = false`, the sign is positive — so an
    internal-command row's `Δfp_bal` is `+fee` (when `permitted_to_receive`
    on the fp slot allows it).

[^delegate-fail]: For failed or not-permitted stake_delegations, the
    delegate write is a no-op so `fp_staked' = fp_staked`. The only
    stake_change comes from debiting `fee` from a (possibly) staked
    `fp_bal`. Hence `−fee·fp_staked` collapses all four delegation
    sub-cases (None→Some, Some→Some, Some→None, None→None) into a single
    formula.

### Why the encoding tricks work

Two tx types (Coinbase without ft, Fee_transfer with one single) have only
*one* real account, but `Transaction_union` still fills in both `fee_payer`
and `receiver` slots. The encoding handles this by:

1. Setting `fee_payer_pk = receiver_pk` (same account in both slots).
2. Setting `fee = 0` so `Δfp_bal = 0` regardless of the fp slot's
   permission.
3. Putting the entire credit in `body.amount` so the rcv slot sees the
   full payment.

The net result is that the single account gets credited once via the
`receiver` slot.

## Cases that never reach the SNARK

Some permission failures look like they should appear as Failed rows but
actually cause the transaction to be *rejected outright* — either by the
unchecked path's `Or_error` or by hard SNARK assertions on the
fee_payer. These don't need coverage rows because no block ever contains
them:

- **fee_payer's `send` rejects signature auth** — `Or_error` at
  `mina_transaction_logic.ml:565-568`; SNARK asserts `permitted_to_send`
  for all user commands at `transaction_snark.ml:2543-2548`.
- **fee_payer's `access` rejects** — SNARK asserts `permitted_to_access`
  for all commands at `transaction_snark.ml:2530-2532`.
- **fee_payer's `increment_nonce` rejects** — `Or_error` at
  `mina_transaction_logic.ml:571-574`; SNARK asserts at lines 2534-2541.
- **Source has insufficient balance for the fee** — `Or_error` in
  `pay_fee` at `mina_transaction_logic.ml:488`.
- **`fee_payer == source`** — asserted unconditionally by the circuit
  (`transaction_snark.ml:2339`); a transaction where they differ fails
  to prove rather than being marked Failed.

## How the circuit uses the reduced form

`apply_tagged_transaction` computes `stake_change` via the reduced form and
then the outer `main` function of the Base rule asserts equality with the
public statement field:

```ocaml
[%with_label_ "equal stake_changes"] (fun () ->
    Currency.Amount.Signed.Checked.assert_equal stake_change
      statement.stake_change )
```

The `statement.stake_change` value is produced by
`Transaction_applied.stake_change` at block-production time
(`staged_ledger.ml`) and by `create_expected_statement` at scan-state replay
time (`transaction_snark_scan_state.ml`). Both unchecked call sites must
produce a value that matches the expanded form — and therefore the reduced
form, since they are equal by construction.

The unified reduced form has a concrete benefit for the circuit
implementation: the inputs `Δfp_bal` and `Δrcv_bal` are exactly the signed
balance changes the circuit already produces while updating each slot's
account record. There is no need to reconstruct `fee` / `receiver_increase`
from advice and re-apply gates manually — once the balance updates have
been threaded through the gates, they *are* the inputs to the stake_change
formula.
