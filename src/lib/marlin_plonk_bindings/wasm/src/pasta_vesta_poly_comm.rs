use wasm_bindgen::prelude::*;
use mina_curves::pasta::{vesta::Affine as GAffine};
use commitment_dlog::commitment::{PolyComm};
use crate::pasta_vesta::WasmVestaGAffine;
use crate::wasm_vector::WasmVector;
use std::convert::{Into, From};

#[wasm_bindgen]
pub struct WasmPastaVestaPolyComm {
    pub unshifted: *mut WasmVector<WasmVestaGAffine>, // wasm_bindgen requires something copy-able
    pub shifted: Option<WasmVestaGAffine>,
}

impl Drop for WasmPastaVestaPolyComm {
    fn drop(&mut self) {
        let _unshifted = unsafe { Box::from_raw(self.unshifted) };
    }
}

impl From<PolyComm<GAffine>> for WasmPastaVestaPolyComm {
    fn from(x: PolyComm<GAffine>) -> Self {
        let PolyComm {unshifted, shifted} = x;
        let unshifted: Vec<WasmVestaGAffine> =
            unshifted.into_iter().map(|x| x.into()).collect();
        WasmPastaVestaPolyComm {
            unshifted: Box::into_raw(Box::new(unshifted.into())),
            shifted: shifted.map(|x| x.into()),
        }
    }
}

impl From<&PolyComm<GAffine>> for WasmPastaVestaPolyComm {
    fn from(x: &PolyComm<GAffine>) -> Self {
        let unshifted: Vec<WasmVestaGAffine> =
            x.unshifted.iter().map(|x| x.into()).collect();
        WasmPastaVestaPolyComm {
            unshifted: Box::into_raw(Box::new(unshifted.into())),
            shifted: x.shifted.map(|x| x.into()),
        }
    }
}

impl From<WasmPastaVestaPolyComm> for PolyComm<GAffine> {
    fn from(x: WasmPastaVestaPolyComm) -> Self {
        let WasmPastaVestaPolyComm {unshifted, shifted} = x;
        let boxed_unshifted = unsafe { Box::from_raw(unshifted) };
        let unshifted: &Vec<WasmVestaGAffine> = boxed_unshifted.as_ref();
        PolyComm {
            unshifted: unshifted.iter().map(|x| x.into()).collect(),
            shifted: shifted.map(|x| x.into()),
        }
    }
}

impl From<&WasmPastaVestaPolyComm> for PolyComm<GAffine> {
    fn from(x: &WasmPastaVestaPolyComm) -> Self {
        let boxed_unshifted = unsafe { Box::from_raw(x.unshifted) };
        let unshifted: &Vec<WasmVestaGAffine> = boxed_unshifted.as_ref();
        let unshifted = unshifted.iter().map(|x| x.into()).collect();
        let _no_drop = Box::into_raw(boxed_unshifted);
        PolyComm {
            unshifted: unshifted,
            shifted: x.shifted.map(|x| x.into()),
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_vesta_poly_comm_unshifted(x: &mut WasmPastaVestaPolyComm) -> WasmVector<WasmVestaGAffine> {
    let old_unshifted = x.unshifted;
    // Clear the pointer to prevent a double-free
    x.unshifted = Box::into_raw(Box::new((vec![]).into()));
    unsafe { *Box::from_raw(old_unshifted) }
}

#[wasm_bindgen]
pub fn caml_pasta_vesta_poly_comm_set_unshifted(x: &mut WasmPastaVestaPolyComm, unshifted: WasmVector<WasmVestaGAffine>) {
    let _to_drop = unsafe { Box::from_raw(x.unshifted) };
    x.unshifted = Box::into_raw(Box::new(unshifted));
}

#[wasm_bindgen]
pub fn caml_pasta_vesta_poly_comm_empty() -> WasmPastaVestaPolyComm {
    WasmPastaVestaPolyComm {
        unshifted: Box::into_raw(Box::new((vec![]).into())),
        shifted: None,
    }
}
