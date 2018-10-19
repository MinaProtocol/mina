# Code Idiosyncrasies

We use OCaml, and a particular style of OCaml. Many of these patterns are not captured in our style guide (though maybe they should be).

<a name="parameterized-records"></a>
## Parameterized records

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

```ocaml
type t = int [@@deriving sexp, eq]
```

This is the first time we've seen a macro. Here we use `sexp` from [ppx_jane](https://github.com/janestreet/ppx_jane) and `eq` from [ppx_deriving](https://github.com/ocaml-ppx/ppx_deriving).


<a name="stable-v1"></a>
### Stable.V1

```ocaml
module Stable : sig
  module V1 : sig
    type t = (* ... *)
    [@@deriving bin_io, (*...*)]
  end
end
```

Whenever a type is serializable, it's important for us to maintain backwards compatibility once we have a stable release. Ideally, we wouldn't define `bin_io` on any types outside of `Stable.V1`. When we change the structure of the datatype we would create a `V2` under `Stable`.

<a name="quickcheck-gen"></a>
### Property based tests

[Core](https://opensource.janestreet.com/core/) has an implementation of [QuickCheck](https://blog.janestreet.com/quickcheck-for-core/) that we use whenever we can in unit tests. Here is an example signature for a `Quickcheck.Generator.t` of transactions.

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

<a name="typesafe-invariants"></a>
### Typesafe invariants (help with naming this section)

Often times in Coda, we need to perform very important checks on certain pieces of data.
For example, we need to confirm that the signature is valid on a transaction we recieve over the network.
Such checks can be expensive, so we only want to do them once, but we want to remember that we've done them.

```ocaml
(* inside transaction.mli *)

module With_valid_signature : sig
  type nonrec t = private t [@@deriving sexp, eq, bin_io]

  (*...*)
end

val check : t -> With_valid_signature.t option
```

Here we define `With_valid_signature` (usage will be `Transaction.With_valid_signature.t`) using `type nonrec t = private t` to allow upcasting to a `Transaction.t`, but prevent downcasting. The _only_ way to turn a `Transaction.t` into a `Transaction.With_valid_signature.t` is to `check` it. Now the compiler will catch our mistakes.

<a name="unit-tests"></a>
### Unit Tests

We use [ppx_inline_test](https://github.com/janestreet/ppx_inline_test) for unit testing. Of course whenever we can, we combine that with `QuickCheck`.

```ocaml
let%test_unit =
  Quickcheck.test ~sexp:[%sexp_of: Int.t] Int.gen
    ~f:(fun x -> assert (Int.equal (f_inv (f x)) x))
```

<a name="functors"></a>
### Functors

We are in the process of migrating to using module signature equalities -- see [the style guidelines](style_guidelines.md#functor-signature-equalities) and [the rfc for rationale](../rfcs/0004-style-guidelines.md), but we still have a lot of code using type substitutions (`with type foo := bar`).

In [signature_lib/checked.ml](../src/lib/signature_lib/checked.ml) we have an example of a definition using type substitutions. First we define the resulting module type of the functor, keeping all types we'll be functoring in abstract.

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

This is also the first time we see custom SNARK circuit logic. A pattern we've been using is to scope all operations that you'd want to run inside a SNARK under a submodule `module Checked`.

For example, inside [sgn.mli](../src/lib/sgn/sgn.mli) we see:

```ocaml
(* ... *)
val negate : t -> t

module Checked : sig
  val negate : var -> var
end
```

`negate` is the version of the function that runs in OCaml, and `Checked.negate` is the one that runs inside of a SNARK circuit.

