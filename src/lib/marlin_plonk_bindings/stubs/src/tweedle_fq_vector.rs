use algebra::tweedle::fq::Fq;
use crate::caml_pointer::{self, CamlPointer};

pub type CamlTweedleFqVector = CamlPointer<Vec<Fq>>;

#[ocaml::func]
pub fn caml_tweedle_fq_vector_create() -> CamlTweedleFqVector {
    caml_pointer::create(Vec::new())
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_length(v: CamlTweedleFqVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_emplace_back(mut v: CamlTweedleFqVector, x: Fq) {
    v.push(x);
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_get(
    v: CamlTweedleFqVector,
    i: ocaml::Int,
) -> Result<Fq, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(*x),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fq_vector_get")
            .err()
            .unwrap()),
    }
}
