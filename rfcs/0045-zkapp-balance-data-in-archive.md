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

Rename the existing `zkapp_account` to `zkapp_precondition_accounts`, and in the
table `zkapp_predicate`, rename `account_id` to `precondition_account_id`, and
modify the foreign key reference accordingly.

Add new table `zkapp_accounts`:
```
  app_state_id         int     NOT NULL  REFERENCES zkapp_states(id)
  verification_key_id  int     NOT NULL  REFERENCES zkapp_verification_keys(id)
  zkapp_version        bigint  NOT NULL
  sequence_state_id    int     NOT NULL  REFERENCES zkapp_sequence_states(id)
  last_sequence_slot   bigint  NOT NULL
  proved_state         bool    NOT NULL
  zkapp_uri_id         int     NOT NULL  REFERENCES zkapp_uris(id)
```

The new table `zkapp_uris` is:
```
  id                 serial  PRIMARY_KEY
  uri                text    NOT NULL UNIQUE
```

The table `balances` is replaced by a new table `accounts_accessed`, with columns:
```
  ledger_index            int     NOT NULL
  block_id                int     NOT NULL  REFERENCES blocks(id)
  account_id              int     NOT NULL  REFERENCES account_ids(id)
  token_symbol            text    NOT NULL
  balance                 bigint  NOT NULL
  nonce                   bigint  NOT NULL
  receipt_chain_hash      text    NOT NULL
  delegate                int               REFERENCES public_keys(id)
  voting_for              text    NOT NULL
  timing                  int               REFERENCES timing_info(id)
  permissions             int     NOT NULL  REFERENCES zkapp_permissions(id)
  zkapp                   int               REFERENCES zkapp_accounts(id)
```

In order to include the genesis ledger accounts in this table, we may
need a separate app to populate it. Alternatively, we could use an app
to dump the SQL needed to populate the table, and keep that SQL in the
Mina repository.

The new table `account_ids`:
```
  id                 serial  PRIMARY_KEY
  public_key_id      int     NOT NULL     REFERENCES public_keys(id)
  token              text    NOT NULL
  token_owner        int                  REFERENCES account_ids(id)
```
A `NULL` entry for the `token_owner` indicates that this account
owns the token.

The new table `zkapp_sequence_states` has the same definition as the
existing `zkapp_states`; it represents a vector of field elements.  We
probably don't want to commingle sequence states with app states in a
single table, because they contain differing numbers of elements.

Add a new table `accounts_created`:
```
  block_id            int                NOT NULL  REFERENCES blocks(id)
  account_id_id       int                NOT NULL  REFERENCES account_ids(id)
  creation_fee        bigint             NOT NULL
```

There should be an entry in this table for every account, other than
those in the genesis ledger.

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
  balances. Make the constructor nullary.

- In `Transaction.Status.t`, the `Failed` constructor is applied to a pair, consisting of
  instances of `Failure.Collection.t` and `Balance_data.t`. Make the constructor unary by
  omitting the second element of the pair.

- Delete the types `Auxiliary_data.t` and `Balance_data.t`.

- For internal commands, the types `Coinbase_balance_data.t` and `Fee_transfer_balance_data.t`
  are used in the archive processor to convert the transaction status balance data to a
  suitable form for those commands. Because per-transaction balances won't be stored, delete
  those types.

Information to be added:

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

- The same message can contain a list of records representing account
  creation fees burned for the block, with fields for the public key
  of the created account and the fee amount. That information can be
  extracted from the scan state of the staged ledger in the breadcrumb.

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
changed for each block. There is no existing code to add entries to the
`blocks_zkapps_commands` join table, it needs to be added.

Because the `Breadcrumb_added` message will contain account creation fee
information, the processor will no longer require the temporizing hack
to calculate that information. The creation fee information will no
longer be written to join tables, instead it will be written to the
new `accounts_created` table.

### Changes to archive blocks

For extensional blocks (the type `Extensional.t`), a field `zkapps_cmds` needs to be added,
and the function `add_from_extensional` needs to use that field to populate the tables
`zkapp_commands` and `blocks_zkapp_commands`. Also, there needs to be a field `accounts`
with the account information used to populate the new `accounts_accessed` table.

Likewise, precomputed blocks (type `External_transition.Precomputed_block.t`) will need
an `accounts` field with account information.

For both kinds of blocks, we'll also need a list of account creation fees.

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

Placing the account creation fees in a separate table will require changes
to the SQL queries for the `block` endpoint, which currently rely on
those fees' presence in the `blocks_internal_commands` and `blocks_user_commands`
tables.

There is no current support for zkApps in the Rosetta code, that will need
to be added.

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
   to write out account information. Is there a better way?
