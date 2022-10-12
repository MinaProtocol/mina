use mina_curves::pasta::{Fp, Fq};
use oracle::{constants::PlonkSpongeConstantsKimchi, permutation::poseidon_block_cipher};
use wasm_bindgen::prelude::*;

use crate::{
    arkworks::{WasmPastaFp, WasmPastaFq},
    wasm_flat_vector::WasmFlatVector,
};

// fp

#[wasm_bindgen]
pub fn caml_pasta_fp_poseidon_block_cipher(
    state: WasmFlatVector<WasmPastaFp>,
) -> WasmFlatVector<WasmPastaFp> {
    let mut state_vec: Vec<Fp> = state.into_iter().map(Into::into).collect();
    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(
        &oracle::pasta::fp_kimchi::params(),
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
        &oracle::pasta::fq_kimchi::params(),
        &mut state_vec,
    );
    state_vec
        .iter()
        .map(|f| WasmPastaFq(*f))
        .collect::<Vec<WasmPastaFq>>()
        .into()
}
