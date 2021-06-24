use mina_curves::pasta::{pallas, vesta};
use plonk_protocol_dlog::prover::ProverProof as DlogProof;
use std::ops::Deref;

// there are two curves we prove with

type DlogProofPallas = DlogProof<pallas::Affine>;
type DlogProofVesta = DlogProof<vesta::Affine>;

// Pallas

#[derive(Clone)]
pub struct CamlDlogProofPallas(pub DlogProofPallas);

unsafe impl ocaml::FromValue for CamlDlogProofPallas {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlDlogProofPallas {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlDlogProofPallas {
    finalize: CamlDlogProofPallas::caml_pointer_finalize,
});

// handy implementations

impl From<DlogProofPallas> for CamlDlogProofPallas {
    fn from(x: DlogProofPallas) -> Self {
        CamlDlogProofPallas(x)
    }
}

impl From<&DlogProofPallas> for CamlDlogProofPallas {
    fn from(x: &DlogProofPallas) -> Self {
        CamlDlogProofPallas(*x)
    }
}

impl Into<DlogProofPallas> for CamlDlogProofPallas {
    fn into(self) -> DlogProofPallas {
        self.0
    }
}

impl Into<DlogProofPallas> for &CamlDlogProofPallas {
    fn into(self) -> DlogProofPallas {
        self.0
    }
}
impl Deref for CamlDlogProofPallas {
    type Target = DlogProofPallas;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// Vesta

#[derive(Clone)]
pub struct CamlDlogProofVesta(pub DlogProofVesta);

unsafe impl ocaml::FromValue for CamlDlogProofVesta {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlDlogProofVesta {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlDlogProofVesta {
    finalize: CamlDlogProofVesta::caml_pointer_finalize,
});

// handy implementation

impl From<DlogProofVesta> for CamlDlogProofVesta {
    fn from(x: DlogProofVesta) -> Self {
        CamlDlogProofVesta(x)
    }
}

impl From<&DlogProofVesta> for CamlDlogProofVesta {
    fn from(x: &DlogProofVesta) -> Self {
        CamlDlogProofVesta(*x)
    }
}

impl Into<DlogProofVesta> for CamlDlogProofVesta {
    fn into(self) -> DlogProofVesta {
        self.0
    }
}

impl Into<DlogProofVesta> for &CamlDlogProofVesta {
    fn into(self) -> DlogProofVesta {
        self.0
    }
}

impl Deref for CamlDlogProofVesta {
    type Target = DlogProofVesta;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
