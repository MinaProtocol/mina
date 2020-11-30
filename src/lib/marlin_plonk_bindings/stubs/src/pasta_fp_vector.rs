use crate::pasta_fp::{CamlPastaFp, CamlPastaFpPtr};
use algebra::pasta::fp::Fp;
use std::ops::{Deref, DerefMut};

#[derive (Clone)]
pub struct CamlPastaFpVector(pub *mut Vec<Fp>);

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_pasta_fp_vector_finalize(v: ocaml::Value) {
    let mut v: ocaml::Pointer<CamlPastaFpVector> = ocaml::FromValue::from_value(v);
    unsafe {
        // Memory is freed when the variable goes out of scope
        let _box = Box::from_raw(v.as_mut().0);
    }
}

ocaml::custom!(CamlPastaFpVector {
    finalize: caml_pasta_fp_vector_finalize,
});

impl From<CamlPastaFpVector> for &Vec<Fp> {
    fn from(x: CamlPastaFpVector) -> Self {
        unsafe { &*x.0 }
    }
}

impl Deref for CamlPastaFpVector {
    type Target = Vec<Fp>;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.0 }
    }
}

impl DerefMut for CamlPastaFpVector {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe { &mut *self.0 }
    }
}

unsafe impl ocaml::FromValue for CamlPastaFpVector {
    fn from_value(x: ocaml::Value) -> Self {
        let x = ocaml::Pointer::<CamlPastaFpVector>::from_value(x);
        (*x.as_ref()).clone()
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_create() -> CamlPastaFpVector {
    CamlPastaFpVector(Box::into_raw(Box::new(Vec::new())))
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_length(v: CamlPastaFpVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_emplace_back(mut v: CamlPastaFpVector, x: CamlPastaFpPtr) {
    (*v).push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_pasta_fp_vector_get(
    v: CamlPastaFpVector,
    i: ocaml::Int,
) -> Result<CamlPastaFp, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(CamlPastaFp(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fp_vector_get")
            .err()
            .unwrap()),
    }
}
