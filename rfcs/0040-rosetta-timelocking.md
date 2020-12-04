## Summary

[summary]: #summary

This is a proposal for supporting time-locked account tracking in Rosetta. Though, really, it boils down to supporting historical balance lookups for accounts through the archive node (some of which may have time locks on them). We are still considering adding support for time-locked account creation after the genesis block, this proposal aims to describe what changes we could make to the design and implementation in the scenario that we do wish to support this feature.

## Motivation

[motivation]: #motivation

Right now, Rosetta can not handle accounts with time locks on them. The specification demands we present the liquid balance in the accounts. Unfortunately, in the protocol we sample the liquidity curve at the moment funds are attempting to be transferred which is at odds with how Rosetta attempts to understand the world. We wish to support this.

## Detailed design

[detailed-design]: #detailed-design

### Balance exemptions and historical balance lookups

Rosetta supports the notion of a balance exempt account. These are accounts that one should not use operations alone to monitor changes in balance. The specification details that this should be used sparingly, but goes on to suggest that vesting accounts are one such example. If we only support time-locked accounts in the genesis ledger, all we need to do is at Rosetta-server-startup-time is pull those time-locked account addresses and fill the balance exemption field. If we don't, we'll need to update this field dynamically, it remains to be seen if this is allowable by the Rosetta specification, see unresolved question 1.

This is not a solution alone -- the specification goes on to say that in the case that one or more accounts are balance exempt, you must support historical balance lookups. This is difficult for us because Mina's constant-sized blockchain does not contain historical data. We use the archive node to store extra data for us -- we're already using it to store all the blocks that our nodes see. In order to support historical balance lookups, we have to add extra information so we can compute this data. Specifically, we'll add information about the current balance of any accounts touched during a transaction whenever we store in the archive node. We can use this and the genesis ledger from Rosetta to reconstruct the current balance of any account at any block by crawling backward from that block until we see a transaction (or fallback to the genesis ledger if no such transaction exists). Additionally, we can use the extra timing information in time-locked accounts in the genesis ledger to sample the liquidity curve at any moment as well. In the universe where we need to support time-locked account creation after genesis, we should be able to extract the timing information from the relevant transaction that creates the account via the archive node as well.

### Implementation details

In some cases, two separate approaches are outlined. This RFC proposes that we go with Approach A in the case that by mainnet we do not need to support creating time-locked accounts after the genesis ledger, and Approach B if we do end up needing to support this feature.

**Protocol/Archive**

- Add a new table `balances` to the SQL database with the following schema:

```
id,
public_key,
amount
```

- Add a new table `user_commands_balances` to the SQL database with the following schema:

```
user_command_id,
balance_id
```

- Add a new table `internal_commands_balances` to the SQL database with the following schema:

```
internal_command_id,
balance_id
```

- (Approach B) Add a new table `timing_info` to the SQL database with the following schema:

```
public_key,
<timing_info>
```

- Change the SQL schema to add relevant indexes to support the SQL query we'll be performing from Rosetta
- Populate the new tables with the relevant info every time we add transactions to the archive node (remember to look at fee, sender, and receiver)
- (Approach B) Pull the genesis ledger (either via RocksDB or JSON, see unresolved question 3) and add timing information to the database to the `timing_info` table
- (Approach B, in the case we support time-locked account creation after genesis) Every time we create a new time locked account, add to the `timing_info` table

**Rosetta**

- Set historical-balance-lookups to true
- (Approach A) Pull in the genesis ledger (either via RocksDB or JSON, see unresolved question 3)
- Use the time-locked accounts to populate the balance exemption field (either via the database Approach B) or from the genesis ledger (Approach A).
- Change `/account/balance` queries to support the block-identifier parameter and use it to perform the following SQL queries against the archive node:

1. Recursively traverse the canonical chain until you find the starting block that the identifier points to (we already have a similar query in the `/block` section, use this as a starting point)
2. Recursively traverse the chain backward from that point until you find the first transaction that involves the public key (either via fee, sender, receiver) specified in the `/account/balance` parameter
3. Use the join-tables to find the relevant data in the `balances` table and look at the amount

- For `/account/balance` queries involving the time-locked accounts, use the time-locking functions that already exist https://github.com/MinaProtocol/mina/blob/92ea2c06523559b9980658d15b9e5271400ac856/src/lib/coda_base/account.ml#L561 using the timing info either in the genesis ledger (Approach A) or the database (Approach B) and the balance we found above.

## Drawbacks

[drawbacks]: #drawbacks

This will increase the size of our archived data by a factor of around two. This seems acceptable.

## Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

### Use a Rosetta operation to unlock tokens each block

The nice thing about this approach is we wouldn't have to change our protocol, and we use operations -- the atomic unit of change in Rosetta -- to model tokens vesting.

This approach is not ideal from a scalability perspective because we would need to generate synthetic operations adding the liquid balances to every single currently vesting account.

There is also another more serious reason that this approach is unacceptable: Floating-point rounding issues will cause the sum of the parts to not equal the whole. In other words, summing each of the synthetic operations growing the liquid balance up until block `b`, would not be equal to querying the liquid balance at block `b` itself.

### Change the protocol

Other protocols that have similar time-locked accounts require an explicit on-chain transaction to move liquid funds out of the vesting account before they are actually usable. If we changed our protocol to support such a transaction, it would be trivial to model this in Rosetta.

However, this provides a worse experience for users. Even though they know their account has liquid funds, and even though the _protocol_ knows their account has liquid funds, a separate transaction is required before they're usable.

Additionally, we want to avoid changing the protocol this close to a looming mainnet launch.

## Prior art

[prior-art]: #prior-art

Celo's and Solana's Rosetta implementation is similar to the "Change the protocol" section in Rationale and Alternatives.

## Unresolved questions

[unresolved-questions]: #unresolved-questions

I would like at least (2) and (3) resolved before we do significant implementation work on this feature.

1. Will the Rosetta team officially be okay with this approach, even in the world where we need time locked account creation after genesis (and thus need a non-static balance exemption list) . See this discourse thread for more info:
   https://community.rosetta-api.org/t/representing-minas-vesting-accounts-using-balance-exemptions/317

2. Is Approach A actually easier if we don't yet support time-locked account creation after genesis? We will eventually need to support this later, are we wasting time if we don't just go with Approach B?

3. Assuming we go with Approach A, is it easier to retrieve genesis ledger information from the RocksDB database or from the JSON in the runtime ledger
