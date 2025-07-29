use crate::{pasta_fp::WasmPastaFp, pasta_fq::WasmPastaFq};
use mina_curves::pasta::{
    curves::{
        pallas::{G_GENERATOR_X as GeneratorPallasX, G_GENERATOR_Y as GeneratorPallasY},
        vesta::{G_GENERATOR_X as GeneratorVestaX, G_GENERATOR_Y as GeneratorVestaY},
    },
    Pallas as AffinePallas, Vesta as AffineVesta,
};
use wasm_bindgen::prelude::*;

//
// handy types
//

#[wasm_bindgen]
#[derive(Clone, Copy, Debug)]
pub struct WasmGPallas {
    pub x: WasmPastaFp,
    pub y: WasmPastaFp,
    pub infinity: bool,
}

#[wasm_bindgen]
#[derive(Clone, Copy, Debug)]
pub struct WasmGVesta {
    pub x: WasmPastaFq,
    pub y: WasmPastaFq,
    pub infinity: bool,
}

// Conversions from/to AffineVesta

impl From<AffineVesta> for WasmGVesta {
    fn from(point: AffineVesta) -> Self {
        WasmGVesta {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

impl From<&AffineVesta> for WasmGVesta {
    fn from(point: &AffineVesta) -> Self {
        WasmGVesta {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

impl From<WasmGVesta> for AffineVesta {
    fn from(point: WasmGVesta) -> Self {
        AffineVesta {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

impl From<&WasmGVesta> for AffineVesta {
    fn from(point: &WasmGVesta) -> Self {
        AffineVesta {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

// Conversion from/to AffinePallas

impl From<AffinePallas> for WasmGPallas {
    fn from(point: AffinePallas) -> Self {
        WasmGPallas {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

impl From<&AffinePallas> for WasmGPallas {
    fn from(point: &AffinePallas) -> Self {
        WasmGPallas {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

impl From<WasmGPallas> for AffinePallas {
    fn from(point: WasmGPallas) -> Self {
        AffinePallas {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

impl From<&WasmGPallas> for AffinePallas {
    fn from(point: &WasmGPallas) -> Self {
        AffinePallas {
            x: point.x.into(),
            y: point.y.into(),
            infinity: point.infinity,
        }
    }
}

#[wasm_bindgen]
pub fn caml_pallas_affine_one() -> WasmGPallas {
    WasmGPallas {
        x: WasmPastaFp::from(GeneratorPallasX),
        y: WasmPastaFp::from(GeneratorPallasY),
        infinity: false,
    }
}

#[wasm_bindgen]
pub fn caml_vesta_affine_one() -> WasmGVesta {
    WasmGVesta {
        x: WasmPastaFq::from(GeneratorVestaX),
        y: WasmPastaFq::from(GeneratorVestaY),
        infinity: false,
    }
}
