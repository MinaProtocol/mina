#![feature(get_mut_unchecked)]
//! The Marlin_plonk_stubs crate exports some functionalities
//! and structures from the following the Rust crates to OCaml:
//!
//! * [Marlin](https://github.com/o1-labs/marlin),
//!   a PLONK implementation.
//! * [Arkworks](http://arkworks.rs/),
//!   a math library that Marlin builds on top of.
//!
use neon::{context::ModuleContext, result::NeonResult};

/// Arkworks types
mod arkworks;
/// Poseidon
mod poseidon;
mod wasm_flat_vector;
mod wasm_vector;

#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    cx.export_function(
        "caml_pasta_fp_poseidon_block_cipher",
        poseidon::caml_pasta_fp_poseidon_block_cipher,
    )?;
    cx.export_function(
        "caml_pasta_fq_poseidon_block_cipher",
        poseidon::caml_pasta_fq_poseidon_block_cipher,
    )?;

    Ok(())
}
