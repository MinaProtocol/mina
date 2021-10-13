//! The Marlin_plonk_stubs crate exports some functionalities
//! and structures from the following the Rust crates to OCaml:
//!
//! * [Marlin](https://github.com/o1-labs/marlin),
//!   a PLONK implementation.
//! * [Arkworks](http://arkworks.rs/),
//!   a math library that Marlin builds on top of.
//!

extern crate libc;

/// Arkworks types
pub mod arkworks;

/// Caml pointers
pub mod caml_pointer;
pub mod gate_vector;
pub mod urs_utils; // TODO: move this logic to proof-systems

/// Field vectors
pub mod pasta_fp_vector;
pub mod pasta_fq_vector;

/// Groups
pub mod pasta_pallas;
pub mod pasta_vesta;

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
pub mod pasta_fp_plonk_oracles;
pub mod pasta_fq_plonk_oracles;

/// Proofs
pub mod pasta_fp_plonk_proof;
pub mod pasta_fq_plonk_proof;

/// Re-exports
pub use {
    commitment_dlog::commitment::caml::{CamlOpeningProof, CamlPolyComm},
    oracle::sponge::caml::CamlScalarChallenge,
    plonk_15_wires_circuits::{
        gate::{caml::CamlCircuitGate, GateType},
        nolookup::scalars::caml::{CamlLookupEvaluations, CamlProofEvaluations, CamlRandomOracles},
        wires::caml::CamlWire,
    },
    plonk_15_wires_protocol_dlog::prover::caml::{CamlProverCommitments, CamlProverProof},
};
