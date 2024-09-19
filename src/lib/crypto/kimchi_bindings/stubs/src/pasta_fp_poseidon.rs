use crate::field_vector::fp::CamlFpVector;
use crate::field_vector::fp_batch::CamlFpBatchVector;
use mina_curves::pasta::Fp;
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi, constants::SpongeConstants,
    permutation::poseidon_block_cipher, poseidon::ArithmeticSpongeParams,
};
use rayon::iter::ParallelIterator;
use rayon::prelude::ParallelSliceMut;

pub struct CamlPastaFpPoseidonParams(ArithmeticSpongeParams<Fp>);
pub type CamlPastaFpPoseidonParamsPtr<'a> = ocaml::Pointer<'a, CamlPastaFpPoseidonParams>;

extern "C" fn caml_pasta_fp_poseidon_params_finalize(v: ocaml::Raw) {
    unsafe {
        let v: CamlPastaFpPoseidonParamsPtr = v.as_pointer();
        v.drop_in_place()
    };
}

ocaml::custom!(CamlPastaFpPoseidonParams {
    finalize: caml_pasta_fp_poseidon_params_finalize,
});

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_params_create() -> CamlPastaFpPoseidonParams {
    CamlPastaFpPoseidonParams(mina_poseidon::pasta::fp_kimchi::params())
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_block_cipher(
    params: CamlPastaFpPoseidonParamsPtr,
    mut state: CamlFpVector,
) {
    poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(&params.as_ref().0, state.as_mut())
}

pub fn caml_pasta_fp_poseidon_update_impl(
    params: &ArithmeticSpongeParams<Fp>,
    state: &mut Vec<Fp>,
    input: Vec<Fp>,
) {
    let rate = PlonkSpongeConstantsKimchi::SPONGE_RATE;
    let rem = input.len() % rate;
    let mut num = input.len() / rate;
    if rem > 0 || num == 0 {
        num += 1;
    }
    for i in 0..num {
        for j in 0..rate {
            let ix = i * rate + j;
            if ix < input.len() {
                // Sponge rate = 2
                state[j] += input[ix]
            }
        }
        poseidon_block_cipher::<Fp, PlonkSpongeConstantsKimchi>(params, state)
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_update(
    params: CamlPastaFpPoseidonParamsPtr,
    mut state: CamlFpVector,
    input: CamlFpVector,
) {
    caml_pasta_fp_poseidon_update_impl(&params.as_ref().0, state.as_mut(), input.to_vec());
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_update_batch(
    params: CamlPastaFpPoseidonParamsPtr,
    chunk_size: usize,
    state: CamlFpVector,
    mut inputs: CamlFpBatchVector,
) {
    let state_ = state.to_vec();
    let params2 = &params.as_ref().0;
    let f = |input: &mut Vec<Fp>| {
        let input_ = input.clone();
        *input = state_.clone();
        caml_pasta_fp_poseidon_update_impl(params2, input, input_);
    };
    inputs
        .par_chunks_mut(chunk_size)
        .for_each(|chunk| chunk.iter_mut().for_each(f));
}
