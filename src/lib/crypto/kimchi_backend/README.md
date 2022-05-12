# Kimchi Backend

This package contains the glue between:

* [snarky](https://github.com/o1-labs/snarkyjs), a library to write circuits.
* [pickles](https://github.com/MinaProtocol/mina/tree/develop/src/lib/pickles), the recursive layer of the protocol.
* and [kimchi_bindings](../kimchi_bindings), the OCaml bindings to our proof system [kimchi](https://www.github.com/o1-labs/proof-systems) written in Rust.

As snarky expects specific "backend" modules, zexe-backend mostly contains functors that converts the ocaml-bindings found in [kimchi_bindings](../kimchi_bindings) into what snarky expects.

There are three things to convert here:

1. fundamental (or non-generic) low-level types: arkwork types (BigInteger256) AND mina-curves types (Vesta, Pallas, Fp, Fq).
2. common (or generic) low-level types: polynomial commitments (Poly_comm), gates (Gates), etc. that are instantiated separately for the two curves (Fq_poly_comm, Fp_poly_comm).
3. high-level types that describe the constraint system, the indexes, etc. that are instantiated separately for the two curves as well.

For the most part, you can find these types defined in `kimchi_backend_common/*` and instantiated in `pasta/basic.ml` and `pasta/{pallas,vesta}_based_plonk.ml`.

## File structure

```
kimchi_backend/
├── pasta/ # the instantiations of everything for both curves
│   ├── basic.ml # instantiate a number of things
│   ├── {pallas,vesta}_based_plonk.ml # instantiate the backend for the different curves
│   ├── precomputed.ml
├── common/ # the stuff that both curves have in common
│   ├── bigint.ml
│   ├── curve.ml
│   ├── dlog_plonk_based_keypair.ml
│   ├── dlog_urs.ml
│   ├── endoscale_round.ml
│   ├── field.ml
│   ├── intf.ml
│   ├── plonk_constraint_system.ml # the functor to create a constraint system
│   ├── plonk_dlog_oracles.ml
│   ├── plonk_dlog_proof.ml
│   ├── poly_comm.ml
│   ├── scale_round.ml
│   ├── var.ml
│   ├── version.ml
└── kimchi_backend.ml
```
