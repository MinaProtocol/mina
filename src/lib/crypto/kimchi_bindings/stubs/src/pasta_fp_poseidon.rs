use crate::field_vector::fp::CamlFpVector;
use crate::field_vector::fp_batch::CamlFpBatchVector;
use mina_curves::pasta::Fp;
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi, constants::SpongeConstants,
    permutation::poseidon_block_cipher, poseidon::sbox, poseidon::ArithmeticSpongeParams,
};

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

#[inline]
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
        for r in 0..PlonkSpongeConstantsKimchi::PERM_ROUNDS_FULL {
            let mut el0 = state[0];
            let mut el1 = state[1];
            let mut el2 = state[2];
            el0 = sbox::<Fp, PlonkSpongeConstantsKimchi>(el0);
            el1 = sbox::<Fp, PlonkSpongeConstantsKimchi>(el1);
            el2 = sbox::<Fp, PlonkSpongeConstantsKimchi>(el2);
            // Manually unrolled loops for multiplying each row by the vector
            state[0] = params.mds[0][0] * el0
                + params.mds[0][1] * el1
                + params.mds[0][2] * el2
                + params.round_constants[r][0];
            state[1] = params.mds[1][0] * el0
                + params.mds[1][1] * el1
                + params.mds[1][2] * el2
                + params.round_constants[r][1];
            state[2] = params.mds[2][0] * el0
                + params.mds[2][1] * el1
                + params.mds[2][2] * el2
                + params.round_constants[r][2];
        }
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
    state: CamlFpVector,
    mut inputs: CamlFpBatchVector,
) {
    let state_ = state.to_vec();
    let params2 = &params.as_ref().0;
    inputs.iter_mut().for_each(|input| {
        let input_ = (&(*input)).to_vec();
        *input = state_.clone();
        caml_pasta_fp_poseidon_update_impl(params2, input.as_mut(), input_);
    })
}
