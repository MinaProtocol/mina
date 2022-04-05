## Summary
[summary]: #summary

For zkApps, balances and account creation fees of the affected parties
are not being stored in the database. The data sent from the daemon to
the archive process does not contain such information. The archive
database schema does not have a place to store all such information, were
it provided.

Add additional information to the RPC data sent from the daemon, so
that account creation information and balances are provided for each
block. Update the schema to allow storing the information.

Currently, balance and nonce information is stored for each
transaction, which is more fine-grained than needed. Instead, store
complete account information, including balances and nonces, for each
account with a transaction in a block, just once for that block. That
should simplify both the code to store that information, and queries
for that information, as done by the Rosetta implementation.

We also wish to store account index information (ledger leaf order),
to allow predicting block winners from archive database information.

## Motivation
[motivation]: #motivation

The archive processor has no code to store balance and account
creation fee information for zkApp transactions. The replayer needs
such information in the archive database to verify balances and
nonces, and Rosetta needs it to respond to account queries.

## Detailed design
[detailed-design]: #detailed-design

### Changes to the archive database schema

Balances are no longer per-transaction, but per-block.

Table `blocks_internal_commands`, remove the column:

  `receiver_account_creation_fee_paid`
  `receiver_balance`

Table `blocks_user_commands`, remove the columns:

  `fee_payer_account_creation_fee_paid`
  `receiver_account_creation_fee_paid`
  `fee_payer_balance`
  `source_balance`
  `receiver_balance`

where the array contains account creation fees for each of the `other_parties`.
While the array is not nullable, array elements may be `NULL`.

The table `balances` is replaced by a new table `accounts_accessed`, with columns:
```
  block_id            int                NOT NULL  REFERENCES blocks(id)
  public_key          int                NOT NULL  REFERENCES public_keys(id)
  token               int                NOT NULL  REFERENCES tokens(id)
  token_permissions   token_permissions  NOT NULL
  balance             bigint             NOT NULL
  nonce               bigint             NOT NULL
  receipt_chain_hash  text               NOT NULL
  delegate            int                          REFERENCES public_keys(id)
  voting_for          text    NOT NULL
  timing              int                          REFERENCES timing_info(id)
  permissions         int     NOT NULL             REFERENCES zkapp_permissions(id)
  zkapp               int                          REFERENCES snapp_account(id)
  zkapp_uri           text    NOT NULL
```

The new type `token_permissions` is:

  `CREATE TYPE token_permission AS ENUM ('token_owned_new_accounts_disabled', 'token_owned_new_accounts_enabled',
                                         'token_not_owned_account_disabled', 'token_not_owned_account_enabled')`

(Alternatively, we could create a new table with four entries corresponding to these possibilities,
and refer to it with a foreign key.)

The new table `tokens` is:
```
  id                  serial  PRIMARY KEY
  token_id            text    NOT NULL
  token_symbol        text    NOT NULL
```

Table `public_keys`, add column:

  `ledger_index int  NOT NULL`

In order to include the hard fork genesis ledger accounts in this table, we may need
a separate app to populate it. Alternatively, once we have the genesis ledger, we
could use an app to dump the SQL needed to populate the table, and keep that SQL in the
Mina repository.

Add a new table `account_creation_fees`:
```
  block_id            int                NOT NULL  REFERENCES blocks(id)
  public_key_id       int                NOT NULL  REFERENCES public_keys(id)
  fee                 bigint             NOT NULL
```

Delete the unused table `zkapp_party_balances`.

### Changes to the daemon-to-archive-process RPC

Blocks are sent from the daemon to the archive process via an RPC named `Send_archive_diff`.
There are several kinds of messages that can be sent using that RPC, but the one
we're interested in here is the `Breadcrumb_added` message, which contains a block.

Currently, the per-transaction balances (for user commands and internal commands only, not for zkApps)
are contained in the transaction statuses of transactions contained in a block. The
transactions are contained in the `Staged_ledger_diff.t` part of the block, which
is an instance of the type `External_transition.t`.

We'll still want to send blocks using this RPC, but remove some information, and add some
other information.

The RPC type is unversioned, because the daemon and archive process should come from the
same build. Hence, the changes proposed here don't require adding versioning.

Information to be removed:

- In `Transaction.Status.t`, the `Applied` constructor is applied to a pair consisting of
  `Auxiliary_data.t` containing account creation fees, and `Balance_data.t`, containing
  balances. The fields in those types are all options, because they may not be relevant
  to a particular transaction. Make the constructor unary, applied to a new type
  `Account_creation_fees.t` (see below).

- In `Transaction.Status.t`, the `Failed` constructor is applied to a pair, consisting of
  instances of `Failure.Collection.t` and `Balance_data.t`. Make the constructor unary by
  omitting the second element of the pair.

- Delete the types `Auxiliary_data.t` and `Balance_data.t`.

- For internal commands, the types `Coinbase_balance_data.t` and `Fee_transfer_balance_data.t`
  are used in the archive processor to convert the transaction status balance data to a
  suitable form for those commands. Because per-transaction balances won't be stored, delete
  those types.

Information to be added:

- The new type `Account_creation_fees.t` is a list of records with
  fields for public key, amount, and an account role.  The account role can be
  `Receiver_account`, `Other_party_account`, and so on. This approach
  gives flexibility for the number of such fees, and avoids the use of
  options.

- The `Breadcrumb_added` message can contain a list of accounts
  affected by the block.  Specifically, the list contains a list of
  `int`, `Account.t` pairs (or perhaps a record with two fields),
  where the integer is the ledger index, and the account is its ledger
  state when the block is created. From this list, we can populate the
  new `accounts_accessed` table, and for new accounts, the
  `public_keys` table. The account information is available in the
  function `Archive_lib.Diff.Builder.breadcrumb_added`. The staged
  ledger is contained in the breadcrumb argument, and the block
  contains transactions, so the accounts affected by the block can be
  queried from the staged ledger.

Types to modify:

- The type `Mina_transaction_logic.Transaction_applied.Signed_command_applied`
  contains the field `user_command` with a status, which will contain
  the account creation fees.  Modify the nearby types
  `Fee_transfer_applied` and `Coinbase_applied` to contain those
  fees. We could use `With_status.t` for that purpose, or, since those
  commands always succeed, add new fields to those types to hold the
  account creation fee list.

Removing the information from transaction statuses changes the
structure of blocks, which use a versioned type. While the version
number need not be changed, because the new type will be deployed at a
hard fork, the change affects the serialization of blocks, so a new
`Bin_prot.t` layout will be needed for `External_transition.t`.
(The change in PR #10684, which removes the validation callback from
blocks (serialized as the unit value), would also require a new
layout, independently of the changes here.)

## Changes to the archive processor

The archive processor will need to be updated to add the account information that's
changed for each block. There is no exiting code to add entries to the
`blocks_zkapps_commands` join table, it needs to be added.

Because transaction statuses will contain account creation fee
information, the processor will no longer require the temporizing hack
to calculate that information. The creation fee information will no
longer be written to join tables, instead it will be written to the
new `account_creation_fees` table.

### Changes to archive blocks

For extensional blocks (the type `Extensional.t`), a field `zkapps_cmds` needs to be added,
and the function `add_from_extensional` needs to use that field to populate the tables
`zkapp_commands` and `blocks_zkapp_commands`. Also, there needs to be a field `accounts`
with the account information used to populate the new `accounts_accessed` table.

Likewise, precomputed blocks (type `External_transition.Precomputed_block.t`) will need
an `accounts` field with account information.

These archive block types do not contain version information in their JSON serialization.
Therefore, blocks exported with changed types will require code using the same types, and
old exported blocks will not be importable by new code.

## Changes to the replayer

The replayer currently verifies balances, nonces, and account creation fees after
replaying each transaction. With the proposed changes, it can perform those
verifications after each block.

## Changes to Rosetta

Currently, the `account` endpoint in the Rosetta implementation
makes at least one SQL query to find a balance and a nonce. If the initial
query fails, a fallback query is made using two subqueries: at a given block
height, the balance comes from the most recent transaction (user or
internal command), while the nonce comes from the most recent user
command. With the changes here, a single query will always return both the
balance and nonce, because both items always appear in the `accounts_accessed` table.

We'll still need to distinguish canonical from pending block heights,
and in the latter case, use the Postgresql recursion mechanism to find
a path back to a canonical block.

## Drawbacks
[drawbacks]: #drawbacks

Storing complete account information for each block likely increases
the database storage requirements, even though per-transaction
balances will be removed.

Because balances and nonces are stored per-block, rather than
per-transaction, related bugs may be more difficult to difficult to
rectify, when flagged by the replayer.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

A simpler alternative would be to use the existing `balances` table,
but without the sequence information, rather than storing all the
account information. That would be enough to allow the replayer and
Rosetta to work after zkApps are running on a network.  But that would
limit some possible use cases for the archive data. For example, with
the complete account information, it's possible to construct the
ledger corresponding to any block, without running the replayer.
(We'd still want to the replayer available, to verify ledger hashes, balances,
and nonces in the archive database.)

## Prior art
[prior-art]: #prior-art

The proposal here is an extension of existing mechanisms used to store
and query transaction data in an archive database.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

There are some minor questions posed in the text above. Besides those:

 - The new database schema has information not present in the current
   schema, such as the `accounts_accessed` table.  It won't be possible to
   write a simple migration program, that simply shuffles around
   existing information, if migration is needed. It may be possible to
   do a migration by modifying the replayer, which maintains a ledger,
   to write out account information. Will the archive database at the
   hard fork start empty, or will it contain pre-fork data?
