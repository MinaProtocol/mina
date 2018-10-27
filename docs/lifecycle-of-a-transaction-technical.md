# The Lifecycle of a Transaction (technical)

In Coda, transactions pass through several steps before they are considered verified and complete. This document is meant to walk through what happens to a single transaction as it works it's way through our codebase. For a more high-level simple overview aimed at users who want to understand a little bit about how transactions work check out the [lite lifecycle of a transaction](lifecycle-of-a-transaction-technical-lite.md).

Let's say you want to send a transaction in Coda, assuming you've already made you're account and you have funds.
Your friend gives you her public key -- it's `KEFLx5TOqJNzd6buc+dW3HCjkL57NjnZIaplYJ50DO1uTfogKfwAAAAA`.

Then you invoke the following command:

```bash
$ coda client send-txn -receiver PUBKEY -amount 10 -privkey-path ~/my-private-key
```

<a name="client"></a>
## Coda client -- [client.ml](../src/app/cli/src/client.ml)

[client.ml](../src/app/cli/src/client.ml) defines the CLI command parser for the `coda client` subcommands.
We use [Jane Street](https://github.com/janestreet)'s standard libraries often.
Specifically [Core](https://opensource.janestreet.com/core/) (common datastructures) and [Async](https://opensource.janestreet.com/async/) (asynchronous programming using the composable `Deferred.t` type) are used very often.
On top of most files you'll see some variant of `open Core` and `open Async`.
Here in [client.ml](../src/app/cli/src/client.ml) we see that too. `Async` shadows the `Command` type and lets us declaratively express the details of each command.
If you scroll to the bottom of [client.ml](../src/app/cli/src/client.ml), you'll find we register the `send-txn` command to the function `send_txn`.
Here we describe the flags this action depends on: `receiver` a [public key](#public-key), a fee, an amount, and a path to your [private key](#private-key). These flag param kinds are defined in [client_lib.ml](../src/lib/client_lib.ml).
In the body of `send_txn` we build a transaction and send it over to the [daemon](#daemon).

<a name="transaction"></a>
## Transaction

In [transaction.mli](../src/lib/coda_base/transaction.mli), you'll see a couple important things. (1) we break down transactions into a [transaction payload](#transaction-payload) (the part that needs to be [signed](#signature)) and the rest. and (2) you see the type defined in what will seem to be a strange manner, but is a common pattern in our codebase.

For more see:
* [Parameterized records](code-idiosyncrasies.md#parameterized-records)
* [Ppx deriving](code-idiosyncrasies.md#ppx_deriving)
* [Stable.V1](code-idiosyncrasies.md#stable-v1)
* [Property based tests](code-idiosyncrasies.md#quickcheck-gen)
* [Typesafe Invariants](code-idiosyncrasies.md#typesafe-invariants)
* [Unit Tests](code-idiosyncrasies.md#unit-tests)

Let's dig into the Transaction payload:

<a name="transaction-payload"></a>
## Transaction payload

Check out [transaction_payload.mli](../src/lib/coda_base/transaction_payload.mli). Recall that a payload is the part of the transaction the sender will sign with her private key. We see this is built up out of the receiver [public key](#public-key), [amount](#currency), [fee](#currency), and a [nonce](#account-nonce). Again the payload is SNARKable so it has a `type var`, and other important Snarkable functions (in a future RFC we will put this in a custom [ppx_deriving](#ppx-deriving).

<a name="signature"></a>
## Signatures

(TODO: @ihm can you correct any details I mess up here)

We use [Schnorr signatures](https://en.wikipedia.org/wiki/Schnorr_signature). A [Schnorr signature](https://en.wikipedia.org/wiki/Schnorr_signature) is an element in a [group](https://en.wikipedia.org/wiki/Group_(mathematics). Our group is a point on an [eliptic curve](https://en.wikipedia.org/wiki/Elliptic_curve). So what is a signature? Open up [signature lib's checked.ml](../src/lib/signature_lib/checked.ml) and scroll to `module Signature` within `module type S`. It's a non-zeor point on a curve, aka a pair of two `curve_scalar` values. To sign we give a [private key](#private-key) and a message, we can verify a signature on a message with a [public key](#public-key).

This is the first time we see heavily functored code, so see [functors](code-idiosyncrasies.md#functors) if you're confused. This is also the first time we see custom SNARK circuit logic, see [custom SNARK circuit logic](code-idiosyncrasies.md#snark-checked) for more.

<a name="private-key"></a>
## Private key

In [private_key.ml](../src/lib/signature_lib/private_key.ml) we see a private key is a `Tick.Inner_curve.Scalar.t` or a  scalar on an elliptic curve. Let's break it down more precisely: Because we rely on [recursive zkSNARKs](https://eprint.iacr.org/2014/595) we actually have two elliptic curves called `Tick` and `Tock`. Most of our logic happens within `Tick` (TODO: @ihm expand on this). [Schnorr signatures](#signature) demand we use scalars for our private key.

<a name="public-key"></a>
## Public key

The public key corresponding to a [private key](#private-key) `p` is just $one^p$ in other words $one*one*one ...{p times}... one$. We can see this in [public_key.ml](../src/lib/signature_lib/public_key.ml). Remember group elements are non-zero curve points which is why we also `include Non_zero_curve_point`

Public keys can also be compressed -- see [public_key.mli](../src/lib/signature_lib/public_key.mli). A point on an elliptic curve can unambiguously be represented by a single scalar field element and a boolean. This is the representation we use into the [transaction payload](#transaction-payload) because it's more efficient inside of SNARK circuits.

<a name="currency"></a>
## Currency

In [currency.mli](../src/lib/currency/currency.mli), we define [nominal types](https://en.wikipedia.org/wiki/Nominal_type_system) for fee, amount, and balance that handles overflow and underflow properly. Everything is backed by 64bit unsigned integers for now. Notice, that we again include SNARK circuit operations under the [Checked](#snark-checked) submodules within each of the types.

<a name="account"></a>
## Account

Transactions are can be applied successfully only if certain properties hold of the account of the sender (and the receiver's balance doesn't overflow).

Checkout [account.ml](../src/lib/coda_base/account.ml), an account is a record with a [public key](#public-key) (the owner of the account), a [balance](#currency), a [nonce](#account-nonce), and a [receipt chain hash](#receipt-chain-hash).

A transaction is valid if:

1. The signature is valid w.r.t. the public key of the sender
2. The sender has enough balance to pay out the fee and the amount
3. The reciever has enough room for the amount s.t. there won't be an overflow
4. The [account nonce](#account-nonce) matches the nonce inside the transaction.

When we apply a transaction we also cons it onto the [receipt chain](#receipt-chain-hash), and increment the account nonce.

Fees are handled out-of-band see the [fee excess system](#fee-excess).

This is encoded inside the SNARK in [transaction_snark.ml](../src/lib/transaction_snark/transaction_snark.ml), specifically the `apply_tagged_transaction` function, although you'll need to look at how the bool flags are set in the `is_normal` case.

It's captured outside the SNARK here: (TODO: where is this? Ledger_builder somewhere?)

<a name="account-nonce"></a>
### Account Nonce

The [account_nonce.mli](../src/lib/coda_numbers/account_nonce.mli) is just a [nominal type](https://en.wikipedia.org/wiki/Nominal_type_system) around a natural number. This is used for protection against double-application of transactions.
The account nonce is incremented in the sender's the account whenever a transaction is applied.

<a name="receipt-chain-hash"></a>
### Receipt Chain Hash

The [receipt.mli](../src/lib/coda_base/receipt.mli) chain hash is the top hash of a [merkle list](#merkle-list) of transaction payloads. This is used to prove that you actually sent a transaction to someone. Since Coda doesn't keep transaction history, this is how you can prove to someone that your transaction went through.

How does it work?

<a name="merkle-list"></a>
A merkle list is like a [merkle tree](https://en.wikipedia.org/wiki/Merkle_tree) but with one branch. As long as you keep your merkle list hashes, you can prove that any individual piece of data was part of the list if you know for sure what the top hash is.

If it's important to prove your transaction went through, you ask the receiver to start recording receipt chain hashs, and hand your transaction payload over to the receiver. He can then check the top hash of their receipt chain to see if it includes your payload.

## Take a break!

We've fully described all the components of a `Transaction.t`. Congrats on making it this far!

After a break, we'll be ready to dive into the daemon code.

<a name="daemon"></a>
## Daemon

The coda daemon is defined inline in [coda.ml](../src/app/cli/src/coda.ml). Search for the `daemon` function to see the CLI flags we use there. The daemon is optionally auto-started by the client if it doesn't already exist. We get configuration from a JSON configuration file (try first from `-f`, then from `$XDG_CONFIG_DIR/coda/daemon.json`, then from `/etc/coda/daemon.json`). We do a lot of setup here which leads up to invoking `Coda_main.Coda.Make` and then `Run`ing it. The details of those are described below.

When we have the `Run` modulle, we can make an instance of the coda daemon at the value level, and set up any background processes and services.

<a name="main"></a>
## Main

By the time you're reading this, hopefully we've tamed the beast that is [coda_main.ml](../src/app/cli/src/coda_main.ml). Here we wire the system together at the module level. What does this mean? We instantiate all the functors for the different subcomponents of the daemon. Eventually we create something that conforms to `Main_intf` (in this same file).

<a name="run"></a>
### Run functor

At the bottom of [coda_main.ml](../src/app/cli/src/coda_main.ml), we define a `Run` functor that finally has the other side of the `rpc` call that the client makes to `send_txn`. Run contains the server-side implementations of all the RPC calls the client makes. It also is responsible for logic of setting up any RPC/webservers servers and background processes.

Let's assume we have an instance of `Run.t` already created, and we'll circle back later.

<a name="client-rpc"></a>
### Client_rpc

In [client_lib.ml](../src/lib/client_lib/client_lib.ml), we define the concrete RPC calls that the client uses to communicate to the daemon. We use [Async](https://opensource.janestreet.com/async/)'s RPC library for this. `Send_transactions` defined the RPC call we use to send the transaction: the query type is the input -- the transactions we want to send -- and the response is the output -- in this case `unit`, because we don't get any meaningful feedback other than "the transaction has been enqueued" on success.

### Schedule transaction into Transaction pool

Back in [coda_main.ml](../src/app/cli/src/coda_main.ml), we invoke `send_txn` in [Run](#run), that delegates to `schedule_transaction` -- here we enqueue the transaction into the [Transaction Pool](#transaction-pool).

<a name="coda-lib"></a>
## Coda_lib

To create a `Run` instance we'll need to go to [coda_lib.ml](../src/lib/coda_lib/coda_lib.ml) where we wire all subsystems together at the value level. This is in contrast to [coda_main.ml](#main) where we wire all the subsystems together at the module level.

It's here where we can trace the path of the transaction from the transaction pool forwards. Let's sketch that out before diving deeper into each of the subsystems:

1. The [transaction pool](#transaction-pool) broadcasts diffs from the transaction pool through to the [network](#network)
2. The [proposer](#proposer) reads transactions from the transaction pool when it's time to make a transition from one blockchain state to another, those transactions are part of a diff to update a [ledger builder](#ledger-builder) which is committed to inside the new blockchain state. [External transitions](#external-transition) are emitted.
3. The [network](#network) and the [proposer](#proposer) feed [external transitions](#external-transition) containing information on how to update a [ledger builder](#ledger-builder) with the new transaction buffered to the [ledger builder controller](#ledger-builder-controller)
4. The [ledger builder controller](#ledger-builder-controller) figures out where this [external transition](#external-transition) fits in it's tree of possible forks. If this happens to extend our "best" path (the state upon which we will propose later) then we do an expensive materialization step to create a [tip](#tip) holding the new [ledger builder](#ledger-builder) and emit this strongest tip over the [network](#network). Healthy clients only forward tips they locally think are the strongest.

<a name="transaction-pool"></a>
## Transaction Pool

Open up [transaction_pool.ml](../src/lib/transaction_poll/transaction_pool.ml)... TODO

<a name="network"></a>
## Network

TODO

<a name="proposer"></a>
## Proposer

TODO

<a name="external-transition"></a>
## External Transition

TODO

<a name="ledger-builder-controller"></a>
## Ledger-builder-controller

TODO

<a name="ledger-builder"></a>
## Ledger-builder

TODO

## Ledger

TODO


