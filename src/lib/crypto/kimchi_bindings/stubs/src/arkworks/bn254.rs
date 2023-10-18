use crate::arkworks::CamlBigInteger256;
use ark_ff::PrimeField;
use std::{convert::TryFrom, ops::Deref};

type Fp = ark_bn254::Fr;

#[derive(Clone, Copy, Debug, ocaml_gen::CustomType)]
pub struct CamlBN254Fp(pub Fp);

unsafe impl<'a> ocaml::FromValue<'a> for CamlBN254Fp {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        *x.as_ref()
    }
}

impl CamlBN254Fp {
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

ocaml::custom!(CamlBN254Fp {
    finalize: CamlBN254Fp::caml_pointer_finalize,
    compare: CamlBN254Fp::ocaml_compare,
});

impl Deref for CamlBN254Fp {
    type Target = Fp;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//
// Handy implementations
//

impl From<Fp> for CamlBN254Fp {
    fn from(fp: Fp) -> Self {
        CamlBN254Fp(fp)
    }
}

impl From<&Fp> for CamlBN254Fp {
    fn from(fp: &Fp) -> Self {
        CamlBN254Fp(*fp)
    }
}

impl From<CamlBN254Fp> for Fp {
    fn from(camlfp: CamlBN254Fp) -> Fp {
        camlfp.0
    }
}

impl From<&CamlBN254Fp> for Fp {
    fn from(camlfp: &CamlBN254Fp) -> Fp {
        camlfp.0
    }
}

impl TryFrom<CamlBigInteger256> for CamlBN254Fp {
    type Error = ocaml::Error;
    fn try_from(x: CamlBigInteger256) -> Result<Self, Self::Error> {
        Fp::from_repr(x.0)
            .map(Into::into)
            .ok_or(ocaml::Error::Message(
                "TryFrom<CamlBigInteger256>: integer is larger than order",
            ))
    }
}
