use crate::arkworks::CamlBigInteger256;
use ark_ff::PrimeField;
use mina_curves::bn254::Fq;
use std::{convert::TryFrom, ops::Deref};

//
// BN254Fq <-> CamlBN254Fq
//

#[derive(Clone, Copy, ocaml_gen::CustomType)]
/// A wrapper type for [BN254 Fq](mina_curves::bn254::Fq)
pub struct CamlBN254Fq(pub Fq);

unsafe impl<'a> ocaml::FromValue<'a> for CamlBN254Fq {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        *x.as_ref()
    }
}

impl CamlBN254Fq {
    unsafe extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        let ptr = v.as_pointer::<Self>();
        ptr.drop_in_place()
    }

    unsafe extern "C" fn ocaml_compare(x: ocaml::Raw, y: ocaml::Raw) -> i32 {
        let x = x.as_pointer::<Self>();
        let y = y.as_pointer::<Self>();
        match x.as_ref().0.cmp(&y.as_ref().0) {
            core::cmp::Ordering::Less => -1,
            core::cmp::Ordering::Equal => 0,
            core::cmp::Ordering::Greater => 1,
        }
    }
}

ocaml::custom!(CamlBN254Fq {
    finalize: CamlBN254Fq::caml_pointer_finalize,
    compare: CamlBN254Fq::ocaml_compare,
});

//
// Handy implementations
//

impl Deref for CamlBN254Fq {
    type Target = Fq;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl From<Fq> for CamlBN254Fq {
    fn from(x: Fq) -> Self {
        CamlBN254Fq(x)
    }
}

impl From<&Fq> for CamlBN254Fq {
    fn from(x: &Fq) -> Self {
        CamlBN254Fq(*x)
    }
}

impl From<CamlBN254Fq> for Fq {
    fn from(camlfq: CamlBN254Fq) -> Fq {
        camlfq.0
    }
}

impl From<&CamlBN254Fq> for Fq {
    fn from(camlfq: &CamlBN254Fq) -> Fq {
        camlfq.0
    }
}

impl TryFrom<CamlBigInteger256> for CamlBN254Fq {
    type Error = ocaml::Error;
    fn try_from(x: CamlBigInteger256) -> Result<Self, Self::Error> {
        Fq::from_repr(x.0)
            .map(Into::into)
            .ok_or(ocaml::Error::Message(
                "TryFrom<CamlBigInteger256>: integer is larger than order",
            ))
    }
}
