use std::ops::{Add, Deref, Neg, Sub};

use mina_curves::bn254::curve::ProjectiveBn254;
use mina_curves::pasta::curves::{pallas::ProjectivePallas, vesta::ProjectiveVesta};

// Pallas

#[derive(Clone, Copy, ocaml_gen::CustomType)]
pub struct CamlGroupProjectivePallas(pub ProjectivePallas);

unsafe impl<'a> ocaml::FromValue<'a> for CamlGroupProjectivePallas {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        *x.as_ref()
    }
}

impl CamlGroupProjectivePallas {
    unsafe extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        let ptr = v.as_pointer::<Self>();
        ptr.drop_in_place()
    }
}

ocaml::custom!(CamlGroupProjectivePallas {
    finalize: CamlGroupProjectivePallas::caml_pointer_finalize,
});

impl Deref for CamlGroupProjectivePallas {
    type Target = ProjectivePallas;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// Handy implementations

impl From<ProjectivePallas> for CamlGroupProjectivePallas {
    fn from(x: ProjectivePallas) -> Self {
        CamlGroupProjectivePallas(x)
    }
}

impl From<&ProjectivePallas> for CamlGroupProjectivePallas {
    fn from(x: &ProjectivePallas) -> Self {
        CamlGroupProjectivePallas(*x)
    }
}

impl From<CamlGroupProjectivePallas> for ProjectivePallas {
    fn from(x: CamlGroupProjectivePallas) -> Self {
        x.0
    }
}

impl From<&CamlGroupProjectivePallas> for ProjectivePallas {
    fn from(x: &CamlGroupProjectivePallas) -> Self {
        x.0
    }
}

impl Add for CamlGroupProjectivePallas {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}

impl Add for &CamlGroupProjectivePallas {
    type Output = CamlGroupProjectivePallas;

    fn add(self, other: Self) -> Self::Output {
        CamlGroupProjectivePallas(self.0 + other.0)
    }
}

impl Sub for CamlGroupProjectivePallas {
    type Output = CamlGroupProjectivePallas;

    fn sub(self, other: Self) -> Self::Output {
        CamlGroupProjectivePallas(self.0 - other.0)
    }
}

impl Sub for &CamlGroupProjectivePallas {
    type Output = CamlGroupProjectivePallas;

    fn sub(self, other: Self) -> Self::Output {
        CamlGroupProjectivePallas(self.0 - other.0)
    }
}

impl Neg for CamlGroupProjectivePallas {
    type Output = CamlGroupProjectivePallas;

    fn neg(self) -> Self::Output {
        CamlGroupProjectivePallas(-self.0)
    }
}

impl Neg for &CamlGroupProjectivePallas {
    type Output = CamlGroupProjectivePallas;

    fn neg(self) -> Self::Output {
        CamlGroupProjectivePallas(-self.0)
    }
}

// Vesta

#[derive(Clone, Copy, ocaml_gen::CustomType)]
pub struct CamlGroupProjectiveVesta(pub ProjectiveVesta);

unsafe impl<'a> ocaml::FromValue<'a> for CamlGroupProjectiveVesta {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        *x.as_ref()
    }
}

impl CamlGroupProjectiveVesta {
    unsafe extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        let ptr = v.as_pointer::<Self>();
        ptr.drop_in_place()
    }
}

ocaml::custom!(CamlGroupProjectiveVesta {
    finalize: CamlGroupProjectiveVesta::caml_pointer_finalize,
});

impl Deref for CamlGroupProjectiveVesta {
    type Target = ProjectiveVesta;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//
// Handy implementations
//

impl From<ProjectiveVesta> for CamlGroupProjectiveVesta {
    fn from(x: ProjectiveVesta) -> Self {
        CamlGroupProjectiveVesta(x)
    }
}

impl From<&ProjectiveVesta> for CamlGroupProjectiveVesta {
    fn from(x: &ProjectiveVesta) -> Self {
        CamlGroupProjectiveVesta(*x)
    }
}

impl From<CamlGroupProjectiveVesta> for ProjectiveVesta {
    fn from(x: CamlGroupProjectiveVesta) -> Self {
        x.0
    }
}

impl From<&CamlGroupProjectiveVesta> for ProjectiveVesta {
    fn from(x: &CamlGroupProjectiveVesta) -> Self {
        x.0
    }
}

impl Add for CamlGroupProjectiveVesta {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}
impl Add for &CamlGroupProjectiveVesta {
    type Output = CamlGroupProjectiveVesta;

    fn add(self, other: Self) -> Self::Output {
        CamlGroupProjectiveVesta(self.0 + other.0)
    }
}

impl Sub for CamlGroupProjectiveVesta {
    type Output = CamlGroupProjectiveVesta;

    fn sub(self, other: Self) -> Self::Output {
        CamlGroupProjectiveVesta(self.0 - other.0)
    }
}

impl Sub for &CamlGroupProjectiveVesta {
    type Output = CamlGroupProjectiveVesta;

    fn sub(self, other: Self) -> Self::Output {
        CamlGroupProjectiveVesta(self.0 - other.0)
    }
}

impl Neg for CamlGroupProjectiveVesta {
    type Output = CamlGroupProjectiveVesta;

    fn neg(self) -> Self::Output {
        CamlGroupProjectiveVesta(-self.0)
    }
}

impl Neg for &CamlGroupProjectiveVesta {
    type Output = CamlGroupProjectiveVesta;

    fn neg(self) -> Self::Output {
        CamlGroupProjectiveVesta(-self.0)
    }
}

// Bn254

#[derive(Clone, Copy, ocaml_gen::CustomType)]
pub struct CamlGroupProjectiveBn254(pub ProjectiveBn254);

unsafe impl<'a> ocaml::FromValue<'a> for CamlGroupProjectiveBn254 {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        *x.as_ref()
    }
}

impl CamlGroupProjectiveBn254 {
    unsafe extern "C" fn caml_pointer_finalize(v: ocaml::Raw) {
        let ptr = v.as_pointer::<Self>();
        ptr.drop_in_place()
    }
}

ocaml::custom!(CamlGroupProjectiveBn254 {
    finalize: CamlGroupProjectiveBn254::caml_pointer_finalize,
});

impl Deref for CamlGroupProjectiveBn254 {
    type Target = ProjectiveBn254;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// Handy implementations

impl From<ProjectiveBn254> for CamlGroupProjectiveBn254 {
    fn from(x: ProjectiveBn254) -> Self {
        CamlGroupProjectiveBn254(x)
    }
}

impl From<&ProjectiveBn254> for CamlGroupProjectiveBn254 {
    fn from(x: &ProjectiveBn254) -> Self {
        CamlGroupProjectiveBn254(*x)
    }
}

impl From<CamlGroupProjectiveBn254> for ProjectiveBn254 {
    fn from(x: CamlGroupProjectiveBn254) -> Self {
        x.0
    }
}

impl From<&CamlGroupProjectiveBn254> for ProjectiveBn254 {
    fn from(x: &CamlGroupProjectiveBn254) -> Self {
        x.0
    }
}

impl Add for CamlGroupProjectiveBn254 {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}

impl Add for &CamlGroupProjectiveBn254 {
    type Output = CamlGroupProjectiveBn254;

    fn add(self, other: Self) -> Self::Output {
        CamlGroupProjectiveBn254(self.0 + other.0)
    }
}

impl Sub for CamlGroupProjectiveBn254 {
    type Output = CamlGroupProjectiveBn254;

    fn sub(self, other: Self) -> Self::Output {
        CamlGroupProjectiveBn254(self.0 - other.0)
    }
}

impl Sub for &CamlGroupProjectiveBn254 {
    type Output = CamlGroupProjectiveBn254;

    fn sub(self, other: Self) -> Self::Output {
        CamlGroupProjectiveBn254(self.0 - other.0)
    }
}

impl Neg for CamlGroupProjectiveBn254 {
    type Output = CamlGroupProjectiveBn254;

    fn neg(self) -> Self::Output {
        CamlGroupProjectiveBn254(-self.0)
    }
}

impl Neg for &CamlGroupProjectiveBn254 {
    type Output = CamlGroupProjectiveBn254;

    fn neg(self) -> Self::Output {
        CamlGroupProjectiveBn254(-self.0)
    }
}
