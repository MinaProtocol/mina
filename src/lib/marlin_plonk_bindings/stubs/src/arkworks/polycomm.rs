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

/*

//
// Pallas
//

#[derive(Clone)]
pub struct CamlPolyCommPallas(pub PolyCommPallas);

unsafe impl ocaml::FromValue for CamlPolyCommPallas {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlPolyCommPallas {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlPolyCommPallas {
    finalize: CamlPolyCommPallas::caml_pointer_finalize,
});

impl Deref for CamlPolyCommPallas {
    type Target = PolyCommPallas;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// handy converter

impl From<PolyCommPallas> for CamlPolyCommPallas {
    fn from(x: PolyCommPallas) -> Self {
        Self(x)
    }
}

impl From<&PolyCommPallas> for CamlPolyCommPallas {
    fn from(x: &PolyCommPallas) -> Self {
        Self(x.clone())
    }
}

impl Into<PolyCommPallas> for CamlPolyCommPallas {
    fn into(self) -> PolyCommPallas {
        self.0
    }
}

impl Into<PolyCommPallas> for &CamlPolyCommPallas {
    fn into(self) -> PolyCommPallas {
        self.0.clone()
    }
}

//
// Vesta
//

#[derive(Clone)]
pub struct CamlPolyCommVesta(pub PolyCommVesta);

unsafe impl ocaml::FromValue for CamlPolyCommVesta {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlPolyCommVesta {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlPolyCommVesta {
    finalize: CamlPolyCommVesta::caml_pointer_finalize,
});

impl Deref for CamlPolyCommVesta {
    type Target = PolyCommVesta;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// handy converter

impl From<PolyCommVesta> for CamlPolyCommVesta {
    fn from(x: PolyCommVesta) -> Self {
        Self(x)
    }
}

impl From<&PolyCommVesta> for CamlPolyCommVesta {
    fn from(x: &PolyCommVesta) -> Self {
        Self(x.clone())
    }
}

impl Into<PolyCommVesta> for CamlPolyCommVesta {
    fn into(self) -> PolyCommVesta {
        self.0
    }
}

impl Into<PolyCommVesta> for &CamlPolyCommVesta {
    fn into(self) -> PolyCommVesta {
        self.0.clone()
    }
}

*/
