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
| `is_user_command`             | `1` for Payment / Stake_delegation; `0` for Fee_transfer / Coinbase.                               |
| `is_payment`                  | `1` for Payment; `0` otherwise.                                                                    |
| `is_stake_delegation`         | `1` for Stake_delegation; `0` otherwise.                                                           |
| `user_command_fails`          | `1` if a user command failed to apply (fee is still deducted); `0` otherwise.                      |
| `source_delegation_permitted` | `1` iff the fee_payer's `set_delegate` permission accepts signature auth. See note below.          |
| `payment_permitted`           | `1` iff the body actually transferred funds — i.e., source's `access`/`send` and receiver's `access`/`receive` permissions all allow it. See note below. |
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

The "partial success" comes from these circuit sites running
unconditionally for any user command, regardless of the auth check:

- Fee debit: `transaction_snark.ml:2576` — sign is negative for user
  commands.
- Nonce increment: `transaction_snark.ml:2496` —
  `Account.Nonce.Checked.succ_if account.nonce is_user_command`.

The delegate write is gated. The auth check is computed at
`transaction_snark.ml:2954-2957` (`permitted_to_update_delegate`) and folded
into `update_account` at `transaction_snark.ml:2974-2988`. The actual
delegate assignment at `transaction_snark.ml:3041-3047` only fires when
`is_stake_delegation && update_account` is true — otherwise the new
delegate value falls through to `account.delegate` (no-op write). Our
`stake_change` formula tracks this via the `source_delegation_permitted`
factor.

### Note on `payment_permitted`

Distinct from `user_command_fails`. A signed payment can fail to transfer
funds because the source account's `send` permission rejects signature
auth (or `access` rejects), or because the receiver account's `receive`
permission rejects None_given auth (or `access` rejects). In any of those
cases the unchecked status is `Failed [Update_not_permitted_balance]` —
fee deducted, nonce incremented, body amount stays in source.

The circuit handles "did the body actually transfer?" via two parallel
mechanisms:

1. **Permission gates** (catch permission rejections). Source's amount
   debit is gated by `payment_permitted` at `transaction_snark.ml:2992`;
   receiver's update is gated by `permitted_to_receive` at
   `transaction_snark.ml:2870`. So when permissions reject, no balance
   change happens at all.
2. **Root rollback** (catch the 8 strict failures in
   `User_command_failure.t` — e.g. `amount_insufficient_to_create`,
   receiver overflow). Source/receiver are tentatively updated, then
   rolled back via the `final_root` reset at `transaction_snark.ml:3213`
   when `user_command_fails`.

Consequence: `user_command_fails` does *not* mean "the unchecked status
was Failed"; it means "one of the 8 strict failure modes fired". To
answer "did the body amount actually move?" we need *both* gates:
`payment_permitted ∧ ¬user_command_fails`.

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

Cancel the `fp_bal · fp_staked` terms (where applicable) and split on
`is_user_command`.

```
stake_change = is_user_command ? user_cmd_delta : internal_delta
```

### User command (Payment or Stake_delegation)

```
user_cmd_delta =
      fp_bal · (fp_staked' − fp_staked)                                -- delegate transition
    − fee    · fp_staked'                                              -- fee always deducted
    + (payment_permitted ∧ ¬user_command_fails)                        -- payment body
        · payload.body.amount · (rcv_staked − fp_staked)
```

Three pieces: a **delegate transition** term (zero for payments and for
failed/not-permitted delegations), a **fee deduction** term (always present
for user commands, gated on the *post-tx* staked state so it cancels the
transition term correctly when opting out), and a **payment body** term
(only active when the body actually moved funds — see the note on
`payment_permitted` for why both gates are required). Note that
`payment_permitted` already implies `is_payment`, so we don't need a
separate `is_payment` factor.

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
(see `transaction_union.ml`). The final column is the reduced-form
expression above (`user_cmd_delta` or `internal_delta`) specialized to that
row's encoding — substitute the encoded values into the reduced form, drop
zero terms, and you get the cell shown.

| Tag                                    | `fee_payer` slot       | `receiver` slot        | `fee`    | `body.amount`   | `receiver_increase` | Reduced form collapses to                                     |
|----------------------------------------|------------------------|------------------------|----------|-----------------|---------------------|---------------------------------------------------------------|
| Payment, success                       | sender                 | payee                  | `fee`    | amount          | amount              | `−fee·fp_staked + amount·(rcv_staked − fp_staked)`            |
| Payment, fail                          | sender                 | payee                  | `fee`    | amount          | amount              | `−fee·fp_staked`                                              |
| Stake_delegation, Some→Some            | delegator              | new delegate           | `fee`    | `0`             | `0`                 | `−fee`                                                        |
| Stake_delegation, Some→None (opt-out)  | delegator              | `empty_pk`             | `fee`    | `0`             | `0`                 | `−fp_bal`                                                     |
| Stake_delegation, None→Some (opt-in)   | delegator              | new delegate           | `fee`    | `0`             | `0`                 | `fp_bal − fee`                                                |
| Stake_delegation, None→None            | delegator              | `empty_pk`             | `fee`    | `0`             | `0`                 | `0`                                                           |
| Stake_delegation, not permitted        | delegator              | anything               | `fee`    | `0`             | `0`                 | `−fee·fp_staked` [^delegate-fail]                             |
| Stake_delegation, failed               | delegator              | anything               | `fee`    | `0`             | `0`                 | `−fee·fp_staked` [^delegate-fail]                             |
| Fee_transfer, one single               | `fee_payer ≡ receiver` | `fee_payer ≡ receiver` | `0`      | `fee`           | `fee`               | `fee·rcv_staked`                                              |
| Fee_transfer, two singles              | `pk₂` [^fp-slot]       | `pk₁`                  | `fee₂` [^fee-credit] | `fee₁`          | `fee₁`              | `fee₂·fp_staked + fee₁·rcv_staked`                            |
| Coinbase, no fee_transfer              | block producer         | block producer         | `0`      | `full`          | `full`              | `full_coinbase · rcv_staked`                                  |
| Coinbase, with fee_transfer            | snark worker [^fp-slot] | block producer        | `ft_fee` [^fee-credit] | `full`          | `full − ft_fee`     | `ft_fee·fp_staked + (full − ft_fee)·rcv_staked`               |

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
    internal-command row's reduced form can have a `+ fee · fp_staked` term
    despite the slot being called "fee_payer".

[^delegate-fail]: For failed or not-permitted stake_delegations, the
    delegate write is a no-op so `fp_staked' = fp_staked`. The only
    stake_change comes from debiting `fee` from a (possibly) staked
    `fp_bal`. Hence `−fee·fp_staked` collapses all four delegation
    sub-cases (None→Some, Some→Some, Some→None, None→None) into a single
    formula: `0` when fp wasn't staked to begin with, `−fee` when it was.

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
