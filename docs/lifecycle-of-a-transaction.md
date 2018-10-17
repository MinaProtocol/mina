# The Lifecycle of a Transaction

Intro-paragraph, you want to send a transaction in Coda, etc etc

Your friend gives you her public key -- it's `KEFLx5TOqJNzd6buc+dW3HCjkL57NjnZIaplYJ50DO1uTfogKfwAAAAA`

Invoke:

```bash
$ coda client send-txn -receiver PUBKEY -amount 10 -privkey ~/my-private-key
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

In [transaction.mli](../src/lib/coda_base/transaction.mli), you'll see a couple important things. (1) we break down transactions into a [transaction payload](#transaction-payload) (the part that needs to be [signed](#signature)) and the rest. and (2) you see the type defined in what will seem to be a strange manner, but is a common pattern in our codebase. I'd like to break it down:

(TODO: Should we move these asides into an appendix?)

### Parameterized records

```ocaml
type ('payload, 'pk, 'signature) t_ =
  {payload: 'payload; sender: 'pk; signature: 'signature}
[@@deriving eq, sexp, hash]

type t = (Payload.t, Public_key.t, Signature.t) t_
[@@deriving eq, sexp, hash]

(* ... *)

type var = (Payload.var, Public_key.var, Signature.var) t_
```

We're defining a base type `t_` with type variables for all types of record fields. Then we define the record using these type variables. Finally, we instantiate the record with `type t`, this is the OCaml type. And also `type var` this is the type of this value in a SNARK circuit. We'll cover this more later. Whenever we want something to be programmable from within a SNARK circuit we define it in this manner so we can reuse the record definition across both types.

There is some talk of moving to OCaml objects to do this sort of thing so we don't need to deal with positional arguments. Perhaps I (@bkase) will write up an RFC for that at some point.

<a name="ppx_deriving"></a>
### Ppx_deriving

This is the first time we've seen a [ppx_deriving](https://github.com/ocaml-ppx/ppx_deriving) macro. Here we use some deriving fields from [ppx_jane](https://github.com/janestreet/ppx_jane) as well.

I want to point out one other pattern that appears often in our codebase:

### Stable.V1

```ocaml
module Stable : sig
  module V1 : sig
    type t = (* ... *)
    [@@deriving bin_io, (*...*)]
  end
end
```

Whenever a type is serializable, it's important for us to maintain backwards compatibility once we have a stable release. Ideally, we wouldn't define `bin_io` on any types outside of `Stable.V1`.

<a name="quickcheck-gen"></a>
### Property based tests

[Core](https://opensource.janestreet.com/core/) has an implementation of [QuickCheck](https://blog.janestreet.com/quickcheck-for-core/) that we use whenever we can in unit tests. Here we see we have a `Quickcheck.Generator.t` for transactions.

```ocaml
(* Generate a single transaction between
 * $a, b \in keys$
 * for fee $\in [0,max_fee]$
 * and an amount $\in [1,max_amount]$
 *)

val gen :
     keys:Signature_keypair.t array
  -> max_amount:int
  -> max_fee:int
  -> t Quickcheck.Generator.t
```

### Typesafe invariants (help with naming this section)

Often times in Coda, we need to perform very important checks on certain pieces of data.
For example, we need to confirm that the signature is valid on a transaction we recieve over the network.
Such checks can be expensive, so we only want to do them once, but we want to remember that we've done them.

```ocaml
module With_valid_signature : sig
  type nonrec t = private t [@@deriving sexp, eq, bin_io]

  (*...*)
end

val check : t -> With_valid_signature.t option
```

Here we define `With_valid_signature` (usage will be `Transaction.With_valid_signature.t`) using `type nonrec t = private t` to allow upcasting to a `Transaction.t`, but prevent downcasting. The _only_ way to turn a `Transaction.t` into a `Transaction.With_valid_signature.t` is to `check` it. Now the compiler will catch our mistakes.

<a name="unit-test"></a>
### Unit tests

Last general thing before we move on -- we use [ppx_inline_test](https://github.com/janestreet/ppx_inline_test) for unit testing. Of course whenever we can, we combine that with `QuickCheck`. In [transaction.ml](../src/lib/coda_base/transaction.mli), we have property that asserts the signatures we create are valid.

Let's dig into the Transaction payload:

<a name="transaction-payload"></a>
## Transaction payload

Check out [transaction_payload.mli](../src/lib/coda_base/transaction_payload.mli). Recall that a payload is the part of the transaction the sender will sign with her private key. We see this is built up out of the receiver [public key](#public-key), [amount](#currency), [fee](#currency), and a [nonce](#account-nonce). Again the payload is SNARKable so it has a `type var`, and other important Snarkable functions (in a future RFC we will put this in a custom [ppx_deriving](#ppx-deriving).

<a name="signature"></a>
## Signatures

(TODO: @ihm can you correct any details I mess up here)

We use [Schnorr signatures](https://en.wikipedia.org/wiki/Schnorr_signature). A [Schnorr signature](https://en.wikipedia.org/wiki/Schnorr_signature) is an element in a [group](https://en.wikipedia.org/wiki/Group_(mathematics). Our group is a point on an [eliptic curve](https://en.wikipedia.org/wiki/Elliptic_curve). So what is a signature? Open up [signature lib's checked.ml](../src/lib/signature_lib/checked.ml) and scroll to `module Signature` within `module type S`. It's a point on a curve, aka a pair of two `curve_scalar` values. To sign we give a [private key](#private-key) and a message, we can verify a signature on a message with a [public key](#public-key).

This is the first time we see heavily functored code so I want to dig into this:

### Functors

We are in the process of migrating to using module signature equalities -- see [the style guidelines](style_guidelines.md#functor-signature-equalities) and [the rfc for rationale](../rfcs/0004-style-guidelines.md), but we still have a lot of code using type substitutions (`with type foo := bar`).

Here's an example of a definition using type substitutions. First we define the resulting module type of the functor, keeping all types we'll be functoring in abstract.

```ocaml
module type S = sig
  type boolean_var
  type curve
  type curve_var
  (*...*)
end
```

Then we define the functor:

```ocaml
module Schnorr
  (Impl : Snark_intf.S)
  (Curve : sig (*...*) end)
  (Message : Message_intf
    with type boolean_var := Impl.Boolean.var
    (*...*))
: S with type boolean_var := Impl.Boolean.var
     and type curve := Curve.t
     and type curve_var := Curve.var
     (*...*)
= struct
  (* here we implement the signature described in S *)
end
```

<a name="snark-checked"></a>
### Custom SNARK circuit logic

This is also the first time we see custom

<a name="public-key"></a>
## Public key

<a name="private-key"></a>
## Private key

<a name="currency"></a>
## Currency

<a name="account"></a>
## Account

<a name="daemon"></a>
## Daemon

## Main

### Client_rpc

### Run functor

### Instantiating the world

### Schedule transaction into Transaction pool

## Coda_lib

Connects to network and proposer

## Network

## Proposer

## Snarks

## Ledger-builder-controller

## Ledger-builder

## Ledger


