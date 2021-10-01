# Crypto

This folder groups all the cryptography-related packages

```
crypto/
├── marlin_plonk_bindings/ # bindings to the Rust proof-systems repo
├── random_oracle/ # poseidon hash function
├── random_oracle_input/ # TODO: this should be moved within the random_oracle package
├── sha256_lib/ # SHA-256 hash function
├── signature_lib/ # our schnorr signature implementation
└── zexe_backend/ # the glue between marlin_plonk_bindings and snarky/pickles
```