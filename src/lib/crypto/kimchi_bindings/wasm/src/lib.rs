#![feature(get_mut_unchecked)]
//! The Marlin_plonk_stubs crate exports some functionalities
//! and structures from the following the Rust crates to OCaml:
//!
//! * [Marlin](https://github.com/o1-labs/marlin),
//!   a PLONK implementation.
//! * [Arkworks](http://arkworks.rs/),
//!   a math library that Marlin builds on top of.
//!

use wasm_bindgen::prelude::*;

mod wasm_flat_vector;
mod wasm_vector;

#[wasm_bindgen]
extern {
    pub fn alert(s: &str);
}

#[wasm_bindgen]
pub fn greet(name: &str) {
    alert(&format!("Hello, {}!", name));
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (crate::log(&format_args!($($t)*).to_string()))
}

#[wasm_bindgen]
pub fn console_log(s: &str) {
    log(s);
}

pub use wasm_bindgen_rayon::init_thread_pool;

/// Arkworks types
pub mod arkworks;

/// Utils
pub mod urs_utils; // TODO: move this logic to proof-systems

/// Vectors
pub mod gate_vector;

/// Curves
pub mod projective;
pub mod poly_comm;

/// SRS
pub mod srs;

/// Indexes
pub mod pasta_fp_plonk_index;
pub mod pasta_fq_plonk_index;

/// Verifier indexes/keys
pub mod plonk_verifier_index;

/// Oracles
pub mod oracles;

/// Proofs
pub mod plonk_proof;

/*
/// Handy re-exports
pub use {
    commitment_dlog::commitment::caml::{CamlOpeningProof, CamlPolyComm},
    kimchi::prover::caml::{CamlProverCommitments, CamlProverProof},
    kimchi_circuits::{
        expr::caml::{CamlColumn, CamlLinearization, CamlPolishToken, CamlVariable},
        gate::{caml::CamlCircuitGate, CurrOrNext, GateType},
        nolookup::scalars::caml::{CamlLookupEvaluations, CamlProofEvaluations, CamlRandomOracles},
        wires::caml::CamlWire,
    },
    oracle::sponge::caml::CamlScalarChallenge,
};
*/
