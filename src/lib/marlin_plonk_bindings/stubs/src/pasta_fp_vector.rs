use crate::caml_pointer::{self, CamlPointer};
use algebra::pasta::fp::Fp;

pub type CamlPastaFpVector = CamlPointer<Vec<Fp>>;

#[ocaml::func]
pub fn caml_pasta_fp_vector_create() -> CamlPastaFpVector {
    caml_pointer::create(Vec::new())
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_length(v: CamlPastaFpVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_emplace_back(mut v: CamlPastaFpVector, x: Fp) {
    (*v).push(x);
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_get(
    v: CamlPastaFpVector,
    i: ocaml::Int,
) -> Result<Fp, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(*x),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fp_vector_get")
            .err()
            .unwrap()),
    }
}
