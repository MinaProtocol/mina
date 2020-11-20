use crate::pasta_fp::{CamlPastaFp, CamlPastaFpPtr};
use algebra::pasta::fp::Fp;

pub struct CamlPastaFpVector(pub Vec<Fp>);
pub type CamlPastaFpVectorPtr = ocaml::Pointer<CamlPastaFpVector>;

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_pasta_fp_vector_finalize(v: ocaml::Value) {
    let mut v: CamlPastaFpVectorPtr = ocaml::FromValue::from_value(v);
    unsafe {
        v.as_mut_ptr().drop_in_place();
    }
}

ocaml::custom!(CamlPastaFpVector {
    finalize: caml_pasta_fp_vector_finalize,
});

#[ocaml::func]
pub fn caml_pasta_fp_vector_create() -> CamlPastaFpVector {
    CamlPastaFpVector(Vec::new())
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_length(v: CamlPastaFpVectorPtr) -> ocaml::Int {
    v.as_ref().0.len() as isize
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_emplace_back(mut v: CamlPastaFpVectorPtr, x: CamlPastaFpPtr) {
    v.as_mut().0.push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_get(
    v: CamlPastaFpVectorPtr,
    i: ocaml::Int,
) -> Result<CamlPastaFp, ocaml::Error> {
    match v.as_ref().0.get(i as usize) {
        Some(x) => Ok(CamlPastaFp(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fp_vector_get")
            .err()
            .unwrap()),
    }
}
