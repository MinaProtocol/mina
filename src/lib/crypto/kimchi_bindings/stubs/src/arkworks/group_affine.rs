use ark_ff::Zero;
use mina_curves::pasta::{Fp, Fq, Pallas as AffinePallas, Vesta as AffineVesta};

//
// handy types
//

pub type CamlGVesta = CamlGroupAffine<Fq>;
pub type CamlGPallas = CamlGroupAffine<Fp>;

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
            Self::Finite((point.x, point.y))
        }
    }
}

impl From<&AffineVesta> for CamlGVesta {
    fn from(point: &AffineVesta) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x, point.y))
        }
    }
}

impl From<CamlGVesta> for AffineVesta {
    fn from(camlg: CamlGVesta) -> Self {
        match camlg {
            CamlGVesta::Infinity => AffineVesta::zero(),
            CamlGVesta::Finite((x, y)) => AffineVesta::new(x, y, false),
        }
    }
}

impl From<&CamlGVesta> for AffineVesta {
    fn from(camlg: &CamlGVesta) -> Self {
        match camlg {
            CamlGroupAffine::Infinity => AffineVesta::zero(),
            CamlGroupAffine::Finite((x, y)) => AffineVesta::new(*x, *y, false),
        }
    }
}

// Conversion from/to AffinePallas

impl From<AffinePallas> for CamlGPallas {
    fn from(point: AffinePallas) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x, point.y))
        }
    }
}

impl From<&AffinePallas> for CamlGPallas {
    fn from(point: &AffinePallas) -> Self {
        if point.infinity {
            Self::Infinity
        } else {
            Self::Finite((point.x, point.y))
        }
    }
}

impl From<CamlGPallas> for AffinePallas {
    fn from(camlg: CamlGPallas) -> Self {
        match camlg {
            CamlGPallas::Infinity => AffinePallas::zero(),
            CamlGPallas::Finite((x, y)) => AffinePallas::new(x, y, false),
        }
    }
}

impl From<&CamlGPallas> for AffinePallas {
    fn from(camlg: &CamlGPallas) -> Self {
        match camlg {
            CamlGroupAffine::Infinity => AffinePallas::zero(),
            CamlGroupAffine::Finite((x, y)) => AffinePallas::new(*x, *y, false),
        }
    }
}
