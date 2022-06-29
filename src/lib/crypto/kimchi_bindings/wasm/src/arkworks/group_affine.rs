use crate::arkworks::pasta_fp::WasmPastaFp;
use crate::arkworks::pasta_fq::WasmPastaFq;
use mina_curves::pasta::{
    pallas::Affine as AffinePallas, pallas::G_GENERATOR_X as GeneratorPallasX,
    pallas::G_GENERATOR_Y as GeneratorPallasY, vesta::Affine as AffineVesta,
    vesta::G_GENERATOR_X as GeneratorVestaX, vesta::G_GENERATOR_Y as GeneratorVestaY,
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
        AffineVesta::new(point.x.into(), point.y.into(), point.infinity)
    }
}

impl From<&WasmGVesta> for AffineVesta {
    fn from(point: &WasmGVesta) -> Self {
        AffineVesta::new(point.x.into(), point.y.into(), point.infinity)
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
        AffinePallas::new(point.x.into(), point.y.into(), point.infinity)
    }
}

impl From<&WasmGPallas> for AffinePallas {
    fn from(point: &WasmGPallas) -> Self {
        AffinePallas::new(point.x.into(), point.y.into(), point.infinity)
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

/*
#[wasm_bindgen]
pub fn caml_pasta_pallas_one() -> WasmPallasGProjective {
    ProjectivePallas::prime_subgroup_generator().into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_add(
    x: &WasmPallasGProjective,
    y: &WasmPallasGProjective,
) -> WasmPallasGProjective {
    (**x + **y).into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_sub(
    x: &WasmPallasGProjective,
    y: &WasmPallasGProjective,
) -> WasmPallasGProjective {
    (**x - **y).into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_negate(x: &WasmPallasGProjective) -> WasmPallasGProjective {
    (-(**x)).into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_double(x: &WasmPallasGProjective) -> WasmPallasGProjective {
    (x.double()).into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_scale(x: &WasmPallasGProjective, y: WasmPastaFq) -> WasmPallasGProjective {
    (x.mul(y.0)).into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_random() -> WasmPallasGProjective {
    let rng = &mut rand_core::OsRng;
    WasmPallasGProjective(UniformRand::rand(rng))
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_rng(i: u32) -> WasmPallasGProjective {
    let i: u64 = i.into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    WasmPallasGProjective(UniformRand::rand(&mut rng))
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_endo_base() -> WasmPastaFp {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    WasmPastaFp(endo_q)
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_endo_scalar() -> WasmPastaFq {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    WasmPastaFq(endo_r)
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_to_affine(x: &WasmPallasGProjective) -> WasmPallasGAffine {
    Into::<&GProjective>::into(x).into_affine().into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_of_affine(x: &WasmPallasGAffine) -> WasmPallasGProjective {
    Into::<GAffine>::into(x).into_projective().into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_of_affine_coordinates(x: WasmPastaFp, y: WasmPastaFp) -> WasmPallasGProjective {
    GProjective::new(x.0, y.0, Fp::one()).into()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_affine_deep_copy(x: &WasmPallasGAffine) -> WasmPallasGAffine {
    x.clone()
}

#[wasm_bindgen]
pub fn caml_pasta_pallas_affine_one() -> WasmPallasGAffine {
    GAffine::prime_subgroup_generator().into()
}
*/
