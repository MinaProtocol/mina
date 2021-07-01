use crate::arkworks::CamlGroupAffine;
use crate::arkworks::{CamlFp, CamlFq};
use commitment_dlog::commitment::PolyComm;
use mina_curves::pasta::{pallas, vesta};

// there are two curves we commit with

type PolyCommPallas = PolyComm<pallas::Affine>;
type PolyCommVesta = PolyComm<vesta::Affine>;

//
// Pallas
//

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPolyCommPallas {
    pub unshifted: Vec<CamlGroupAffine<CamlFp>>,
    pub shifted: Option<CamlGroupAffine<CamlFp>>,
}

// handy converter

impl From<PolyCommPallas> for CamlPolyCommPallas {
    fn from(x: PolyCommPallas) -> Self {
        Self {
            unshifted: x.unshifted.iter().map(Into::into).collect(),
            shifted: x.shifted.map(Into::into),
        }
    }
}

impl From<&PolyCommPallas> for CamlPolyCommPallas {
    fn from(x: &PolyCommPallas) -> Self {
        Self {
            unshifted: x.unshifted.iter().map(Into::into).collect(),
            shifted: x.shifted.map(Into::into),
        }
    }
}

impl Into<PolyCommPallas> for CamlPolyCommPallas {
    fn into(self) -> PolyCommPallas {
        PolyCommPallas {
            unshifted: self.unshifted.iter().map(Into::into).collect(),
            shifted: self.shifted.map(Into::into),
        }
    }
}

impl Into<PolyCommPallas> for &CamlPolyCommPallas {
    fn into(self) -> PolyCommPallas {
        PolyCommPallas {
            unshifted: self.unshifted.iter().map(Into::into).collect(),
            shifted: self.shifted.map(Into::into),
        }
    }
}

//
// Vesta
//

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPolyCommVesta {
    pub unshifted: Vec<CamlGroupAffine<CamlFq>>,
    pub shifted: Option<CamlGroupAffine<CamlFq>>,
}

// handy converter

impl From<PolyCommVesta> for CamlPolyCommVesta {
    fn from(x: PolyCommVesta) -> Self {
        Self {
            unshifted: x.unshifted.iter().map(Into::into).collect(),
            shifted: x.shifted.map(Into::into),
        }
    }
}

impl From<&PolyCommVesta> for CamlPolyCommVesta {
    fn from(x: &PolyCommVesta) -> Self {
        Self {
            unshifted: x.unshifted.iter().map(Into::into).collect(),
            shifted: x.shifted.map(Into::into),
        }
    }
}

impl Into<PolyCommVesta> for CamlPolyCommVesta {
    fn into(self) -> PolyCommVesta {
        PolyCommVesta {
            unshifted: self.unshifted.iter().map(Into::into).collect(),
            shifted: self.shifted.map(Into::into),
        }
    }
}

impl Into<PolyCommVesta> for &CamlPolyCommVesta {
    fn into(self) -> PolyCommVesta {
        PolyCommVesta {
            unshifted: self.unshifted.iter().map(Into::into).collect(),
            shifted: self.shifted.map(Into::into),
        }
    }
}
