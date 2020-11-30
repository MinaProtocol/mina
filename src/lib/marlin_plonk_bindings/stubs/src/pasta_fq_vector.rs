use crate::pasta_fq::{CamlPastaFq, CamlPastaFqPtr};
use algebra::pasta::fq::Fq;
use std::ops::{Deref, DerefMut};

#[derive (Clone)]
pub struct CamlPastaFqVector(pub *mut Vec<Fq>);

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_pasta_fq_vector_finalize(v: ocaml::Value) {
    let mut v: ocaml::Pointer<CamlPastaFqVector> = ocaml::FromValue::from_value(v);
    unsafe {
        // Memory is freed when the variable goes out of scope
        let _box = Box::from_raw(v.as_mut().0);
    }
}

ocaml::custom!(CamlPastaFqVector {
    finalize: caml_pasta_fq_vector_finalize,
});

impl From<CamlPastaFqVector> for &Vec<Fq> {
    fn from(x: CamlPastaFqVector) -> Self {
        unsafe { &*x.0 }
    }
}

impl Deref for CamlPastaFqVector {
    type Target = Vec<Fq>;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.0 }
    }
}

impl DerefMut for CamlPastaFqVector {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe { &mut *self.0 }
    }
}

unsafe impl ocaml::FromValue for CamlPastaFqVector {
    fn from_value(x: ocaml::Value) -> Self {
        let x = ocaml::Pointer::<CamlPastaFqVector>::from_value(x);
        (*x.as_ref()).clone()
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_create() -> CamlPastaFqVector {
    CamlPastaFqVector(Box::into_raw(Box::new(Vec::new())))
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_length(v: CamlPastaFqVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_emplace_back(mut v: CamlPastaFqVector, x: CamlPastaFqPtr) {
    v.push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_pasta_fq_vector_get(
    v: CamlPastaFqVector,
    i: ocaml::Int,
) -> Result<CamlPastaFq, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(CamlPastaFq(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_pasta_fq_vector_get")
            .err()
            .unwrap()),
    }
}
