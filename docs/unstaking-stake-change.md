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

- **Signed command invariant**: `fee_payer == source` is unconditionally
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
encoding notes below).

## Variables

| Symbol                        | Meaning                                                                                            |
|-------------------------------|----------------------------------------------------------------------------------------------------|
| `is_user_command`             | `1` for Payment / Stake_delegation; `0` for Fee_transfer / Coinbase.                               |
| `is_payment`                  | `1` for Payment; `0` otherwise.                                                                    |
| `is_stake_delegation`         | `1` for Stake_delegation; `0` otherwise.                                                           |
| `user_command_fails`          | `1` if a user command failed to apply (fee is still deducted); `0` otherwise.                      |
| `source_delegation_permitted` | `1` iff the fee_payer's `set_delegate` permission accepts signature auth. See note below.          |
| `fp_staked`  / `fp_staked'`   | Is `fee_payer.delegate` set, before / after the tx.                                                |
| `fp_bal`     / `fp_bal'`      | `fee_payer.balance`, before / after the tx.                                                        |
| `rcv_staked`                  | Is `receiver.delegate` set. No non-zkApp tag touches it, so pre = post.                            |
| `rcv_bal`    / `rcv_bal'`     | `receiver.balance`, before / after the tx.                                                         |
| `set_to_unstaked`             | For stake_delegation, does `payload.body.receiver_pk` equal `empty_pk`?                            |
| `fee`                         | `payload.common.fee` (as an unsigned `Amount`).                                                    |
| `payload.body.amount`         | The body amount field. Meaning depends on tag — see coverage table.                                |
| `receiver_increase`           | Amount credited to `receiver`, computed earlier in the circuit. See coverage table.                |

### Note on `source_delegation_permitted`

Distinct from `user_command_fails`. The account's `set_delegate` permission
may have been configured (by a prior zkApp `Update.permissions` call) to
reject signature-only auth — e.g. `set_delegate = Proof`, `Both`, or
`Impossible`. In that case a signed stake_delegation still "succeeds" (fee
deducted, nonce incremented) but the delegate change is silently rejected.
In-circuit check: `permitted_to_update_delegate` at
`transaction_snark.ml:2945`.

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

| Family         | `fp_bal'`                                       | `rcv_bal' − rcv_bal`               |
|----------------|-------------------------------------------------|------------------------------------|
| User command   | `fp_bal − fee − (is_payment ∧ ¬fails) · amount` | `(is_payment ∧ ¬fails) · amount`   |
| Internal       | `fp_bal + fee`                                  | `receiver_increase`                |

For user commands `fp_staked'` can differ from `fp_staked` (see derivation
above). For internal commands `fp_staked' = fp_staked`.

Substituting the balance transitions into the definition gives one
stake_change expression per family, still with no cancellation. That is the
form the unchecked implementation mirrors.

## Reduced form

Cancel the `fp_bal · fp_staked` terms (where applicable) and split on
`is_user_command`.

```
stake_change = is_user_command ? signed_cmd_delta : internal_delta
```

### Signed command (Payment or Stake_delegation)

```
signed_cmd_delta =
      fp_bal · (fp_staked' − fp_staked)                                -- delegate transition
    − fee    · fp_staked'                                              -- fee always deducted
    + (is_payment ∧ ¬user_command_fails)                               -- payment body
        · payload.body.amount · (rcv_staked − fp_staked)
```

Three pieces: a **delegate transition** term (zero for payments and for
failed/not-permitted delegations), a **fee deduction** term (always present
for user commands, gated on the *post-tx* staked state so it cancels the
transition term correctly when opting out), and a **payment body** term
(only active when the tx is a successful payment).

### Internal command (Fee_transfer or Coinbase)

```
internal_delta =
      fee               · fp_staked         -- fee credited to fee_payer slot
    + receiver_increase · rcv_staked        -- second recipient (if any)
```

Two slots `fp_staked` and `rcv_staked` correspond to the *two accounts*
touched by any internal command. When only one account is "real"
(Fee_transfer with a single recipient, or Coinbase with no snark-worker
fee_transfer), `fee = 0` and the encoding below disarms the double credit.

## Coverage table

The `fee_payer`, `receiver`, `fee`, `body.amount`, and `receiver_increase`
columns show how each tag is encoded by `Transaction_union.of_transaction`
(see `src/lib/transaction/transaction_union.ml`). The final column shows the
reduced-form expression collapsed to its operative terms.

| Tag                                    | `fee_payer` slot       | `receiver` slot        | `fee`    | `body.amount`   | `receiver_increase` | Reduced form collapses to                                     |
|----------------------------------------|------------------------|------------------------|----------|-----------------|---------------------|---------------------------------------------------------------|
| Payment, success                       | sender                 | payee                  | `fee`    | amount          | amount              | `−fee·fp_staked + amount·(rcv_staked − fp_staked)`            |
| Payment, fail                          | sender                 | payee                  | `fee`    | amount          | amount              | `−fee·fp_staked`                                              |
| Stake_delegation, Some→Some            | delegator              | new delegate           | `fee`    | `0`             | `0`                 | `−fee`                                                        |
| Stake_delegation, Some→None (opt-out)  | delegator              | `empty_pk`             | `fee`    | `0`             | `0`                 | `−fp_bal`                                                     |
| Stake_delegation, None→Some (opt-in)   | delegator              | new delegate           | `fee`    | `0`             | `0`                 | `fp_bal − fee`                                                |
| Stake_delegation, None→None            | delegator              | `empty_pk`             | `fee`    | `0`             | `0`                 | `0`                                                           |
| Stake_delegation, not permitted        | delegator              | anything               | `fee`    | `0`             | `0`                 | `−fee·fp_staked`                                              |
| Stake_delegation, failed               | delegator              | anything               | `fee`    | `0`             | `0`                 | `−fee·fp_staked`                                              |
| Fee_transfer, one single               | `fee_payer ≡ receiver` | `fee_payer ≡ receiver` | `0`      | `fee`           | `fee`               | `fee·rcv_staked`                                              |
| Fee_transfer, two singles              | `pk₂`                  | `pk₁`                  | `fee₂`   | `fee₁`          | `fee₁`              | `fee₂·fp_staked + fee₁·rcv_staked`                            |
| Coinbase, no fee_transfer              | `fee_payer ≡ receiver` | `fee_payer ≡ receiver` | `0`      | `full`          | `full`              | `full_coinbase · rcv_staked`                                  |
| Coinbase, with fee_transfer            | ft recipient           | coinbase receiver      | `ft_fee` | `full`          | `full − ft_fee`     | `ft_fee·fp_staked + (full − ft_fee)·rcv_staked`               |

### Why the encoding tricks work

Two tx types (Coinbase without ft, Fee_transfer with one single) have only
*one* real account, but `Transaction_union` still fills in both `fee_payer`
and `receiver` slots. The encoding handles this by:

1. Setting `fee_payer_pk = receiver_pk` (same account in both slots).
2. Setting `fee = 0` so the `fee · fp_staked` term in `internal_delta`
   vanishes.
3. Putting the entire credit in `body.amount` so that `receiver_increase`
   equals the full payment.

The net result is that the single account gets credited once via the
`receiver` slot, and the `fee_payer` slot contributes nothing.

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
