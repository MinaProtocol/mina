use std::ops::Deref;

use mina_curves::pasta::{pallas::Affine as AffinePallas, vesta::Affine as AffineVesta};

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
