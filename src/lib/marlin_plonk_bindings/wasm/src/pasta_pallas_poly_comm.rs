use wasm_bindgen::prelude::*;
use mina_curves::pasta::{pallas::Affine as GAffine};
use commitment_dlog::commitment::{PolyComm};
use crate::pasta_pallas::WasmPallasGAffine;
use crate::wasm_vector::WasmVector;
use std::convert::{Into, From};

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaPallasPolyComm {
    #[wasm_bindgen(skip)]
    pub unshifted: WasmVector<WasmPallasGAffine>,
    pub shifted: Option<WasmPallasGAffine>,
}

#[wasm_bindgen]
impl WasmPastaPallasPolyComm {
    #[wasm_bindgen(constructor)]
    pub fn new(unshifted: WasmVector<WasmPallasGAffine>, shifted: Option<WasmPallasGAffine>) -> Self {
        WasmPastaPallasPolyComm { unshifted, shifted }
    }

    #[wasm_bindgen(getter)]
    pub fn unshifted(&self) -> WasmVector<WasmPallasGAffine> {
        self.unshifted.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_unshifted(&mut self, x: WasmVector<WasmPallasGAffine>) {
        self.unshifted = x
    }
}

impl From<PolyComm<GAffine>> for WasmPastaPallasPolyComm {
    fn from(x: PolyComm<GAffine>) -> Self {
        let PolyComm {unshifted, shifted} = x;
        let unshifted: Vec<WasmPallasGAffine> =
            unshifted.into_iter().map(|x| x.into()).collect();
        WasmPastaPallasPolyComm {
            unshifted: unshifted.into(),
            shifted: shifted.map(|x| x.into()),
        }
    }
}

impl From<&PolyComm<GAffine>> for WasmPastaPallasPolyComm {
    fn from(x: &PolyComm<GAffine>) -> Self {
        let unshifted: Vec<WasmPallasGAffine> =
            x.unshifted.iter().map(|x| x.into()).collect();
        WasmPastaPallasPolyComm {
            unshifted: unshifted.into(),
            shifted: x.shifted.map(|x| x.into()),
        }
    }
}

impl From<WasmPastaPallasPolyComm> for PolyComm<GAffine> {
    fn from(x: WasmPastaPallasPolyComm) -> Self {
        let WasmPastaPallasPolyComm {unshifted, shifted} = x;
        PolyComm {
            unshifted: (*unshifted).iter().map(|x| (*x).into()).collect(),
            shifted: shifted.map(|x| x.into()),
        }
    }
}

impl From<&WasmPastaPallasPolyComm> for PolyComm<GAffine> {
    fn from(x: &WasmPastaPallasPolyComm) -> Self {
        PolyComm {
            unshifted: x.unshifted.iter().map(|x| { (*x).into() }).collect(),
            shifted: x.shifted.map(|x| x.into()),
        }
    }
}
