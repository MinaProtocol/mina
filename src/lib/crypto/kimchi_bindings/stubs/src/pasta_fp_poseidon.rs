use crate::field_vector::fp::CamlFpVector;
use crate::field_vector::fp_batch::CamlFpBatchVector;
use mina_curves::pasta::Fp;
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    constants::SpongeConstants,
    poseidon::{sbox, ArithmeticSpongeParams},
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

pub fn full_round(
    params: &ArithmeticSpongeParams<Fp>,
    state0: &mut Fp,
    state1: &mut Fp,
    state2: &mut Fp,
    r: usize,
) {
    let mut el0 = *state0;
    let mut el1 = *state1;
    let mut el2 = *state2;
    el0 = sbox::<Fp, PlonkSpongeConstantsKimchi>(el0);
    el1 = sbox::<Fp, PlonkSpongeConstantsKimchi>(el1);
    el2 = sbox::<Fp, PlonkSpongeConstantsKimchi>(el2);
    // Manually unrolled loops for multiplying each row by the vector
    *state0 = params.mds[0][0] * el0
        + params.mds[0][1] * el1
        + params.mds[0][2] * el2
        + params.round_constants[r][0];
    *state1 = params.mds[1][0] * el0
        + params.mds[1][1] * el1
        + params.mds[1][2] * el2
        + params.round_constants[r][1];
    *state2 = params.mds[2][0] * el0
        + params.mds[2][1] * el1
        + params.mds[2][2] * el2
        + params.round_constants[r][2];
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_block_cipher(
    params: CamlPastaFpPoseidonParamsPtr,
    mut state: CamlFpVector,
) {
    let mut state0 = state[0];
    let mut state1 = state[1];
    let mut state2 = state[2];
    let params = &params.as_ref().0;
    for r in 0..PlonkSpongeConstantsKimchi::PERM_ROUNDS_FULL {
        full_round(params, &mut state0, &mut state1, &mut state2, r);
    }
    state[0] = state0;
    state[1] = state1;
    state[2] = state2;
}

pub fn caml_pasta_fp_poseidon_update_impl(
    params: &ArithmeticSpongeParams<Fp>,
    state_and_input: &Vec<Fp>,
) -> [Fp; 3] {
    let mut state0 = state_and_input[0];
    let mut state1 = state_and_input[1];
    let mut state2 = state_and_input[2];
    // Implemented for rate=2, width=3
    let len = state_and_input.len() - 3;
    if len == 0 {
        for r in 0..PlonkSpongeConstantsKimchi::PERM_ROUNDS_FULL {
            full_round(params, &mut state0, &mut state1, &mut state2, r);
        }
    } else {
        let num = (len >> 1) + (len & 1);
        for i in 0..num {
            let i_ = i << 1;
            state0 += state_and_input[3 + i_];
            if i_ + 1 < len {
                state1 += state_and_input[4 + i_];
            }
            for r in 0..PlonkSpongeConstantsKimchi::PERM_ROUNDS_FULL {
                full_round(params, &mut state0, &mut state1, &mut state2, r);
            }
        }
    }
    [state0, state1, state2]
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_update(
    params: CamlPastaFpPoseidonParamsPtr,
    mut state_and_input: CamlFpVector,
) {
    let state = caml_pasta_fp_poseidon_update_impl(&params.as_ref().0, &state_and_input);
    state_and_input[0] = state[0];
    state_and_input[1] = state[1];
    state_and_input[2] = state[2];
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_update_batch(
    params: CamlPastaFpPoseidonParamsPtr,
    chunk_size: usize,
    mut state_and_inputs: CamlFpBatchVector,
) {
    let params2 = &params.as_ref().0;
    let f =
        |state_and_input: &Vec<Fp>| caml_pasta_fp_poseidon_update_impl(params2, state_and_input);
    state_and_inputs
        .par_chunks_mut(chunk_size)
        .for_each(|chunk| {
            let states: Vec<[Fp; 3]> = (*chunk).to_vec().iter().map(f).collect();
            chunk.iter_mut().enumerate().for_each(|(ix, chunk)| {
                chunk[0] = states[ix][0];
                chunk[1] = states[ix][1];
                chunk[2] = states[ix][2];
            })
        });
}
