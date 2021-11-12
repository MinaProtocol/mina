use mina_curves::pasta::{
    fp::Fp,
};
use oracle::poseidon::{
    PlonkSpongeConstants15W,
    ArithmeticSpongeParams};
use crate::field_vector::fp::CamlFpVector;

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
    CamlPastaFpPoseidonParams(oracle::pasta::fp_3::params())
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_block_cipher(
    params: CamlPastaFpPoseidonParamsPtr,
    mut state: CamlFpVector) {
    params.as_ref().0.poseidon_block_cipher::<PlonkSpongeConstants15W>(
        state.as_mut())
}
