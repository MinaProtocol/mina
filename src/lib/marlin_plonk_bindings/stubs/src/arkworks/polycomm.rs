use commitment_dlog::commitment::PolyComm;
use mina_curves::pasta::{pallas, vesta};
use std::ops::Deref;

// there are two curves we commit with

type PolyComPallas = PolyComm<pallas::Affine>;
type PolyComVesta = PolyComm<vesta::Affine>;

// the first type of commitment

#[derive(Clone)]
pub struct CamlPolyComPallas(pub PolyComPallas);

unsafe impl ocaml::FromValue for CamlPolyComPallas {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlPolyComPallas {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlPolyComPallas {
    finalize: CamlPolyComPallas::caml_pointer_finalize,
});

impl Deref for CamlPolyComPallas {
    type Target = PolyComPallas;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// handy converter

impl From<PolyComPallas> for CamlPolyComPallas {
    fn from(x: PolyComPallas) -> Self {
        Self(x)
    }
}

impl From<&PolyComPallas> for CamlPolyComPallas {
    fn from(x: &PolyComPallas) -> Self {
        Self(x.clone())
    }
}

impl Into<PolyComPallas> for CamlPolyComPallas {
    fn into(self) -> PolyComPallas {
        self.0
    }
}

impl Into<PolyComPallas> for &CamlPolyComPallas {
    fn into(self) -> PolyComPallas {
        self.0.clone()
    }
}

// the second type of commitment

#[derive(Clone)]
pub struct CamlPolyComVesta(pub PolyComVesta);

unsafe impl ocaml::FromValue for CamlPolyComVesta {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlPolyComVesta {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlPolyComVesta {
    finalize: CamlPolyComVesta::caml_pointer_finalize,
});

impl Deref for CamlPolyComVesta {
    type Target = PolyComVesta;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// handy converter

impl From<PolyComVesta> for CamlPolyComVesta {
    fn from(x: PolyComVesta) -> Self {
        Self(x)
    }
}

impl From<&PolyComVesta> for CamlPolyComVesta {
    fn from(x: &PolyComVesta) -> Self {
        Self(x.clone())
    }
}

impl Into<PolyComVesta> for CamlPolyComVesta {
    fn into(self) -> PolyComVesta {
        self.0
    }
}

impl Into<PolyComVesta> for &CamlPolyComVesta {
    fn into(self) -> PolyComVesta {
        self.0.clone()
    }
}
