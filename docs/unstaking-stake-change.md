# `stake_change` — transaction spec

This note specifies how `stake_change` is computed for every transaction
kind. The value is given by a single definition (sum of per-account
stake deltas over touched accounts), specialized per non-zkApp tag in
the [Coverage table](#coverage-table), and applied uniformly per
account_update for zkApp transactions ([zkApp transactions](#zkapp-transactions)).

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

`total_stake` is the sum over all **default-token** accounts `a` of
`balance(a) · is_staked(a)`, where `is_staked(a) = 1` iff
`a.delegate ≠ empty_pk`.

By protocol invariant, non-default-token accounts cannot have a
non-empty delegate, so restricting the sum to default-token doesn't
hide any stake.

For a transaction `tx` touching some set of default-token accounts
`A(tx)`:

```
stake_change(tx) = Σ_{a ∈ A(tx)}  balance'(a) · is_staked'(a)
                 − Σ_{a ∈ A(tx)}  balance (a) · is_staked (a)
```

Accounts outside `A(tx)` contribute zero by construction (both balance and
delegate unchanged), so the sum over the whole ledger reduces to the sum
over touched accounts.

For non-zkApp tags, `A(tx) = {fee_payer, receiver}` (possibly identical — see
encoding notes below; both slots are default-token by `Transaction_union`'s
encoding, `transaction_union.ml:32`).

Equivalently, defining each account's stake contribution as

```
stake(a) = if is_staked(a) then balance(a) else 0
```

gives

```
stake_change(tx) = Σ_{a ∈ A(tx)}  stake'(a) − stake(a)
```

## Variables

| Symbol                        | Meaning                                                                                            |
|-------------------------------|----------------------------------------------------------------------------------------------------|
| `fp_staked`  / `fp_staked'`   | Is `fee_payer.delegate` set, before / after the tx.                                                |
| `fp_bal`     / `fp_bal'`      | `fee_payer.balance`, before / after the tx.                                                        |
| `Δfp_bal`                     | `fp_bal' − fp_bal`, signed.                                                                        |
| `rcv_staked`                  | Is `receiver.delegate` set. No non-zkApp tag touches it, so pre = post.                            |
| `rcv_bal`    / `rcv_bal'`     | `receiver.balance`, before / after the tx.                                                         |
| `Δrcv_bal`                    | `rcv_bal' − rcv_bal`, signed.                                                                      |
| `is_stake_delegation`         | `1` for Stake_delegation; `0` otherwise. Used only in the derived `fp_staked'` formula.            |
| `user_command_fails`          | `1` iff a strict failure fires (`receiver_overflow` or one of the 8 conditions in `User_command_failure.t`); triggers an rcv + source rollback. See [note](#note-on-user_command_fails). |
| `source_delegation_permitted` | `1` iff the fee_payer's `set_delegate` permission accepts signature auth.                          |
| `set_to_unstaked`             | For stake_delegation, does `payload.body.receiver_pk` equal `empty_pk`?                            |
| `fee`                         | `payload.common.fee` (as an unsigned `Amount`).  |
| `body.amount`                 | The body amount field; meaning depends on tag — see coverage table.                                |
| `payment_permitted`           | `1` iff source send/access ∧ receiver receive/access.                                              |
| `fp_receive_ok`               | `1` iff fp's `access` ∧ `receive` accept (relevant when fp is a recipient — internal commands).    |
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

When true, the rcv-pass and source-pass balance updates are not
committed to the ledger; only the fee_payer-pass effect sticks.

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

## Coverage table

Each row specializes the [definition](#definition) to one transaction
tag. The columns record:
- the encoding (which account each slot points to, and what goes into
  `fee` / `body.amount`),
- the gate state that puts the row in scope,
- the per-slot deltas `Δfp_bal` and `Δrcv_bal`,
- the resulting `stake_change`.

The `#` column is the row number. Tests for each row are tagged
`(* stake_change_row_<#>[.<sub>] *)` in
`src/lib/transaction_logic/test/transaction_logic/stake_change.ml` and
`src/lib/transaction_snark/test/stake_change_snark/stake_change_snark.ml`.

Permission-rejection variants don't get their own rows: flipping a gate
in the Gates column zeroes the corresponding Δ. E.g. row 9 with
`¬fp_receive_ok` gives `Δfp_bal = 0` → `stake_change = fee₁·rcv_staked`.

| #  | Tag                                     | `fee_payer` slot        | `receiver` slot        | `fee`     | `body.amount` | Gates                                                  | `Δfp_bal`           | `Δrcv_bal`         | `stake_change`                                         |
|----|-----------------------------------------|-------------------------|------------------------|-----------|---------------|--------------------------------------------------------|---------------------|--------------------|--------------------------------------------------------|
| 1  | Payment, success                        | sender                  | payee                  | `fee`     | amount        | `payment_permitted ∧ ¬user_command_fails`              | `−fee − amount`     | `+amount`          | `−fee·fp_staked + amount·(rcv_staked − fp_staked)`     |
| 2  | Payment, body didn't transfer           | sender                  | payee                  | `fee`     | amount        | `¬payment_permitted ∨ user_command_fails`              | `−fee`              | `0`                | `−fee·fp_staked`                                       |
| 3  | Stake_delegation, Some→Some             | delegator               | new delegate           | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `−fee`                                                 |
| 4  | Stake_delegation, Some→None (opt-out)   | delegator               | `empty_pk`             | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `−fp_bal`                                              |
| 5  | Stake_delegation, None→Some (opt-in)    | delegator               | new delegate           | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `fp_bal − fee`                                         |
| 6  | Stake_delegation, None→None             | delegator               | `empty_pk`             | `fee`     | `0`           | `source_delegation_permitted ∧ ¬user_command_fails`    | `−fee`              | `0`                | `0`                                                    |
| 7  | Stake_delegation, not permitted/failed  | delegator               | anything               | `fee`     | `0`           | `¬source_delegation_permitted ∨ user_command_fails`    | `−fee`              | `0`                | `−fee·fp_staked` [^delegate-fail]                      |
| 8  | Fee_transfer, one single                | `fee_payer ≡ receiver` [^single-recipient] | `fee_payer ≡ receiver` | `0`       | `fee`         | `rcv_receive_ok ∧ ¬user_command_fails`                 | `0`                 | `+fee`             | `fee·rcv_staked`                                       |
| 9  | Fee_transfer, two singles               | `pk₂` [^fp-slot]        | `pk₁`                  | `fee₂` [^fee-credit] | `fee₁` | `fp_receive_ok ∧ rcv_receive_ok ∧ ¬user_command_fails` | `+fee₂`             | `+fee₁`            | `fee₂·fp_staked + fee₁·rcv_staked`                     |
| 10 | Coinbase, no fee_transfer               | block producer [^single-recipient] | block producer         | `0`       | `full`        | `rcv_receive_ok ∧ ¬user_command_fails`                 | `0`                 | `+full`            | `full · rcv_staked`                                    |
| 11 | Coinbase, with fee_transfer             | snark worker [^fp-slot] | block producer         | `ft_fee` [^fee-credit] | `full` | `fp_receive_ok ∧ rcv_receive_ok ∧ ¬user_command_fails` | `+ft_fee`           | `+(full − ft_fee)` | `ft_fee·fp_staked + (full − ft_fee)·rcv_staked`        |

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

## zkApp transactions

A `Zkapp_command.t` (`zkapp_command.ml:8-13`) carries:

- a **fee_payer**, a single account_update of restricted shape: a fixed
  `−fee` balance change, no field updates, signature auth on the default
  token (`account_update.ml:1365-1395`),
- a **call forest of account_updates**, each able to change balance,
  delegate, app_state, permissions, etc., subject to per-update
  preconditions and authorization.

Application proceeds in two phases:

1. **First pass**: apply the fee_payer. Always sticks (assuming the tx
   is included in a block).
2. **Second pass**: apply the call forest. If every update is permitted,
   all effects apply. If any update fails a check, the entire second
   pass is cancelled — only the fee_payer's debit remains
   (`mina_transaction_logic.ml:1828-1838`).

### Definition (unchanged)

The [Definition](#definition) applies as-is:

```
stake_change(tx) = Σ_{a ∈ A(tx)}  stake'(a) − stake(a)
```

`A(tx)` for a zkApp tx is `Zkapp_command.accounts_referenced` (the
deduplicated set of accounts targeted by the fee_payer or any
account_update; `zkapp_command.ml:309-311`), restricted to the
default-token entries.

### Per-account_update contributions

For a single account_update `u` targeting account `a`:

- balance: `balance'(a) ← balance(a) + u.balance_change` (if `u`
  applies),
- delegate: `delegate'(a) ← u.update.delegate.set_or_keep delegate(a)`
  (if `u` applies, and only for default-token accounts).

Whether `u` applies depends on its preconditions, authorization, and
per-field permissions — the spec doesn't enumerate these, it just refers
to "successful application".

If the same account is touched by several account_updates, only the
*final* state of that account enters the stake-delta sum.

**Definition (per-account shape).** Write `(p, q)` for the
*per-account shape* of `a` under `tx`, where
`p = is_staked(a)` (pre) and `q = is_staked(a)` (post). The per-account
contribution `stake'(a) − stake(a)` resolves to one of four values
indexed by this shape:

| shape `(p, q)` | per-account Δstake             |
|----------------|--------------------------------|
| `(0, 0)`       | `0`                            |
| `(0, 1)`       | `balance'(a)`                  |
| `(1, 0)`       | `−balance(a)`                  |
| `(1, 1)`       | `balance'(a) − balance(a)`     |

(Direct substitution of the conditional `stake(a) = if is_staked(a) then
balance(a) else 0`.)

### Failure → fee_payer-only

When the second pass fails, only the fee_payer's debit applies. Since
the fee_payer never changes its own delegate (its `update = Update.noop`),
its contribution is:

```
stake_change = (balance(fp) − fee) · is_staked(fp) − balance(fp) · is_staked(fp)
            = −fee · is_staked(fp)
```

### Test case spine

Unlike the non-zkApp [coverage table](#coverage-table) — which enumerates
the finite set of `(tag, encoding)` shapes — the zkApp space is
combinatorial in the size and shape of the call forest. The table below
is therefore not a *combinatorial* coverage but the **minimum case
spine** that, if all rows pass, exercises every distinct branch of the
spec: each per-account stake transition (z3–z5), the fee-payer-only
baseline (z1, z2), the multi-update aggregation rules (z6, z7), the
failure path (z8), the default-token restriction in the sum (z9, z10),
and the field-set restriction to balance + delegate (z11).

Tests in `src/lib/transaction_logic/test/transaction_logic/zkapp_stake_change.ml`
are tagged `(* zkapp_stake_change_row_z<N> *)` to map back to these
rows, mirroring the `stake_change_row_X.Y` convention used for the
non-zkApp table.

| #   | Scenario                                              | Coverage role                                                                  | Expected `stake_change`               |
|-----|-------------------------------------------------------|--------------------------------------------------------------------------------|---------------------------------------|
| z1  | fee_payer staked, no other updates                    | Baseline: fp slot only, per-account shape `(1,1)`                              | `−fee`                                |
| z2  | fee_payer unstaked, no other updates                  | Baseline: fp slot only, per-account shape `(0,0)`                              | `0`                                   |
| z3  | One update: balance change on staked target           | Per-account shape `(1,1)` for a non-fp target                                  | `−fee·fp_staked + Δbal_t`             |
| z4  | One update: opt-in (delegate `None → Some`)           | Per-account shape `(0,1)`                                                      | `−fee·fp_staked + balance'(t)`        |
| z5  | One update: opt-out (delegate `Some → empty_pk`)      | Per-account shape `(1,0)`                                                      | `−fee·fp_staked − balance(t)`         |
| z6  | Two updates on the same target                        | Telescoping: only the final state of `t` enters the sum                        | depends on final state, not interim   |
| z7  | Two updates on two distinct targets                   | Sum-over-`A(tx)`: contributions from distinct accounts add                     | sum of per-account contributions      |
| z8  | Second-pass check fails                               | Failure rollback: only the fee_payer's debit sticks                            | `−fee·fp_staked`                      |
| z9  | Non-default-token update: balance change              | Default-token restriction; payment-mirror furthest from a signed_command       | `−fee·fp_staked`                      |
| z10 | Non-default-token update: delegate Set                | Default-token restriction; delegate-mirror furthest from a signed_command      | `−fee·fp_staked`                      |
| z11 | Default-token update: app_state / permissions only    | Field-set restriction: `stake_change` depends only on balance and delegate     | `−fee·fp_staked`                      |

