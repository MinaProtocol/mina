## Summary

[summary]: #summary

In this RFC, we describe the changes needed for Rosetta to support the upcoming (pending community approval) Mina hardfork which contains zkApps.

The work entails supporting the existing legacy transactions with the new archive schema, adding support for the hardfork and zkapp transactions, and testing.


## Motivation

[motivation]: #motivation

We wish for [Rosetta](https://www.rosetta-api.org/) to support zkApps and other changes present in the (pending community approval) Mina hardfork.

The desired outcome is fully updating the Rosetta implementation to support this hardfork and sufficiently test it.

## Detailed design

[detailed-design]: #detailed-design

The work encompassed in this upgrading can be broken down into four sections:

1. Supporting existing legacy transactions with the new archive schema
2. Handling the new zkApp compatible transactions
3. Supporting hardforks
4. Testing

### Legacy Transaction Support

The new archive schema has made a fundamental design shift to record balance changes at the per-block level of granularity rather than the per-transaction one. To read more about this change, see the [associated RFC, 0045](./0045-zkapp-balance-data-in-archive.md).

The changes needed for Rosetta to support these changes are outlined in the [0045 RFC](./0045-zkapp-balance-data-in-archive.md) under the "Changes to Rosetta" sub-heading.

To summarize, for the `Account` endpoint, the SQL queries can be simplified to merely a pending and canonical query to the new `accounts_accessed` table; we no longer need to inspect individual transactions.

For the `Block` endpoint, adjust the queries to not rely on the bits that are no longer present in the existing tables, and add a new SQL query to use the `accounts_accessed` table to pull the account-creation-fee parts.

### Handling zkApp transactions

zkApp Transactions will introduce many additions to our Rosetta implementation, but in an effort to keep the scope down, there are a few areas of Rosetta that will not support them.

Rosetta's spec demands that it be able to track all balance changes that result from transactions on the network; however, we don't need to be able to construct all such balances nor do we need to track balance changes that only involve custom tokens. In order to support custom tokens built on top of Mina we would need to both be able to broadcast zkApp transactions and also keep track of token changes.

#### Construction API

As such, custom tokens are _out of scope_ and thus the Rosetta Construction flow will _not_ need to change. Instead, we will continue to support the existing legacy transactions.

#### Data API

The [Data API](https://www.rosetta-api.org/docs/data_api_introduction.html) will need to change to support zkApps.

Most of the changes will be localized to supporting new zkApps related [Rosetta operations](https://www.rosetta-api.org/docs/models/Operation.html) and putting them in a new type of [Rosetta transaction](https://www.rosetta-api.org/docs/models/Transaction.html).

These new transactions will be present in both the `/block` and `/mempool` endpoints.

Note: GraphQL queries for zkApp transactions can be [generated programatically](https://github.com/MinaProtocol/mina/blob/develop/src/lib/mina_base/parties.ml#L1431) as they are quite large.

**Operations for zkApps**

[Operation types](https://github.com/MinaProtocol/mina/blob/35ed5e191af9cfa2709f567f6fe85d96dabfafef/src/lib/rosetta_lib/operation_types.ml) should be extended with new operations for all kinds of ways zkApp transactions can manipulate account balances (for each one-sided changes).

Luckily this is made extremely clear by the shape of the zkApps transaction structure.

The following intends to be an exhaustive list of those sorts of operations:

1. `Zkapp_fee_payer_dec`
2. `Zkapp_balance_change`

Note that only balance changes that correspond with the default MINA token (`token_id` = 1) should be considered as changes here.

There are many new types of failures and they're per-party in zkApps transactions. These are enumerated in [`transaction_status.ml`](https://github.com/MinaProtocol/mina/blob/a6e5f182855b3f4b4afb0ea8636760e618e2f7a0/src/lib/mina_base/transaction_status.ml). They can be pulled from the `zkapp_party_failures` table in the archive database. Since the errors are already per-party, they're easily associated with operations on a one-to-one basis. These can be added verbatim to as ["reason metadata"](https://github.com/MinaProtocol/mina/blob/a6e5f182855b3f4b4afb0ea8636760e618e2f7a0/src/lib/rosetta_lib/user_command_info.ml#L449) to those operations with a `Failed` label.

### Supporting hardforks

Changes will need to be made to `/network/status` such that the genesis block is the first block of the hardfork network (so it's index will be greater than 1; to be determined when we fork). This is important to be the true block height or else the archive data queries will be incorrect.

`/network/list` will remain unchanged as in the hardfork world the old network "doesn't exist".

### Testing

#### Rosetta CLI

Rosetta has a [cli testing tool](https://github.com/coinbase/rosetta-cli) that must pass on this network.

See the [Rosetta README.md](https://github.com/MinaProtocol/mina/blob/develop/src/app/rosetta/README.md) for information on how to run this tool.

Ideally we can connect this CI as we've done in the past.

#### Test-curl

There are a series of shell scripts that can be manipulated to use the transaction construction tool in the `src/app/rosetta` folder. These should continue to pass: The [README.md](https://github.com/MinaProtocol/mina/blob/develop/src/app/rosetta/README.md) also contains information on these scripts.

## Drawbacks

[drawbacks]: #drawbacks

More effort, but needed for tooling support

## Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

We considered including custom tokens, but it will be extra work and not really
worth the effort at the moment as there are no widely used custom tokens (yet).

## Prior art

[prior-art]: #prior-art

Our existing implementation of Rosetta and archive schemas.

Also see the [Rosetta spec](https://www.rosetta-api.org/).

## Unresolved questions

[unresolved-questions]: #unresolved-questions

None at this time.
