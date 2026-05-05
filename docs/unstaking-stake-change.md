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

The following are asserted by the SNARK or the unchecked apply path;
transactions that violate them are rejected outright (not marked Failed),
so they never appear in any coverage-table row. All formulas below assume
they hold.

- `fee_payer == source` (`transaction_snark.ml:2339`)
- fee_payer's `access` accepts (all commands; `transaction_snark.ml:2530-2532`)
- fee_payer's `send` accepts (user commands only; `transaction_snark.ml:2543-2548`)
- fee_payer's `increment_nonce` accepts (user commands only; `transaction_snark.ml:2534-2541`)
- fee_payer's balance ≥ `fee` (`mina_transaction_logic.ml:488`)

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
| `user_command_fails`          | `1` iff a strict failure fires (`receiver_overflow` or one of the 8 conditions in `User_command_failure.t`); triggers an rcv + source rollback. See [note](#note-on-user_command_fails). |
| `source_delegation_permitted` | `1` iff the fee_payer's `set_delegate` permission accepts signature auth.                          |
| `set_to_unstaked`             | For stake_delegation, does `payload.body.receiver_pk` equal `empty_pk`?                            |
| `fee`                         | `payload.common.fee` (as an unsigned `Amount`).  |
| `payload.body.amount`         | The body amount field. meaning depends on tag — see coverage table.                                |
| `payment_permitted`           | `1` iff source send/access ∧ receiver receive/access. Source-side gates are asserted by the SNARK (see Preconditions), so on-chain `payment_permitted = 0` only via receiver-side rejection. |
| `fp_receive_ok`               | `1` iff fp's `access` ∧ `receive` accept (relevant when fp is a recipient — internal commands). fp's `access` is asserted (see Preconditions), so on-chain `fp_receive_ok = 0` only via `receive` rejection. |
| `rcv_receive_ok`              | `1` iff receiver's `access` ∧ `receive` accept.                                                    |

### Note on `user_command_fails`

The name is misleading: the boolean fires for both user and internal
commands. It is the OR of:

- the 8 fields of `User_command_failure.t`
  (`transaction_snark.ml:217-231`):
  `predicate_failed`, `source_not_present`, `receiver_not_present`,
  `amount_insufficient_to_create`, `token_cannot_create`,
  `source_insufficient_balance`, `source_minimum_balance_violation`,
  `source_bad_timing`. The per-field comments in the SNARK source flag
  each as user-command-specific.
- `receiver_overflow` (`transaction_snark.ml:2932`), which can fire on
  any command — e.g. a Coinbase to a near-max-balance receiver.

When true, `final_root` resets to `root_after_fee_payer_update`
(`transaction_snark.ml:3213`), undoing the rcv-pass and source-pass
balance updates. Only the fee_payer-pass effect sticks.

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
| User command   | `fp_bal − fee − (payment_permitted ∧ ¬user_command_fails) · body.amount`        | `(payment_permitted ∧ ¬user_command_fails) · amount` |
| Fee_transfer   | `fp_bal + fee` [^fp-slot] [^fee-credit]                                         | `body.amount`                                       |
| Coinbase       | `fp_bal + fee` [^fp-slot] [^fee-credit]                                         | `body.amount − fee`                                 |

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
- the gate state that puts the row in scope,
- the resulting `Δfp_bal`, `Δrcv_bal`, and `fp_staked' − fp_staked`,
- the reduced-form expression by substitution.

The `#` column is the row number. Tests for each row are tagged
`(* unstaking_tx_case_<#>[.<sub>] *)` in
`src/lib/transaction_logic/test/transaction_logic/stake_change.ml` and
`src/lib/transaction_snark/test/stake_change_snark/stake_change_snark.ml`.

Permission-rejection variants don't get their own rows: flipping a gate
in the Gates column zeroes the corresponding Δ. E.g. row 9 with
`¬fp_receive_ok` gives `Δfp_bal = 0` → `fee₁·rcv_staked`.

| #  | Tag                                     | `fee_payer` slot        | `receiver` slot        | `fee`     | `body.amount` | Gates                                                  | `Δfp_bal`           | `Δrcv_bal`         | `fp_staked' − fp_staked` | Reduced form collapses to                              |
|----|-----------------------------------------|-------------------------|------------------------|-----------|---------------|--------------------------------------------------------|---------------------|--------------------|--------------------------|--------------------------------------------------------|
| 1  | Payment, success                        | sender                  | payee                  | `fee`     | amount        | `payment_permitted ∧ ¬user_command_fails`              | `−fee − amount`     | `+amount`          | `0`                      | `−fee·fp_staked + amount·(rcv_staked − fp_staked)`     |
| 2  | Payment, body didn't transfer           | sender                  | payee                  | `fee`     | amount        | `¬payment_permitted ∨ user_command_fails`              | `−fee`              | `0`                | `0`                      | `−fee·fp_staked`                                       |
| 3  | Stake_delegation, Some→Some             | delegator               | new delegate           | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `0`                      | `−fee`                                                 |
| 4  | Stake_delegation, Some→None (opt-out)   | delegator               | `empty_pk`             | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `−1`                     | `−fp_bal`                                              |
| 5  | Stake_delegation, None→Some (opt-in)    | delegator               | new delegate           | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `+1`                     | `fp_bal − fee`                                         |
| 6  | Stake_delegation, None→None             | delegator               | `empty_pk`             | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `0`                      | `0`                                                    |
| 7  | Stake_delegation, not permitted/failed  | delegator               | anything               | `fee`     | `0`           | `¬source_delegation_permitted ∨ user_command_fails`    | `−fee`              | `0`                | `0` [^delegate-fail]     | `−fee·fp_staked`                                       |
| 8  | Fee_transfer, one single                | `fee_payer ≡ receiver` [^single-recipient] | `fee_payer ≡ receiver` | `0`       | `fee`         | `rcv_receive_ok ∧ ¬user_command_fails`                 | `0`                 | `+fee`             | `0`                      | `fee·rcv_staked`                                       |
| 9  | Fee_transfer, two singles               | `pk₂` [^fp-slot]        | `pk₁`                  | `fee₂` [^fee-credit] | `fee₁` | `fp_receive_ok ∧ rcv_receive_ok ∧ ¬user_command_fails` | `+fee₂`             | `+fee₁`            | `0`                      | `fee₂·fp_staked + fee₁·rcv_staked`                     |
| 10 | Coinbase, no fee_transfer               | block producer [^single-recipient] | block producer         | `0`       | `full`        | `rcv_receive_ok ∧ ¬user_command_fails`                 | `0`                 | `+full`            | `0`                      | `full · rcv_staked`                                    |
| 11 | Coinbase, with fee_transfer             | snark worker [^fp-slot] | block producer         | `ft_fee` [^fee-credit] | `full` | `fp_receive_ok ∧ rcv_receive_ok ∧ ¬user_command_fails` | `+ft_fee`           | `+(full − ft_fee)` | `0`                      | `ft_fee·fp_staked + (full − ft_fee)·rcv_staked`        |

### Rows representing Failed-status txs

A tx that fails one of its in-row gates but still satisfies the
[Preconditions](#preconditions) is committed to the chain with
`status = Failed`: the fee_payer pass sticks (fee debited, nonce
incremented), the rest is unwound.

- **Row 2** — Payment, with `¬payment_permitted ∨ user_command_fails`.
  Body amount stayed in source.
- **Row 7** — Stake_delegation, with
  `¬source_delegation_permitted ∨ user_command_fails`. Delegate field
  unchanged.
- **Rows 8–11** with any of the in-row gates inverted (`¬fp_receive_ok`,
  `¬rcv_receive_ok`, or `user_command_fails`). The rejected slot's
  credit is burned; the other slot's credit (if any) still applies.

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

[^single-recipient]: This tx has only one real account, but
    `Transaction_union` fills both slots with it (`fee_payer_pk =
    receiver_pk`) and sets `common.fee = 0`, so `Δfp_bal = 0` regardless
    of fp's permissions. The full credit lives in `body.amount` and
    flows through the rcv slot.

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
