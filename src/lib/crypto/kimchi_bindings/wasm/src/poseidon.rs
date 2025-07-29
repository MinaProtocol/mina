//! This file defines wrapper for the Poseidon hash function that are used in
//! the Mina codebase.
//!
//! It is a wrapper around the Poseidon implementation in the `mina_poseidon` crate.
//! It is required as the native OCaml implementation of Mina does use the Rust
//! implementation defined in the crate `mina_poseidon` instead of defining its
//! own natively in OCaml for performance reasons. The bindings in OCaml can be
//! found in `src/lib/crypto/kimchi_bindings/pasta_fp_poseidon` and
//! `src/lib/crypto/kimchi_bindings/pasta_fq_poseidon` in the Mina codebase.

use arkworks::{WasmPastaFp, WasmPastaFq};
use mina_curves::pasta::{Fp, Fq};
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, permutation::poseidon_block_cipher};
use wasm_bindgen::prelude::*;
use wasm_types::FlatVector as WasmFlatVector;

// fp

#[wasm_bindgen]
pub fn caml_pasta_fp_poseidon_block_cipher(
    state: WasmFlatVector<WasmPastaFp>,
) -> WasmFlatVector<WasmPastaFp> {
    let mut state_vec: Vec<Fp> = state.into_iter().map(Into::into).collect();
    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(
        mina_poseidon::pasta::fp_kimchi::static_params(),
        &mut state_vec,
    );
    state_vec
        .iter()
        .map(|f| WasmPastaFp(*f))
        .collect::<Vec<WasmPastaFp>>()
        .into()
}

// fq

#[wasm_bindgen]
pub fn caml_pasta_fq_poseidon_block_cipher(
    state: WasmFlatVector<WasmPastaFq>,
) -> WasmFlatVector<WasmPastaFq> {
    let mut state_vec: Vec<Fq> = state.into_iter().map(Into::into).collect();
    poseidon_block_cipher::<Fq, PlonkSpongeConstantsKimchi>(
        mina_poseidon::pasta::fq_kimchi::static_params(),
        &mut state_vec,
    );
    state_vec
        .iter()
        .map(|f| WasmPastaFq(*f))
        .collect::<Vec<WasmPastaFq>>()
        .into()
}
