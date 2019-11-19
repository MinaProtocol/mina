## Time-locked and time-vesting accounts

Accounts may contain funds that are available to send at a certain
time or according to a vesting schedule.

## Motivation

Time-locked accounts are useful to delay the availability of
funds. Such accounts have been used in other cryptocurrencies to
implement features such as payment channels. The locking
feature can be used to create incentives; if the account holder
performs a certain action, the account can be funded so that
the locked funds are released.

Vesting schedules are a generalization of the time-locking
mechanism, where funds become increasingly available over time.
There are two times specified, one that indicates when some
amount of funds becomes available to send, and another, later time
that specifies when all funds become available to send. The amount
available to send increases between those two times.

## Detailed design

Accounts may have no timing restrictions, have a time lock, or a
vesting schedule. In Coda, the type `Account.t` is a record type with
several fields.  An additional field `timing` could contain an element
of a sum type with three alternatives: `No_timing`, `Time_locked`, and
`Time_vested`.

`No_timing` means there are no time restrictions on sending funds.

A `Time_locked` value contains an `unlock time`, expressed as a global
slot value, and a `locked amount`. Until the unlock time has passed, the
account can only send funds from its balance that are in excess of the
locked amount. Once the unlock time has passed, there are no
restrictions on sending.

A `Time_vested` value contains a `cliff` time, a `vested` time, a
`cliff amount` and a `vested_amount`. The vested amount is strictly
greater than the cliff amount. Until the cliff time has passed, the
account can send only funds from its balance that are in excess of the
cliff amount. After the cliff time has passed and until the vested
time, more funds are available in proportion to time. During that period,
the sending bound is:
```
  amount_diff = vested_amount - cliff_amount
  time_diff = 1 - ((vested_time - current_time) / (vested_time - cliff_time))
  spending_limit = cliff_amount + amount_diff * time_diff
```
Once the vested time has passed, there are no restrictions on sending.

For both time locked and vesting accounts, it's possible for the 
account balance to be less than the spending bound. For example,
an employee time-locked account may have a locked amount of 1M Coda.
If the employee resigns before the unlock time, the employer could
decide not to send 1M Coda to the account, so the employee would
not receive that benefit.

Nothing prevents sending funds to time locked and vesting accounts.
Consider the time-locked employee account just mentioned. If a
benefactor sends 3M Coda to the employee's account, then before the
unlock time, the employee can send 2M Coda (ignoring fee calculations
for simplicity).  1M Coda are still locked up in the account until
the unlock time.

# Implementation

The restrictions on sending funds need to be enforced in the
transaction SNARK and out-of-SNARK. If the restrictions are violated,
an error occurs.

For the out-of-SNARK transaction, the relevant code location to
enforce the restrictions appears to be in
`Transaction_logic.apply_user_command_unchecked`.  In that function,
we have the sender's account available, so we can examine the `timing`
field. We don't currently have the current global slot information 
available. One solution is would be to timestamp ledgers with a global
slot in some way, indicating when it was last modified.

For the in-SNARK transaction, the restriction would be enforced in
`Transaction_snark.apply_tagged_transaction`. There, we have the `var`
form of the proposed transaction, and of the ledger root. Again, there
is no notion of global slot there. A timestamp added to the ledger
could be made available as a new `Request`.

## Drawbacks

Adding this feature makes the account data slightly larger, slows down
the validation of transactions, and makes the implementation a bit more
complex. Those considerations should be weighed against the utility of the 
feature to users.

## Rationale and alternatives

Instead of using a global slot time, we could use block height.

`Time_vested` is a generalization of `Time_locked`, so we could dispense
with the latter.

## Prior art

Bitcoin uses a block field `nLockTime`, denoting a block time, which can be used to 
time-lock individual transactions. There are many articles about time-locked accounts for 
Ethereum by programming smart contracts. See, for example: 
https://medium.com/bitfwd/time-locked-wallets-an-introduction-to-ethereum-smart-contracts-3dfccac0673c.
Beyond cryptocurrencies, vesting of benefits is a well-established idea in employment.

## Unresolved questions

Where can the global slot be added to ledgers? Is there a better way to make a global slot available 
when validating a transaction, other than it to ledgers? Is there a notion of time better than
global slot for this purpose?
