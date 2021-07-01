use crate::arkworks::{CamlFp, CamlFq};
use ark_ff::Zero;
use mina_curves::pasta::{pallas::Affine as AffinePallas, vesta::Affine as AffineVesta};

// OCaml type

#[derive(Clone, Copy, ocaml::ToValue, ocaml::FromValue)]
pub enum CamlGroupAffine<T>
where
    T: ocaml::ToValue + ocaml::FromValue,
{
    Infinity,
    Finite((T, T)),
}

// Conversions from/to AffineVesta

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

// Conversion from/to AffinePallas

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
