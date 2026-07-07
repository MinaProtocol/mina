# Pickles - a modular typed inductive proof system

Pickles is a framework that provides an interface for writing SNARK circuits as
inductive rules, backed by a co-recursive kimchi verifier operating over the
Pallas and Vesta curves.

It is currently implemented to work with the polynomial IOP
[PLONK](https://eprint.iacr.org/2019/953.pdf) and the recursion layer
[Halo](https://eprint.iacr.org/2019/1021.pdf), generally called
[Halo2](https://electriccoin.co/blog/explaining-halo-2/).
It also provides an abstraction to deal with lookup arguments and custom gates compatible with PLONK.

Pickles aims to be modular using the OCaml module system. Ideally, an inductive proof
system can be parametrized by any finite field and 2-cycle of curves (called
`Tick` and `Tock`). However, at the moment, it is hardcoded to be used with
Pasta and Vesta curves. The code refers to the algebraic parameters as `Impls`
and are passed to generic functions as a first class module.

A particularity of Pickles is to use the power of the OCaml type system to
encode runtime invariants like vector sizes, heterogeneous lists and others at
the type level to avoid constructing some statements that might be wrong at
compile time. Some encoded theories can be found in
[`Pickles_types`](../pickles_types/).
Some types are parametrized by type-level defined naturals.

## Coding guidelines

Functions related to computations are parametrized by at least two types,
suffixed respectively with `var` and `val`, which represent `in circuit` values
and `out circuit` values. The type `[('var, 'val) t]` describes a mapping from
the OCaml type `['val]` to a type representing the value using PlonK variables
(`['var]`).
Each in-circuit encoded value has a corresponding `'a Typ.t` value, which
carries the in-circuit values, out-circuit values and the related circuit
constraints.
A nested module `Constant` must be defined to encode the out-circuit values
and operations.
The reader can find more information in [Snarky
documentation](https://github.com/o1-labs/snarky/blob/master/src/base/snark_intf.ml#L140-L153).

When a type is supposed to encode a list at the type level, a `s` is added to
its name.

## Files structures

This is a non-exhaustive classification of the files structure related to the
library. Refer to the file header for a content description:

- Fiat Shamir (FS) transformation:
  - [`Make_sponge`](make_sponge.mli)
  - [`Opt_sponge`](opt_sponge.mli)
  - [`Ro`](ro.mli)
  - [`Scalar_challenge`](scalar_challenge.mli)
  - [`Sponge_inputs`](sponge_inputs.mli)
  - [`Tick_field_sponge`](tick_field_sponge.mli)
  - [`Tock_field_sponge`](tock_field_sponge.mli)
- Polynomial commitment scheme:
  - [`Commitment_length`](commitment_length.mli)
  - [`Evaluation_length`](evaluation_length.mli)
- Main protocol:
  - [`Impls`](impls.mli)
- Optimisations:
  - [`Endo`](endo.mli)
- Miscellaneous:
  - [`Cache`](cache.mli)
  - [`Cache_handle`](cache_handle.mli)
  - [`Common`](common.mli)
  - [`Dirty`](dirty.mli)
  - [`Import`](import.mli)
- Inductive proof system:
  - [`Compile`](compile.mli)
  - [`Dummy`](dummy.mli)
  - [`Fix_domains`](fix_domains.mli)
  - [`Full_signature`](full_signature.mli)
  - [`Inductive_rule`](inductive_rule.mli)
  - [`Per_proof_witness`](per_proof_witness.mli)
  - [`Pickles`](pickles.mli)
  - [`Pickles_intf`](pickles_intf.mli)
  - [`Proof`](proof.mli)
  - [`Reduced_messages_for_next_proof_over_same_field`](reduced_messages_for_next_proof_over_same_field.mli)
  - [`Requests`](requests.mli)
  - [`Side_loaded_verification_key`](side_loaded_verification_key.mli)
  - [`Step`](step.mli)
  - [`Step_branch_data`](step_branch_data.mli)
  - [`Step_main`](step_main.mli)
  - [`Step_verifier`](step_verifier.mli)
  - [`Tag`](tag.mli)
- Algebraic objects:
  - [`Plonk_curve_ops`](plonk_curve_ops.mli)

## Resources

Some public videos you can find on YouTube describing the intial idea behind
Pickles. It might be outdated if the IOP is changed.
- [zkStudyClub: Izaak Meckler o1Labs - Pickles ](https://www.youtube.com/watch?v=kmCXdjv5oP0)
- [ZK-GLOBAL 0x05 - Izaak Meckler - Meet Pickles SNARK ](https://www.youtube.com/watch?v=nOnGOxyh7jY)
