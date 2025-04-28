# Cryptography Libraries

This directory contains all cryptography-related functionality for the Mina
protocol. The libraries have been reorganized to improve code organization and
discoverability.

## Structure

The cryptography libraries are organized into the following categories:

### Elliptic Curves and Fields
- **crypto_params/** - Configuration parameters for cryptographic operations
- **non_zero_curve_point/** - Representation of non-zero points on elliptic
  curves
- **snarky_curves/** - Implementation of elliptic curves for SNARKs
- **snarky_field_extensions/** - Field extensions for elliptic curve operations
- **snarky_group_map/** - Mapping from field elements to curve points

### Hash
- **blake2/** - Implementation of the Blake2 cryptographic hash function
- **bowe_gabizon_hash/** - Implementation of the Bowe-Gabizon hash function for
  secure cryptographic operations
- **data_hash_lib/** - Core implementation of various hash types, including
  state hashes
- **hash_prefixes/** - Definitions of hash prefixes used to distinguish
  different hash types
- **hash_prefix_states/** - Pre-computed hash prefix states for optimizing hash
  calculations
- **sha256_lib/** - Implementation of the SHA-256 hash function
- **with_hash/** - Utilities for working with hashed data

### Key Management
- **key_cache/** - Caching system for cryptographic keys
- **key_gen/** - Key generation utilities
- **snark_keys_header/** - Header information for SNARK verification keys

### Signature
- **signature_lib/** - Core signature functionality including key generation and
  verification
- **signature_kind/** - Different types of signatures supported by the protocol
- **global_signer_private_key/** - Management of global signing keys

### SNARK
- **blockchain_snark/** - Implementation of SNARKs for verifying blockchain
  transitions
- **kimchi_backend/** - The glue between Kimchi and Snarky/Pickles
- **kimchi_bindings/** - The glue between OCaml and Kimchi (the proof system in Rust)
- **kimchi_pasta_snarky_backend/** - Implementation of pasta curves for the
  Kimchi proof system
- **pickles/** - Recursive SNARK composition system
- **pickles_base/** - Base types and utilities for the Pickles library
- **pickles_types/** - Type definitions for the Pickles library
- **plonkish_prelude/** - Core utilities for PLONK-based proof systems
- **proof-systems/** - Rust implementation of the Kimchi proof system
- **snark_params/** - Parameters for SNARK operations
- **transaction_snark/** - SNARKs for transaction verification
- **transaction_witness/** - Witness generation for transaction SNARKs

### VRF and Random Oracle
- **random_oracle/** - Implementation of the random oracle model
- **random_oracle_input/** - Input handling for random oracles
- **vrf_lib/** - Verifiable Random Function implementation
- **vrf_evaluator/** - Evaluation functionality for VRFs
