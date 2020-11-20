use crate::pasta_fq::{CamlPastaFq, CamlPastaFqPtr};
use algebra::pasta::fq::Fq;

pub struct CamlPastaFqVector(pub Vec<Fq>);
pub type CamlPastaFqVectorPtr = ocaml::Pointer<CamlPastaFqVector>;

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_pasta_fq_vector_finalize(v: ocaml::Value) {
    let mut v: CamlPastaFqVectorPtr = ocaml::FromValue::from_value(v);
    unsafe {
        v.as_mut_ptr().drop_in_place();
    }
}

ocaml::custom!(CamlPastaFqVector {
    finalize: caml_pasta_fq_vector_finalize,
});

#[ocaml::func]
pub fn caml_pasta_fq_vector_create() -> CamlPastaFqVector {
    CamlPastaFqVector(Vec::new())
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_length(v: CamlPastaFqVectorPtr) -> ocaml::Int {
    v.as_ref().0.len() as isize
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_emplace_back(mut v: CamlPastaFqVectorPtr, x: CamlPastaFqPtr) {
    v.as_mut().0.push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_get(
    v: CamlPastaFqVectorPtr,
    i: ocaml::Int,
) -> Result<CamlPastaFq, ocaml::Error> {
    match v.as_ref().0.get(i as usize) {
        Some(x) => Ok(CamlPastaFq(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fq_vector_get")
            .err()
            .unwrap()),
    }
}
