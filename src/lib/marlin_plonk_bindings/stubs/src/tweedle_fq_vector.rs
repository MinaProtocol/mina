use crate::tweedle_fq::{CamlTweedleFq, CamlTweedleFqPtr};
use algebra::tweedle::fq::Fq;

pub struct CamlTweedleFqVector(pub Vec<Fq>);
pub type CamlTweedleFqVectorPtr = ocaml::Pointer<CamlTweedleFqVector>;

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_tweedle_fq_vector_finalize(v: ocaml::Value) {
    let mut v: CamlTweedleFqVectorPtr = ocaml::FromValue::from_value(v);
    unsafe {
        v.as_mut_ptr().drop_in_place();
    }
}

ocaml::custom!(CamlTweedleFqVector {
    finalize: caml_tweedle_fq_vector_finalize,
});

#[ocaml::func]
pub fn caml_tweedle_fq_vector_create() -> CamlTweedleFqVector {
    CamlTweedleFqVector(Vec::new())
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_length(v: CamlTweedleFqVectorPtr) -> ocaml::Int {
    v.as_ref().0.len() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_emplace_back(mut v: CamlTweedleFqVectorPtr, x: CamlTweedleFqPtr) {
    v.as_mut().0.push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_get(
    v: CamlTweedleFqVectorPtr,
    i: ocaml::Int,
) -> Result<CamlTweedleFq, ocaml::Error> {
    match v.as_ref().0.get(i as usize) {
        Some(x) => Ok(CamlTweedleFq(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fq_vector_get")
            .err()
            .unwrap()),
    }
}
