## Summary
[summary]: #summary

A GraphQL api design to allow the wallet app (and future similar applications) to communicate with a full node.

## Motivation

[motivation]: #motivation

Currently, the main use case for this is to support the development of a wallet application which can
communicate with a full node which is running either remotely or locally in another process.

Related Goals:
- Make app development using the api relatively easy and fast.
- Make it easier for people to communicate programmatically with a full node.
- Consumers of the api should not be required to write in a specific language.
- Eventually be able to rewrite the command-line client to use the same api.

## Detailed design

[detailed-design]: #detailed-design

This design is heavily influenced by which data is stored on the node and which is intended to be stored by the client.
Most importantly, we assume the node knows about some private keys which it associates to public keys for which it will
try to store related transactions indefinitely (where "related" means being sent to or from the public key). We may also
need to store information about blocks that these keys have created.
We will likely want to at least optionally cache the history of the blocks/payments on the client side as well,
just to avoid needing to query it all every time (though we could also paginate the )

Note: There are several custom scalars defined at the top for readability. These will be `String`s in the final implementation due to the complications involved in the encoding of custom scalars not being expressed in the schema and needing to be implemented symmetrically on the client and server.

```graphql
scalar Date
scalar PublicKey
scalar PrivateKey
scalar Int64

enum ConsensusStatus {
  SUBMITTED
  INCLUDED
  FINALIZED
  SNARKED
  FAILED
}

type ConsensusState {
  status: ConsensusStatus!
  estimatedPercentConfirmed: Float!
}

type Payment {
  nonce: Int!,
  submittedAt: Date!
  includedAt: Date
  from: PublicKey! 
  to: PublicKey!
  amount: Int64!
  fee: Int!,
  memo: String
}

type PaymentUpdate {
  payment: Payment
  consensus: ConsensusState!
}

enum SyncStatus {
  ERROR
  BOOTSTRAP # Resyncing
  CATCHUP # Synced but a little out
  STALE # You haven't seen any activity recently
  SYNCED
}

type SyncUpdate {
  status: SyncStatus!
  estimatedPercentSynced: Float!
  description: String
}

type SnarkWorker {
  key: PublicKey!
  fee: Int!
}

type SnarkFee {
  snarkCreator: PublicKey!
  fee: Int!
}

type SnarkFeeUpdate {
  fee: SnarkFee
  consensus: ConsensusState!
}

type Block {
  coinbase: Int!
  creator: PublicKey!
  payments: [Payment]!
  snarkFees: [SnarkFee]!
}

type BlockUpdate {
  block: Block!
  consensus: ConsensusState!
}

type Wallet {
  publicKey: PublicKey!
  privateKey: PrivateKey!
  balance(consensus: ConsensusStatus): Int64!
}

type NodeStatus {
  network: String
}

## Input types

input AddWalletInput {
  public: PublicKey
  private: PrivateKey
}

input DeleteWalletInput {
  public: PublicKey
}

input AddPaymentReceiptInput {
  receipt: String
}

input SetNetworkInput {
  address: String
}

input SetSnarkWorkerInput {
  worker: PublicKey!
  fee: Int!
}

input CreatePaymentInput {
  from: PublicKey!,
  to: PublicKey!,
  amount: Int64!,
  fee: Int!,
  memo: String
}

input PaymentFilterInput {
  toOrFrom: PublicKey,
}

input BlockFilterInput {
  creator: PublicKey,
}

## Payload types

type CreatePaymentPayload {
  payment: Payment
}

type SetSnarkWorkerPayload {
  worker: SnarkWorker
}

type SetNetworkPayload {
  address: String
}

type AddPaymentReceiptPayload {
  payment: Payment
}

type AddWalletPayload {
  publicKey: PublicKey
}

type DeleteWalletPayload {
  publicKey: PublicKey
}

# Pagination types

type PageInfo {
  hasPreviousPage: Boolean!
  hasNextPage: Boolean!
}

type PaymentEdge {
  cursor: String
  node: PaymentUpdate
}

type PaymentConnection {
  edges: [PaymentEdge]
  nodes: [PaymentUpdate]
  pageInfo: PageInfo!
  totalCount: Int
}

type BlockEdge {
  cursor: String
  node: BlockUpdate
}

type BlockConnection {
  edges: [BlockEdge]
  nodes: [BlockUpdate]
  pageInfo: PageInfo!
  totalCount: Int
}

type Query {
  # List of wallets currently tracked by the node
  wallets: [Wallet]!
  
  # Gets balance of key at a certain consensus state
  # Note: `consensus` is optional as we will likely decide one
  # state to be the "real" balance (probably FINALIZED)
  balance(publicKey: PublicKey!, consensus: ConsensusStatus): Int64!
  
  payments(
    filter: PaymentFilterInput,
    first: Int,
    after: String,
    last: Int,
    before: String): PaymentConnection
  
  blocks(
    filter: BlockFilterInput,
    first: Int,
    after: String,
    last: Int,
    before: String): BlockConnection
  
  # Null if node isn't performing snark work
  currentSnarkWorker: SnarkWorker

  # Current sync status of the node
  syncState: SyncUpdate!
  
  # version of the node (commit hash or version #)
  version: String!
  
  # Network that the node is connected to
  network: String
  status: NodeStatus
}

type Mutation {
  createPayment(input: CreatePaymentInput!): CreatePaymentPayload
  
  setSnarkWorker(input: SetSnarkWorkerInput!): SetSnarkWorkerPayload
  
  # Configure which network your node is connected to
  setNetwork(input: SetNetworkInput!): SetNetworkPayload
  
  # Adds transaction to the node (note: Not sure how we want to represent this yet)
  addPaymentReceipt(input: AddPaymentReceiptInput!): AddPaymentReceiptPayload
  
  # Tell server to track a private key and all associated transactions
  addWallet(input: AddWalletInput!): AddWalletPayload
  
  # Deletes private key associated with `key` and all related information
  deleteWallet(input: DeleteWalletInput!): DeleteWalletPayload
}

type Subscription {
  # Subscribe to sync status of the node
  newSyncUpdate: SyncUpdate!
  
  # Subscribe to payments for which this key is the sender or receiver
  newPaymentUpdate(filterBySenderOrReceiver: PublicKey!): PaymentUpdate!
  
  # Subscribe all blocks created by `key`
  newBlock(key: PublicKey): BlockUpdate!
  
  # Subscribe to fees earned by key
  newSnarkFee(key: PublicKey): SnarkFee!
}

schema {
  query: Query
  mutation: Mutation
  subscription: Subscription
}
```

Staking is a little bit tricky because of the different states involved. These queries
are pulled out for clarity, but you can imagine them being simply added to the above schema.

You can either perform staking yourself, or delegate your stake to another public key
- Changing your delegation status is a transaction,
  which will experience the same consensus flow as other transactions,
  with the addition of having to wait an additional epoch (?) for it to
  actually come into effect.
- Doing staking work yourself doesn't involve a transaction unless you need to
  cancel an existing delegation first.

This means that at any given moment, there could be a number of pending delegation
transactions all awaiting consensus.

``` graphql
type Delegation {
  nonce: Int!,
  submittedAt: Date!
  includedAt: Date
  from: PublicKey!
  to: PublicKey!
  fee: Int!,
  memo: String
}

type DelegationUpdate {
  status: Delegation!

  # We may have reached consensus but still be waiting for the correct epoch
  active: Boolean!

  consensus: ConsensusState!
}

type Query {
  stakingStatus(key: PublicKey): Boolean!
  
  # Most recent status for each relevant delegation transaction
  delegationStatus(key: PublicKey!): [DelegationUpdate]!
}

type Subscription {
  newDelegationUpdate(publicKey: PublicKey): DelegationUpdate!
}

input SetStakingInput {
  on: Boolean
}

input SetDelegationInput {
  from: PublicKey!
  to: PublicKey!
  fee: Int!
  memo: String
}

type SetStakingPayload {
  on: Boolean
}

type SetDelegationPayload {
  delegation: Delegation
}

type Mutation {
  setStaking(input: SetStakingInput!): SetStakingPayload
  setDelegation(input: SetDelegationInput!): SetDelegationPayload
}
```

## Drawbacks
[drawbacks]: #drawbacks

We could potentially make a wallet by making queries though the existing command-line client, which might involve less work.
This brings in a dependency on graphql and reimplements/replaces some of the work done for the RPC interface.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- The payment and block history for the wallets could be only stored on the client. This would
  make the node only be responsible for storing the private keys of the wallets. This results in a somewhat
  simpler/lighter full node, with the obvious cost that whenever you close your wallet app, you're missing
  any transactions that might be happening, which isn't great for the wallet experience.
- The wallet could be responsible for storing the private keys as well, but then the node would have to ask the wallet
  for them whenever it needed them for snarking etc. Probably not what we want.

Why GraphQL?
- Defines a typed interface for communication between client and server.
- Interface is explorable/discoverable with great existing tools, making development easier.
- Strong OCaml/Reason support without requiring that consumers of the api be written in a specific language.

Alternatives to GraphQL:
- Falcor (or similar)
- Completely custom alternative.

We considered a custom alternative as a single wallet app connected to a single node instance isn't a very standard
setup for graphql app, which we saw as more associated with public web apis with many consumers. However, all the work
in this case would obviously have to be from scratch, representing potentially significant time investment to get stable
for questionable gain. Client libraries would also have to be written for any languages that wanted to interface, whereas
GraphQL already supports many and seems to have pretty good community buy-in.

## Prior art
[prior-art]: #prior-art

- RPC interface that the commandline client uses: This has inspired the graphql api though in some cases we have tried to
simplify the interface and avoid any binary serialization that might rely on having ocaml at both ends.
- REST server in the node: A simple interface that uses rest to deliver some status pages.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- Should we be able to query the node for the amount of the balance that corresponds to unknown/missed transactions?
  We could also calculate this client-side by summing up all the payments/fees/coinbases and comparing to the balance
  queried from the node.
- Several apis involve objects that get incrementally updated during consensus
  It's important that we have a reliable way to associate updates with their
  corresponding objects in memory. We don't have a concept of IDs for most of these
  objects, but if we could create one by hashing together enough properties of the 
  objects, it might help with this and avoid accidents comparing fields in an insufficient way.
- Authentication
- Potentially out of scope: How will this evolve and be used in the future, when most wallets will just run a light node locally?
