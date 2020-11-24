use crate::tweedle_fp::{CamlTweedleFp, CamlTweedleFpPtr};
use algebra::tweedle::fp::Fp;
use std::ops::{Deref, DerefMut};

#[derive(Clone)]
pub struct CamlTweedleFpVector(pub *mut Vec<Fp>);

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_tweedle_fp_vector_finalize(v: ocaml::Value) {
    let mut v: ocaml::Pointer<CamlTweedleFpVector> = ocaml::FromValue::from_value(v);
    unsafe {
        // Memory is freed when the variable goes out of scope
        let _box = Box::from_raw(v.as_mut().0);
    }
}

ocaml::custom!(CamlTweedleFpVector {
    finalize: caml_tweedle_fp_vector_finalize,
});

impl From<CamlTweedleFpVector> for &Vec<Fp> {
    fn from(x: CamlTweedleFpVector) -> Self {
        unsafe { &*x.0 }
    }
}

impl Deref for CamlTweedleFpVector {
    type Target = Vec<Fp>;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.0 }
    }
}

impl DerefMut for CamlTweedleFpVector {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe { &mut *self.0 }
    }
}

unsafe impl ocaml::FromValue for CamlTweedleFpVector {
    fn from_value(x: ocaml::Value) -> Self {
        let x = ocaml::Pointer::<CamlTweedleFpVector>::from_value(x);
        (*x.as_ref()).clone()
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_create() -> CamlTweedleFpVector {
    CamlTweedleFpVector(Box::into_raw(Box::new(Vec::new())))
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_length(v: CamlTweedleFpVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_emplace_back(mut v: CamlTweedleFpVector, x: CamlTweedleFpPtr) {
    (*v).push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_tweedle_fp_vector_get(
    v: CamlTweedleFpVector,
    i: ocaml::Int,
) -> Result<CamlTweedleFp, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(CamlTweedleFp(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fp_vector_get")
            .err()
            .unwrap()),
    }
}
