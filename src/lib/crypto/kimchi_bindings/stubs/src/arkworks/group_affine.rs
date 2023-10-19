use crate::arkworks::{CamlBN254Fq, CamlFp, CamlFq};
use ark_ff::Zero;
use mina_curves::bn254::BN254 as AffineBN254;
use mina_curves::pasta::{Pallas as AffinePallas, Vesta as AffineVesta};

//
// handy types
//

pub type CamlGVesta = CamlGroupAffine<CamlFq>;
pub type CamlGPallas = CamlGroupAffine<CamlFp>;
pub type CamlGBN254 = CamlGroupAffine<CamlBN254Fq>;

//
// GroupAffine<G> <-> CamlGroupAffine<F>
//

#[derive(Clone, Copy, Debug, ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Enum)]
pub enum CamlGroupAffine<F> {
    Infinity,
    Finite((F, F)),
}

// Conversions from/to AffineVesta

impl From<AffineVesta> for CamlGVesta {
    fn from(point: AffineVesta) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<&AffineVesta> for CamlGVesta {
    fn from(point: &AffineVesta) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<CamlGVesta> for AffineVesta {
    fn from(camlg: CamlGVesta) -> Self {
        match camlg {
            CamlGVesta::Infinity => AffineVesta::zero(),
            CamlGVesta::Finite((x, y)) => AffineVesta::new(x.into(), y.into(), false),
        }
    }
}

impl From<&CamlGVesta> for AffineVesta {
    fn from(camlg: &CamlGVesta) -> Self {
        match camlg {
            CamlGroupAffine::Infinity => AffineVesta::zero(),
            CamlGroupAffine::Finite((x, y)) => AffineVesta::new(x.into(), y.into(), false),
        }
    }
}

// Conversion from/to AffinePallas

impl From<AffinePallas> for CamlGPallas {
    fn from(point: AffinePallas) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<&AffinePallas> for CamlGPallas {
    fn from(point: &AffinePallas) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<CamlGPallas> for AffinePallas {
    fn from(camlg: CamlGPallas) -> Self {
        match camlg {
            CamlGPallas::Infinity => AffinePallas::zero(),
            CamlGPallas::Finite((x, y)) => AffinePallas::new(x.into(), y.into(), false),
        }
    }
}

impl From<&CamlGPallas> for AffinePallas {
    fn from(camlg: &CamlGPallas) -> Self {
        match camlg {
            CamlGroupAffine::Infinity => AffinePallas::zero(),
            CamlGroupAffine::Finite((x, y)) => AffinePallas::new(x.into(), y.into(), false),
        }
    }
}

// Conversions from/to AffineBN254

impl From<AffineBN254> for CamlGBN254 {
    fn from(point: AffineBN254) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<&AffineBN254> for CamlGBN254 {
    fn from(point: &AffineBN254) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x.into(), point.y.into()))
        }
    }
}

impl From<CamlGBN254> for AffineBN254 {
    fn from(camlg: CamlGBN254) -> Self {
        match camlg {
            CamlGBN254::Infinity => AffineBN254::zero(),
            CamlGBN254::Finite((x, y)) => AffineBN254::new(x.into(), y.into(), false),
        }
    }
}

impl From<&CamlGBN254> for AffineBN254 {
    fn from(camlg: &CamlGBN254) -> Self {
        match camlg {
            CamlGroupAffine::Infinity => AffineBN254::zero(),
            CamlGroupAffine::Finite((x, y)) => AffineBN254::new(x.into(), y.into(), false),
        }
    }
}
