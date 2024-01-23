use mina_curves::pasta::{
    fp::Fp,
};
use oracle::poseidon::{
    poseidon_block_cipher,
    PlonkSpongeConstants,
    ArithmeticSpongeParams};
use crate::pasta_fp_vector::CamlPastaFpVector;

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
    CamlPastaFpPoseidonParams(oracle::pasta::fp::params())
}

#[ocaml::func]
pub fn caml_pasta_fp_poseidon_block_cipher(
    params: CamlPastaFpPoseidonParamsPtr,
    mut state: CamlPastaFpVector) {
    poseidon_block_cipher::<Fp, PlonkSpongeConstants>(
        & params.as_ref().0,
        state.as_mut())
}
