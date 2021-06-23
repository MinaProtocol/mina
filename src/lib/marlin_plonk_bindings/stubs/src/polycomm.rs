use commitment_dlog::commitment::PolyComm;
use mina_curves::pasta::{pallas, vesta};
use std::ops::Deref;

// there are two curves we commit with

type PolyComPallas = PolyComm<pallas::Affine>;
type PolyComVesta = PolyComm<vesta::Affine>;

// the first type of commitment

pub struct CamlPolyComPallas(pub PolyComPallas);

unsafe impl ocaml::FromValue for CamlPolyComPallas {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<PolyComm> = ocaml::FromValue::from_value(value);
        Self(x.as_ref().clone())
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

// the second type of commitment

pub struct CamlPolyComVesta(pub PolyComVesta);

unsafe impl ocaml::FromValue for CamlPolyComVesta {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<PolyComm> = ocaml::FromValue::from_value(value);
        Self(x.as_ref().clone())
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
