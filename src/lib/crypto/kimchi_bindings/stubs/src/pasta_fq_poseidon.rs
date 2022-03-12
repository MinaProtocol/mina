use crate::field_vector::fq::CamlFqVector;
use mina_curves::pasta::fq::Fq;
use oracle::poseidon::{poseidon_block_cipher, ArithmeticSpongeParams, PlonkSpongeConstantsKimchi};

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
    CamlPastaFqPoseidonParams(oracle::pasta::fq_kimchi::params())
}

#[ocaml::func]
pub fn caml_pasta_fq_poseidon_block_cipher(
    params: CamlPastaFqPoseidonParamsPtr,
    mut state: CamlFqVector,
) {
    poseidon_block_cipher::<Fq, PlonkSpongeConstantsKimchi>(&params.as_ref().0, state.as_mut())
}
