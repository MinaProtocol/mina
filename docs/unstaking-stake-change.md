# `stake_change` — transaction-SNARK invariant

This note documents the universal formula that the `transaction_union` base
circuit asserts to compute `stake_change` for every non-zkapp transaction
(Payment, Stake_delegation, Fee_transfer, Coinbase), plus a coverage table
showing how each `Transaction_union.Tag` maps onto the formula's inputs.

It is the reference for:

- `apply_tagged_transaction` in `src/lib/transaction_snark/transaction_snark.ml`
  (the checked computation).
- `Transaction_applied.stake_change` in
  `src/lib/transaction_logic/transaction_applied.ml` (the unchecked computation
  used by `staged_ledger.ml` and `transaction_snark_scan_state.ml`).

Both implementations must agree for the SNARK scan state to verify proofs
against the expected statement. This document is the single source of truth
for *what* they must agree on.

Zkapp transactions are **out of scope** for this doc: they walk a call-forest
of per-account_update contributions and don't fit a closed form. See
`zkapp_command_logic.ml` for their accumulation logic.

## Variables

| Symbol                        | Meaning                                                                                       |
|-------------------------------|-----------------------------------------------------------------------------------------------|
| `is_user_command`             | `1` for Payment / Stake_delegation; `0` for Fee_transfer / Coinbase.                          |
| `is_payment`                  | `1` for Payment; `0` otherwise.                                                                |
| `is_stake_delegation`         | `1` for Stake_delegation; `0` otherwise.                                                       |
| `user_command_fails`          | `1` if a user command failed to apply (fee is still deducted); `0` otherwise.                  |
| `source_delegation_permitted` | `1` iff the fee_payer's `set_delegate` permission allows this stake_delegation to apply.       |
| `fee_payer_pre_is_staked`               | Is `fee_payer.delegate` set (i.e. ≠ empty) **before** the tx?                                  |
| `fee_payer_pre_balance`              | `fee_payer.balance` before the tx.                                                             |
| `receiver_is_staked`                 | Is `receiver.delegate` set **before** the tx? (receivers don't change delegate in this circuit)|
| `set_to_unstaked`             | For a stake_delegation, does the new delegate equal `Public_key.Compressed.empty`?             |
| `fee`                         | `payload.common.fee` (as an unsigned `Amount`).                                                |
| `payload.body.amount`         | The body amount field. Meaning depends on tag — see coverage table.                            |
| `receiver_increase`           | Amount credited to `receiver`, computed earlier in the circuit. See coverage table.            |

## Derived: `fee_payer_post_is_staked`

The fee_payer's staked state *after* the transaction applies. Equal to
`fee_payer_pre_is_staked` unless a successful, permitted stake_delegation actually
changes the delegate:

```
delegate_actually_changes = is_stake_delegation
                          ∧ ¬user_command_fails
                          ∧ source_delegation_permitted

fee_payer_post_is_staked = delegate_actually_changes ? ¬set_to_unstaked
                                                  : fee_payer_pre_is_staked
```

## The formula

```
stake_change = is_user_command ? signed_cmd_delta : internal_delta
```

### Signed command (Payment or Stake_delegation)

```
signed_cmd_delta =
      fee_payer_pre_balance · (fee_payer_post_is_staked − fee_payer_pre_is_staked)   -- delegate transition
    − fee            · fee_payer_post_is_staked                      -- fee always deducted
    + (is_payment ∧ ¬user_command_fails)                          -- payment body
        · payload.body.amount · (receiver_is_staked − fee_payer_pre_is_staked)
```

Three pieces: a **delegate transition** term (zero for payments and for
failed/not-permitted delegations), a **fee deduction** term (always present
for user commands, gated on the *post-tx* staked state so it cancels the
transition term correctly when opting out), and a **payment body** term (only
active when the tx is a successful payment).

### Internal command (Fee_transfer or Coinbase)

```
internal_delta =
      fee               · fee_payer_pre_is_staked      -- fee credited to fee_payer slot
    + receiver_increase · receiver_is_staked         -- second recipient (if any)
```

The two slots `fee_payer_pre_is_staked` and `receiver_is_staked` correspond to the *two
accounts* touched by any internal command. When only one account is "real"
(Fee_transfer with a single recipient, or Coinbase with no snark-worker
fee_transfer), `fee = 0` and the duplication trick below disarms the double
credit.

## Coverage table

The `fee_payer`, `receiver`, `fee`, `body.amount`, and `receiver_increase`
columns show how each tag is encoded by `Transaction_union.of_transaction`
(see `src/lib/transaction/transaction_union.ml`). The final column shows
the corresponding branch of the formula collapsed to its operative terms.

In the last column only (for table readability) **`fp`** abbreviates
`fee_payer_pre_is_staked` and **`recv`** abbreviates `receiver_is_staked`.

| Tag                                    | `fee_payer` slot       | `receiver` slot        | `fee`    | `body.amount`   | `receiver_increase` | Formula collapses to                 |
|----------------------------------------|------------------------|------------------------|----------|-----------------|---------------------|--------------------------------------|
| Payment, success                       | sender                 | payee                  | `fee`    | amount          | amount              | `−fee·fp + amount·(recv − fp)`       |
| Payment, fail                          | sender                 | payee                  | `fee`    | amount          | amount              | `−fee·fp`                            |
| Stake_delegation, Some→Some            | delegator              | new delegate           | `fee`    | `0`             | `0`                 | `−fee`                               |
| Stake_delegation, Some→None (opt-out)  | delegator              | `empty_pk`             | `fee`    | `0`             | `0`                 | `−fee_payer_pre_balance`             |
| Stake_delegation, None→Some (opt-in)   | delegator              | new delegate           | `fee`    | `0`             | `0`                 | `fee_payer_pre_balance − fee`        |
| Stake_delegation, None→None            | delegator              | `empty_pk`             | `fee`    | `0`             | `0`                 | `0`                                  |
| Stake_delegation, not permitted        | delegator              | anything               | `fee`    | `0`             | `0`                 | `−fee·fp`                            |
| Stake_delegation, failed               | delegator              | anything               | `fee`    | `0`             | `0`                 | `−fee·fp`                            |
| Fee_transfer, one single               | `fee_payer ≡ receiver` | `fee_payer ≡ receiver` | `0`      | `of_fee(fee)`   | `fee`               | `fee·recv`                           |
| Fee_transfer, two singles              | `pk₂`                  | `pk₁`                  | `fee₂`   | `of_fee(fee₁)`  | `fee₁`              | `fee₂·fp + fee₁·recv`                |
| Coinbase, no fee_transfer              | `fee_payer ≡ receiver` | `fee_payer ≡ receiver` | `0`      | `full`          | `full`              | `full_coinbase · recv`               |
| Coinbase, with fee_transfer            | ft recipient           | coinbase receiver      | `ft_fee` | `full`          | `full − ft_fee`     | `ft_fee·fp + (full − ft_fee)·recv`   |

### Why the encoding tricks work

Two tx types (Coinbase without ft, Fee_transfer with one single) have only
*one* real account, but `Transaction_union` still fills in both `fee_payer`
and `receiver` slots. The encoding handles this by:

1. Setting `fee_payer_pk = receiver_pk` (same account in both slots).
2. Setting `fee = 0` so the `fee · fee_payer_pre_is_staked` term in
   `internal_delta` vanishes.
3. Putting the entire credit in `body.amount` so that `receiver_increase`
   equals the full payment.

The net result is that the single account gets credited once via the
`receiver` slot, and the `fee_payer` slot contributes nothing.

## How the circuit uses this

`apply_tagged_transaction` computes `stake_change` via the formula above and
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
produce a value that matches this invariant — they do, because the unchecked
implementation uses the same semantics (just expressed as a per-update
simulation rather than a closed-form circuit polynomial).
