use wasm_bindgen::prelude::*;
use mina_curves::pasta::{vesta::Affine as GAffine};
use commitment_dlog::commitment::{PolyComm};
use crate::pasta_vesta::WasmVestaGAffine;
use crate::wasm_vector::WasmVector;
use std::convert::{Into, From};

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaVestaPolyComm {
    #[wasm_bindgen(skip)]
    pub unshifted: WasmVector<WasmVestaGAffine>,
    pub shifted: Option<WasmVestaGAffine>,
}

#[wasm_bindgen]
impl WasmPastaVestaPolyComm {
    #[wasm_bindgen(constructor)]
    pub fn new(unshifted: WasmVector<WasmVestaGAffine>, shifted: Option<WasmVestaGAffine>) -> Self {
        WasmPastaVestaPolyComm { unshifted, shifted }
    }

    #[wasm_bindgen(getter)]
    pub fn unshifted(&self) -> WasmVector<WasmVestaGAffine> {
        self.unshifted.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_unshifted(&mut self, x: WasmVector<WasmVestaGAffine>) {
        self.unshifted = x
    }
}

impl From<PolyComm<GAffine>> for WasmPastaVestaPolyComm {
    fn from(x: PolyComm<GAffine>) -> Self {
        let PolyComm {unshifted, shifted} = x;
        let unshifted: Vec<WasmVestaGAffine> =
            unshifted.into_iter().map(|x| x.into()).collect();
        WasmPastaVestaPolyComm {
            unshifted: unshifted.into(),
            shifted: shifted.map(|x| x.into()),
        }
    }
}

impl From<&PolyComm<GAffine>> for WasmPastaVestaPolyComm {
    fn from(x: &PolyComm<GAffine>) -> Self {
        let unshifted: Vec<WasmVestaGAffine> =
            x.unshifted.iter().map(|x| x.into()).collect();
        WasmPastaVestaPolyComm {
            unshifted: unshifted.into(),
            shifted: x.shifted.map(|x| x.into()),
        }
    }
}

impl From<WasmPastaVestaPolyComm> for PolyComm<GAffine> {
    fn from(x: WasmPastaVestaPolyComm) -> Self {
        let WasmPastaVestaPolyComm {unshifted, shifted} = x;
        PolyComm {
            unshifted: (*unshifted).iter().map(|x| { (*x).into() }).collect(),
            shifted: shifted.map(|x| x.into()),
        }
    }
}

impl From<&WasmPastaVestaPolyComm> for PolyComm<GAffine> {
    fn from(x: &WasmPastaVestaPolyComm) -> Self {
        PolyComm {
            unshifted: x.unshifted.iter().map(|x| { (*x).into() }).collect(),
            shifted: x.shifted.map(|x| x.into()),
        }
    }
}
