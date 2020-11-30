use crate::tweedle_fq::{CamlTweedleFq, CamlTweedleFqPtr};
use algebra::tweedle::fq::Fq;
use std::ops::{Deref, DerefMut};

#[derive (Clone)]
pub struct CamlTweedleFqVector(pub *mut Vec<Fq>);

/* Note: The vector header is allocated in the OCaml heap, but the data held in
   the vector elements themselves are stored in the rust heap.
*/

extern "C" fn caml_tweedle_fq_vector_finalize(v: ocaml::Value) {
    let mut v: ocaml::Pointer<CamlTweedleFqVector> = ocaml::FromValue::from_value(v);
    unsafe {
        // Memory is freed when the variable goes out of scope
        let _box = Box::from_raw(v.as_mut().0);
    }
}

ocaml::custom!(CamlTweedleFqVector {
    finalize: caml_tweedle_fq_vector_finalize,
});

impl From<CamlTweedleFqVector> for &Vec<Fq> {
    fn from(x: CamlTweedleFqVector) -> Self {
        unsafe { &*x.0 }
    }
}

impl Deref for CamlTweedleFqVector {
    type Target = Vec<Fq>;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.0 }
    }
}

impl DerefMut for CamlTweedleFqVector {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe { &mut *self.0 }
    }
}

unsafe impl ocaml::FromValue for CamlTweedleFqVector {
    fn from_value(x: ocaml::Value) -> Self {
        let x = ocaml::Pointer::<CamlTweedleFqVector>::from_value(x);
        (*x.as_ref()).clone()
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_create() -> CamlTweedleFqVector {
    CamlTweedleFqVector(Box::into_raw(Box::new(Vec::new())))
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_length(v: CamlTweedleFqVector) -> ocaml::Int {
    v.len() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_emplace_back(mut v: CamlTweedleFqVector, x: CamlTweedleFqPtr) {
    v.push(x.as_ref().0);
}

#[ocaml::func]
pub fn caml_tweedle_fq_vector_get(
    v: CamlTweedleFqVector,
    i: ocaml::Int,
) -> Result<CamlTweedleFq, ocaml::Error> {
    match v.get(i as usize) {
        Some(x) => Ok(CamlTweedleFq(*x)),
        None => Err(ocaml::Error::invalid_argument("caml_tweedle_fq_vector_get")
            .err()
            .unwrap()),
    }
}
