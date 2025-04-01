use mina_curves::pasta::{Fp, Fq};
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, permutation::poseidon_block_cipher};
use neon::{
    context::FunctionContext,
    result::JsResult,
    types::{buffer::TypedArray, JsUint8Array},
};

use crate::{
    arkworks::{WasmPastaFp, WasmPastaFq},
    wasm_flat_vector::{FlatVector, FlatVectorElem},
};

// fp

pub fn caml_pasta_fp_poseidon_block_cipher(mut cx: FunctionContext) -> JsResult<JsUint8Array> {
    let state: &JsUint8Array = &*cx.argument(0)?;

    let mut state: Vec<Fp> =
        FlatVector::<WasmPastaFp>::from_bytes(state.as_slice(&mut cx).to_vec())
            .into_iter()
            .map(Into::into)
            .collect();

    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(
        &mina_poseidon::pasta::fp_kimchi::static_params(),
        &mut state,
    );

    let res = state
        .iter()
        .map(|f| WasmPastaFp(*f))
        .flat_map(|f| f.flatten())
        .collect::<Vec<u8>>();

    JsUint8Array::from_slice(&mut cx, &res)
}

// fq

pub fn caml_pasta_fq_poseidon_block_cipher(mut cx: FunctionContext) -> JsResult<JsUint8Array> {
    let state: &JsUint8Array = &*cx.argument(0)?;

    let mut state: Vec<Fq> =
        FlatVector::<WasmPastaFq>::from_bytes(state.as_slice(&mut cx).to_vec())
            .into_iter()
            .map(Into::into)
            .collect();

    poseidon_block_cipher::<Fq, PlonkSpongeConstantsKimchi>(
        &mina_poseidon::pasta::fq_kimchi::static_params(),
        &mut state,
    );

    let res = state
        .iter()
        .map(|f| WasmPastaFq(*f))
        .flat_map(|f| f.flatten())
        .collect::<Vec<u8>>();

    JsUint8Array::from_slice(&mut cx, &res)
}
