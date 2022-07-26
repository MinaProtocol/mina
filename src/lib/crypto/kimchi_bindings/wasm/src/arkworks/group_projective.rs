use std::ops::{Add, Deref, Neg, Sub};
use wasm_bindgen::prelude::*;

use mina_curves::pasta::{
    pallas::Projective as ProjectivePallas, vesta::Projective as ProjectiveVesta,
};

// Pallas
#[wasm_bindgen]
#[derive(Clone, Copy)]
pub struct WasmPallasGProjective(ProjectivePallas);

impl AsRef<WasmPallasGProjective> for WasmPallasGProjective {
    fn as_ref(&self) -> &WasmPallasGProjective {
        self
    }
}

impl Deref for WasmPallasGProjective {
    type Target = ProjectivePallas;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

// Handy implementations

impl From<ProjectivePallas> for WasmPallasGProjective {
    fn from(x: ProjectivePallas) -> Self {
        WasmPallasGProjective(x)
    }
}

impl From<&ProjectivePallas> for WasmPallasGProjective {
    fn from(x: &ProjectivePallas) -> Self {
        WasmPallasGProjective(*x)
    }
}

impl From<WasmPallasGProjective> for ProjectivePallas {
    fn from(x: WasmPallasGProjective) -> Self {
        x.0
    }
}

impl From<&WasmPallasGProjective> for ProjectivePallas {
    fn from(x: &WasmPallasGProjective) -> Self {
        x.0
    }
}

impl Add for WasmPallasGProjective {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}

impl Add for &WasmPallasGProjective {
    type Output = WasmPallasGProjective;

    fn add(self, other: Self) -> Self::Output {
        WasmPallasGProjective(self.0 + other.0)
    }
}

impl Sub for WasmPallasGProjective {
    type Output = WasmPallasGProjective;

    fn sub(self, other: Self) -> Self::Output {
        WasmPallasGProjective(self.0 - other.0)
    }
}

impl Sub for &WasmPallasGProjective {
    type Output = WasmPallasGProjective;

    fn sub(self, other: Self) -> Self::Output {
        WasmPallasGProjective(self.0 - other.0)
    }
}

impl Neg for WasmPallasGProjective {
    type Output = WasmPallasGProjective;

    fn neg(self) -> Self::Output {
        WasmPallasGProjective(-self.0)
    }
}

impl Neg for &WasmPallasGProjective {
    type Output = WasmPallasGProjective;

    fn neg(self) -> Self::Output {
        WasmPallasGProjective(-self.0)
    }
}

// Vesta

#[wasm_bindgen]
#[derive(Clone, Copy)]
pub struct WasmVestaGProjective(ProjectiveVesta);

impl AsRef<WasmVestaGProjective> for WasmVestaGProjective {
    fn as_ref(&self) -> &WasmVestaGProjective {
        self
    }
}

impl Deref for WasmVestaGProjective {
    type Target = ProjectiveVesta;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

//
// Handy implementations
//

impl From<ProjectiveVesta> for WasmVestaGProjective {
    fn from(x: ProjectiveVesta) -> Self {
        WasmVestaGProjective(x)
    }
}

impl From<&ProjectiveVesta> for WasmVestaGProjective {
    fn from(x: &ProjectiveVesta) -> Self {
        WasmVestaGProjective(*x)
    }
}

impl From<WasmVestaGProjective> for ProjectiveVesta {
    fn from(x: WasmVestaGProjective) -> Self {
        x.0
    }
}

impl From<&WasmVestaGProjective> for ProjectiveVesta {
    fn from(x: &WasmVestaGProjective) -> Self {
        x.0
    }
}

impl Add for WasmVestaGProjective {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self(self.0 + other.0)
    }
}
impl Add for &WasmVestaGProjective {
    type Output = WasmVestaGProjective;

    fn add(self, other: Self) -> Self::Output {
        WasmVestaGProjective(self.0 + other.0)
    }
}

impl Sub for WasmVestaGProjective {
    type Output = WasmVestaGProjective;

    fn sub(self, other: Self) -> Self::Output {
        WasmVestaGProjective(self.0 - other.0)
    }
}

impl Sub for &WasmVestaGProjective {
    type Output = WasmVestaGProjective;

    fn sub(self, other: Self) -> Self::Output {
        WasmVestaGProjective(self.0 - other.0)
    }
}

impl Neg for WasmVestaGProjective {
    type Output = WasmVestaGProjective;

    fn neg(self) -> Self::Output {
        WasmVestaGProjective(-self.0)
    }
}

impl Neg for &WasmVestaGProjective {
    type Output = WasmVestaGProjective;

    fn neg(self) -> Self::Output {
        WasmVestaGProjective(-self.0)
    }
}
