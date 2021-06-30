use crate::arkworks::{CamlFp, CamlFq};
use ark_ff::Zero;
use mina_curves::pasta::{pallas::Affine as AffinePallas, vesta::Affine as AffineVesta};

//

#[derive(Clone, Copy, ocaml::ToValue, ocaml::FromValue)]
pub enum CamlGroupAffine<T>
where
    T: ocaml::ToValue + ocaml::FromValue,
{
    Infinity,
    Finite((T, T)),
}

//

impl From<AffineVesta> for CamlGroupAffine<CamlFq> {
    fn from(point: AffineVesta) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<&AffineVesta> for CamlGroupAffine<CamlFq> {
    fn from(point: &AffineVesta) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl Into<AffineVesta> for CamlGroupAffine<CamlFq> {
    fn into(self) -> AffineVesta {
        match self {
            Self::Infinity => AffineVesta::zero(),
            Self::Finite((x, y)) => AffineVesta::new(x.into(), y.into(), false),
        }
    }
}

impl Into<AffineVesta> for &CamlGroupAffine<CamlFq> {
    fn into(self) -> AffineVesta {
        match self {
            CamlGroupAffine::Infinity => AffineVesta::zero(),
            CamlGroupAffine::Finite((x, y)) => AffineVesta::new(x.into(), y.into(), false),
        }
    }
}

//

impl From<AffinePallas> for CamlGroupAffine<CamlFp> {
    fn from(point: AffinePallas) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<&AffinePallas> for CamlGroupAffine<CamlFp> {
    fn from(point: &AffinePallas) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl Into<AffinePallas> for CamlGroupAffine<CamlFp> {
    fn into(self) -> AffinePallas {
        match self {
            Self::Infinity => AffinePallas::zero(),
            Self::Finite((x, y)) => AffinePallas::new(x.into(), y.into(), false),
        }
    }
}

impl Into<AffinePallas> for &CamlGroupAffine<CamlFp> {
    fn into(self) -> AffinePallas {
        match self {
            CamlGroupAffine::Infinity => AffinePallas::zero(),
            CamlGroupAffine::Finite((x, y)) => AffinePallas::new(x.into(), y.into(), false),
        }
    }
}

/*

#[cfg(feature = "ocaml_types")]
unsafe impl<P: Parameters> ocaml::ToValue for GroupAffine<P>
where
    P::BaseField: ocaml::ToValue,
{
    fn to_value(self) -> ocaml::Value {
        if self.infinity {
            ocaml::ToValue::to_value(CamlGroupAffine::<P::BaseField>::Infinity)
        } else {
            ocaml::ToValue::to_value(CamlGroupAffine::Finite((self.x, self.y)))
        }
    }
}

#[cfg(feature = "ocaml_types")]
unsafe impl<P: Parameters> ocaml::FromValue for GroupAffine<P>
where
    P::BaseField: ocaml::FromValue,
{
    fn from_value(v: ocaml::Value) -> Self {
        let g: CamlGroupAffine<P::BaseField> = ocaml::FromValue::from_value(v);
        match g {
            CamlGroupAffine::Infinity => Self::zero(),
            CamlGroupAffine::Finite((x, y)) => Self::new(x, y, false),
        }
    }
}

// Pallas

#[derive(Clone, Copy)]
pub struct CamlGroupAffinePallas(pub AffinePallas);

unsafe impl ocaml::FromValue for CamlGroupAffinePallas {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlGroupAffinePallas {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlGroupAffinePallas {
    finalize: CamlGroupAffinePallas::caml_pointer_finalize,
});

impl Deref for CamlGroupAffinePallas {
    type Target = AffinePallas;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//
// Handy implementations
//

impl From<AffinePallas> for CamlGroupAffinePallas {
    fn from(x: AffinePallas) -> Self {
        CamlGroupAffinePallas(x)
    }
}

impl From<&AffinePallas> for CamlGroupAffinePallas {
    fn from(x: &AffinePallas) -> Self {
        CamlGroupAffinePallas(*x)
    }
}

impl Into<AffinePallas> for CamlGroupAffinePallas {
    fn into(self) -> AffinePallas {
        self.0
    }
}

impl Into<AffinePallas> for &CamlGroupAffinePallas {
    fn into(self) -> AffinePallas {
        self.0
    }
}

// Vesta

#[derive(Clone, Copy)]
pub struct CamlGroupAffineVesta(pub AffineVesta);

unsafe impl ocaml::FromValue for CamlGroupAffineVesta {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlGroupAffineVesta {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlGroupAffineVesta {
    finalize: CamlGroupAffineVesta::caml_pointer_finalize,
});

impl Deref for CamlGroupAffineVesta {
    type Target = AffineVesta;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//
// Handy implementations
//

impl From<AffineVesta> for CamlGroupAffineVesta {
    fn from(x: AffineVesta) -> Self {
        CamlGroupAffineVesta(x)
    }
}

impl From<&AffineVesta> for CamlGroupAffineVesta {
    fn from(x: &AffineVesta) -> Self {
        CamlGroupAffineVesta(*x)
    }
}

impl Into<AffineVesta> for CamlGroupAffineVesta {
    fn into(self) -> AffineVesta {
        self.0
    }
}

impl Into<AffineVesta> for &CamlGroupAffineVesta {
    fn into(self) -> AffineVesta {
        self.0
    }
}

*/
