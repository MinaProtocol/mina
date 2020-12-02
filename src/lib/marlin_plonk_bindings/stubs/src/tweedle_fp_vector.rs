use algebra::tweedle::fp::Fp;
use crate::caml_pointer::{self, CamlPointer};

pub type CamlTweedleFpVector = CamlPointer<Vec<Fp>>;

#[ocaml::func]
pub fn caml_tweedle_fp_vector_create() -> CamlTweedleFpVector {
    caml_pointer::create(Vec::new())
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_length(v: CamlTweedleFpVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_emplace_back(mut v: CamlTweedleFpVector, x: Fp) {
    (*v).push(x);
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_get(
    v: CamlTweedleFpVector,
    i: ocaml::Int,
) -> Result<Fp, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(*x),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fp_vector_get")
            .err()
            .unwrap()),
    }
}
