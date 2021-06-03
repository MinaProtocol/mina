use mina_curves::pasta::{Fp, Fq};
use plonk_circuits::scalars::RandomOracles;
use std::ops::Deref;

// This is defined on two fields

// Fq

#[derive(Clone)]
pub struct CamlRandomOraclesFq(pub RandomOracles<Fq>);

unsafe impl ocaml::FromValue for CamlRandomOraclesFq {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlRandomOraclesFq {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlRandomOraclesFq {
    finalize: CamlRandomOraclesFq::caml_pointer_finalize,
});

// Handy implementations

impl From<RandomOracles<Fq>> for CamlRandomOraclesFq {
    fn from(x: RandomOracles<Fq>) -> Self {
        CamlRandomOraclesFq(x)
    }
}

impl From<&RandomOracles<Fq>> for CamlRandomOraclesFq {
    fn from(x: &RandomOracles<Fq>) -> Self {
        CamlRandomOraclesFq(x.clone())
    }
}

impl Into<RandomOracles<Fq>> for CamlRandomOraclesFq {
    fn into(self) -> RandomOracles<Fq> {
        self.0
    }
}

impl Into<RandomOracles<Fq>> for &CamlRandomOraclesFq {
    fn into(self) -> RandomOracles<Fq> {
        self.0.clone()
    }
}

impl Deref for CamlRandomOraclesFq {
    type Target = RandomOracles<Fq>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// Fp

#[derive(Clone)]
pub struct CamlRandomOraclesFp(pub RandomOracles<Fp>);

unsafe impl ocaml::FromValue for CamlRandomOraclesFp {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

impl CamlRandomOraclesFp {
    extern "C" fn caml_pointer_finalize(v: ocaml::Value) {
        let v: ocaml::Pointer<Self> = ocaml::FromValue::from_value(v);
        unsafe {
            v.drop_in_place();
        }
    }
}

ocaml::custom!(CamlRandomOraclesFp {
    finalize: CamlRandomOraclesFp::caml_pointer_finalize,
});

// Handy implementations

impl From<RandomOracles<Fp>> for CamlRandomOraclesFp {
    fn from(x: RandomOracles<Fp>) -> Self {
        CamlRandomOraclesFp(x)
    }
}

impl From<&RandomOracles<Fp>> for CamlRandomOraclesFp {
    fn from(x: &RandomOracles<Fp>) -> Self {
        CamlRandomOraclesFp(x.clone())
    }
}

impl Into<RandomOracles<Fp>> for CamlRandomOraclesFp {
    fn into(self) -> RandomOracles<Fp> {
        self.0
    }
}

impl Into<RandomOracles<Fp>> for &CamlRandomOraclesFp {
    fn into(self) -> RandomOracles<Fp> {
        self.0.clone()
    }
}

impl Deref for CamlRandomOraclesFp {
    type Target = RandomOracles<Fp>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
