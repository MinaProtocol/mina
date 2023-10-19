use kimchi::prover_index::ProverIndex;
use mina_curves::bn254::BN254;
use poly_commitment::evaluation_proof::OpeningProof;

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
pub struct CamlBN254PlonkIndex(pub Box<ProverIndex<BN254, OpeningProof<BN254>>>);
pub type CamlBN254PlonkIndexPtr<'a> = ocaml::Pointer<'a, CamlBN254PlonkIndex>;

extern "C" fn caml_bn254_plonk_index_finalize(v: ocaml::Raw) {
    unsafe {
        let mut v: CamlBN254PlonkIndexPtr = v.as_pointer();
        v.as_mut_ptr().drop_in_place();
    }
}

impl ocaml::custom::Custom for CamlBN254PlonkIndex {
    const NAME: &'static str = "CamlBN254PlonkIndex\0";
    const USED: usize = 1;
    /// Encourage the GC to free when there are > 12 in memory
    const MAX: usize = 12;
    const OPS: ocaml::custom::CustomOps = ocaml::custom::CustomOps {
        identifier: Self::NAME.as_ptr() as *const ocaml::sys::Char,
        finalize: Some(caml_bn254_plonk_index_finalize),
        ..ocaml::custom::DEFAULT_CUSTOM_OPS
    };
}
