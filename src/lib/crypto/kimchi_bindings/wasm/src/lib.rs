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
extern "C" {
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

// produces a warning, but can be useful
// macro_rules! console_log {
//     ($($t:tt)*) => (crate::log(&format_args!($($t)*).to_string()))
// }

#[wasm_bindgen]
pub fn console_log(s: &str) {
    log(s);
}

#[wasm_bindgen]
pub fn create_zero_u32_ptr() -> *mut u32 {
    Box::into_raw(std::boxed::Box::new(0))
}

#[wasm_bindgen]
pub fn free_u32_ptr(ptr: *mut u32) {
    let _drop_me = unsafe { std::boxed::Box::from_raw(ptr) };
}

#[wasm_bindgen]
pub fn set_u32_ptr(ptr: *mut u32, arg: u32) {
    // The rust docs explicitly forbid using this for cross-thread syncronization. Oh well, we
    // don't have anything better. As long as it works in practice, we haven't upset the undefined
    // behavior dragons.
    unsafe {
        std::ptr::write_volatile(ptr, arg);
    }
}

#[wasm_bindgen]
pub fn wait_until_non_zero(ptr: *const u32) -> u32 {
    // The rust docs explicitly forbid using this for cross-thread syncronization. Oh well, we
    // don't have anything better. As long as it works in practice, we haven't upset the undefined
    // behavior dragons.
    loop {
        let contents = unsafe { std::ptr::read_volatile(ptr) };
        if contents != 0 {
            return contents;
        }
    }
    unreachable!();
}

pub use wasm_bindgen_rayon::init_thread_pool;

/// Arkworks types
pub mod arkworks;

/// Utils
pub mod urs_utils; // TODO: move this logic to proof-systems

/// Vectors
pub mod gate_vector;

pub mod poly_comm;
/// Curves
pub mod projective;

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
    kimchi::circuits::{
        expr::caml::{CamlColumn, CamlLinearization, CamlPolishToken, CamlVariable},
        gate::{caml::CamlCircuitGate, CurrOrNext, GateType},
        nolookup::scalars::caml::{CamlLookupEvaluations, CamlProofEvaluations, CamlRandomOracles},
        wires::caml::CamlWire,
    },
    oracle::sponge::caml::CamlScalarChallenge,
};
*/
