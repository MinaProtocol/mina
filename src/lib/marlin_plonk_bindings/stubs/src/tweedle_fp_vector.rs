use crate::tweedle_fp::{CamlTweedleFp, CamlTweedleFpPtr};
use algebra::tweedle::fp::Fp;

pub struct CamlTweedleFpVector(pub Vec<Fp>);
pub type CamlTweedleFpVectorPtr = ocaml::Pointer<CamlTweedleFpVector>;

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_tweedle_fp_vector_finalize(v: ocaml::Value) {
    let mut v: CamlTweedleFpVectorPtr = ocaml::FromValue::from_value(v);
    unsafe {
        v.as_mut_ptr().drop_in_place();
    }
}

ocaml::custom!(CamlTweedleFpVector {
    finalize: caml_tweedle_fp_vector_finalize,
});

#[ocaml::func]
pub fn caml_tweedle_fp_vector_create() -> CamlTweedleFpVector {
    CamlTweedleFpVector(Vec::new())
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_length(v: CamlTweedleFpVectorPtr) -> ocaml::Int {
    v.as_ref().0.len() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_emplace_back(mut v: CamlTweedleFpVectorPtr, x: CamlTweedleFpPtr) {
    v.as_mut().0.push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_get(
    v: CamlTweedleFpVectorPtr,
    i: ocaml::Int,
) -> Result<CamlTweedleFp, ocaml::Error> {
    match v.as_ref().0.get(i as usize) {
        Some(x) => Ok(CamlTweedleFp(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fp_vector_get")
            .err()
            .unwrap()),
    }
}
