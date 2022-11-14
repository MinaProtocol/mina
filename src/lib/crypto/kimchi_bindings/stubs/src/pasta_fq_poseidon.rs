use crate::field_vector::fq::CamlFqVector;
use mina_curves::pasta::Fq;
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi, permutation::poseidon_block_cipher,
    poseidon::ArithmeticSpongeParams,
};
pub struct CamlPastaFqPoseidonParams(ArithmeticSpongeParams<Fq>);
pub type CamlPastaFqPoseidonParamsPtr<'a> = ocaml::Pointer<'a, CamlPastaFqPoseidonParams>;

extern "C" fn caml_pasta_fq_poseidon_params_finalize(v: ocaml::Raw) {
    unsafe {
        let v: CamlPastaFqPoseidonParamsPtr = v.as_pointer();
        v.drop_in_place()
    };
}

ocaml::custom!(CamlPastaFqPoseidonParams {
    finalize: caml_pasta_fq_poseidon_params_finalize,
});

#[ocaml::func]
pub fn caml_pasta_fq_poseidon_params_create() -> CamlPastaFqPoseidonParams {
    CamlPastaFqPoseidonParams(mina_poseidon::pasta::fq_kimchi::params())
}

#[ocaml::func]
pub fn caml_pasta_fq_poseidon_block_cipher(
    params: CamlPastaFqPoseidonParamsPtr,
    mut state: CamlFqVector,
) {
    poseidon_block_cipher::<Fq, PlonkSpongeConstantsKimchi>(&params.as_ref().0, state.as_mut())
}
