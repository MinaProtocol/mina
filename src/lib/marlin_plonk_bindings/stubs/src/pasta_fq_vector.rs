use crate::caml_pointer::{self, CamlPointer};
use algebra::pasta::fq::Fq;

pub type CamlPastaFqVector = CamlPointer<Vec<Fq>>;

#[ocaml::func]
pub fn caml_pasta_fq_vector_create() -> CamlPastaFqVector {
    caml_pointer::create(Vec::new())
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_length(v: CamlPastaFqVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_emplace_back(mut v: CamlPastaFqVector, x: Fq) {
    v.push(x);
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_get(
    v: CamlPastaFqVector,
    i: ocaml::Int,
) -> Result<Fq, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(*x),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fq_vector_get")
            .err()
            .unwrap()),
    }
}
