## Time-locked and time-vesting accounts

Accounts may contain funds that are available to send according to a 
vesting schedule.

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
of a sum type with three alternatives: `Untimed` and `Timed`.

`Untimed` means there are no time restrictions on sending funds.

A `Timed` value contains an `initial_minimum_balance`, `cliff` time, 
a `cliff amount`, a `vesting_period` time, and a `vesting_increment`.
Until the cliff time has passed, the account can send only funds from 
its balance that are in excess of the initial minimum balance. After the 
cliff time has passed, more funds are available, by calculating a current 
minimum balance which decreases over time. The minimum balance decreases
by the vesting increment for each vesting period:
```
  current_minimum_balance = 
    if global_slot < cliff_time 
	then 
	  initial_minimum_balance
	else 
	  max 0 (initial_minimum_balance - ((global_slot - cliff_time) / vesting_period) * vesting_increment))
```
(where / is integer division).

If a transaction amount would make the account balance less than
the current minimum, the transaction is disallowed.

Nothing prevents sending funds to timed accounts. When timed accounts
are created, the balance must be at least the initial minimum balance.
The account can receive additional funds, and funds can be spent,
as long as the minimum balance invariant is maintained.

A time-locked account time, can be created by using a vesting increment 
equal to the initial minimum balance and a vesting period of one slot.
(In the calculation above, using a vesting period of zero would result in a 
division by zero.)

# Implementation

The restrictions on sending funds need to be enforced in the
transaction SNARK and out-of-SNARK. If the restrictions are violated,
an error occurs.

For the out-of-SNARK transaction, the relevant code location to
enforce the restrictions appears to be in
`Transaction_logic.apply_user_command_unchecked`.

For the in-SNARK transaction, the restriction would be enforced in
`Transaction_snark.apply_tagged_transaction`.

## Drawbacks

Adding this feature makes the account data slightly larger, slows down
the validation of transactions, and makes the implementation a bit more
complex. Those considerations should be weighed against the utility of the 
feature to users.

## Rationale and alternatives

Instead of using a global slot time, we could use block height. The global
slot time is available via the protocol state, which will be made available
to transactions.

## Prior art

Bitcoin uses a block field `nLockTime`, denoting a block time, which can be used to 
time-lock individual transactions. There are many articles about time-locked accounts for 
Ethereum by programming smart contracts. See, for example: 
https://medium.com/bitfwd/time-locked-wallets-an-introduction-to-ethereum-smart-contracts-3dfccac0673c.
Beyond cryptocurrencies, vesting of benefits is a well-established idea in employment.

## Unresolved questions

Do timed accounts interact with staking in any way?


