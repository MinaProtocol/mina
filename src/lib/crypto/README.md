# Crypto

This folder groups cryptography-relevant packages.

```
crypto/
├── kimchi_backend/               # the glue between kimchi and snarky/pickles (TODO: move to a kimchi/ folder)
├── kimchi_bindings/              # the glue between OCaml and kimchi (the proof system in Rust) # TODO: rename to kimchi
├── kimchi_pasta_snarky_backend/
└── mina-rust-dependencies        # a submodule pointing to the (vendored) Rust dependencies
└── plonkish_prelude              # OCaml library containing data structures encoded at the type level for Plonk-ish systems
```
