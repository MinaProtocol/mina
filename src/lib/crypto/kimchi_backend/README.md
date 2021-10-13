# Zexe-backend

This package contains the glue between:

* [snarky](), TKTK
* and [marlin-plonk-binding](), the OCaml bindings to [proof-systems]() (the Rust code that implements our proof systems).

As snarky expects specific "backend" modules, zexe-backend mostly contains functors that converts the ocaml-bindings found in [marlin-plonk-binding]() into what snarky expects.

There's three things to convert here:

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
│   ├── precomputed.ml # TODO: this should be documented
├── common/ # the stuff that both curves have in common
│   ├── bigint.ml
│   ├── curve.ml
│   ├── dlog_plonk_based_keypair.ml
│   ├── dlog_urs.ml
│   ├── endoscale_round.ml
│   ├── field.ml
│   ├── intf.ml # no freaking clue
│   ├── plonk_constraint_system.ml # the functor to create a constraint system
│   ├── plonk_dlog_oracles.ml
│   ├── plonk_dlog_proof.ml
│   ├── poly_comm.ml
│   ├── scale_round.ml
│   ├── var.ml # ?
│   ├── version.ml # there's a gen_version script that prolly should be called from mina_version/gen.sh, or even live in the stubs directory, not thereq
└── kimchi_backend.ml # ?
```

## Roadmap

- [ ] since we have multiple proof systems, but some common pieces (arkworks types), move the common pieces to their own module
- [ ] move this to a crypto/ repo
- [ ] rename this package (plonk backend?)
- [ ] implement the 15-wires backend
