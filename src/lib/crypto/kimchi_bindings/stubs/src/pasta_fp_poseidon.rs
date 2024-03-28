use crate::field_vector::fp::CamlFpVector;
use mina_curves::pasta::Fp;
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi, permutation::poseidon_block_cipher,
    poseidon::ArithmeticSpongeParams,
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
