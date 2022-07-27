//! The Marlin_plonk_stubs crate exports some functionalities
//! and structures from the following the Rust crates to OCaml:
//!
//! * [Proof-systems](https://github.com/o1-labs/proof-systems),
//!   a PLONK implementation.
//! * [Arkworks](http://arkworks.rs/),
//!   a math library that Proof-systems builds on top of.
//!

extern crate libc;

/// Caml helpers
#[macro_use]
pub mod caml;

/// Arkworks types
pub mod arkworks;

/// Utils
pub mod urs_utils; // TODO: move this logic to proof-systems

/// Vectors
pub mod field_vector;
pub mod gate_vector;

/// Curves
pub mod projective;

/// SRS
pub mod srs;

/// Indexes
pub mod pasta_fp_plonk_index;
pub mod pasta_fq_plonk_index;

/// Verifier indexes/keys
pub mod plonk_verifier_index;

pub mod pasta_fp_plonk_verifier_index;
pub mod pasta_fq_plonk_verifier_index;

/// Oracles
pub mod oracles;

/// Proofs
pub mod pasta_fp_plonk_proof;
pub mod pasta_fq_plonk_proof;

/// Poseidon
pub mod pasta_fp_poseidon;
pub mod pasta_fq_poseidon;

/// Linearization helpers
pub mod linearization;

/// Handy re-exports
pub use {
    commitment_dlog::commitment::caml::{CamlOpeningProof, CamlPolyComm},
    kimchi::{
        circuits::{
            gate::{caml::CamlCircuitGate, CurrOrNext, GateType},
            scalars::caml::CamlRandomOracles,
            wires::caml::CamlWire,
        },
        oracles::caml::CamlOracles,
        proof::caml::{CamlLookupEvaluations, CamlProofEvaluations},
        prover::caml::{CamlLookupCommitments, CamlProverCommitments, CamlProverProof},
    },
    oracle::sponge::caml::CamlScalarChallenge,
};
