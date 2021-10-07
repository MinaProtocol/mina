use crate::{arkworks::CamlFp, caml_pointer::CamlPointer};
use mina_curves::pasta::fp::Fp;
use ocaml_gen::ocaml_gen;

pub type CamlPastaFpVector = CamlPointer<Vec<Fp>>;

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_vector_create() -> CamlPastaFpVector {
    CamlPointer::new(Vec::new())
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_vector_length(v: CamlPastaFpVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_vector_emplace_back(mut v: CamlPastaFpVector, x: CamlFp) {
    (*v).push(x.into());
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_vector_get(
    v: CamlPastaFpVector,
    i: ocaml::Int,
) -> Result<CamlFp, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(x.into()),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fp_vector_get")
            .err()
            .unwrap()),
    }
}
