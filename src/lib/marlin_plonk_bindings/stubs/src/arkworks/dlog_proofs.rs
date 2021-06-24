use mina_curves::pasta::{pallas, vesta};
use plonk_protocol_dlog::prover::ProverProof as DlogProof;
use std::ops::Deref;

// there are two curves we prove with

type DlogProofPallas = DlogProof<pallas::Affine>;
type DlogProofVesta = DlogProof<vesta::Affine>;

// the first type

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

impl Deref for CamlDlogProofPallas {
    type Target = DlogProofPallas;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// the second type

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

impl Deref for CamlDlogProofVesta {
    type Target = DlogProofVesta;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
