use ark_ec::{AffineCurve, ProjectiveCurve};
use ark_ff::UniformRand;
use paste::paste;
use rand::rngs::StdRng;

use wasm_bindgen::prelude::*;

macro_rules! impl_projective {
    ($name: ident,
     $GroupProjective: ty,
     $CamlG: ty,
     $CamlScalarField: ty,
     $BaseField: ty,
     $CamlBaseField: ty,
     $Projective: ty) => {

        paste! {
            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _one>]() -> $GroupProjective {
                $Projective::prime_subgroup_generator().into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _add>](
                x: &$GroupProjective,
                y: &$GroupProjective,
            ) -> $GroupProjective {
                x.as_ref() + y.as_ref()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _sub>](
                x: &$GroupProjective,
                y: &$GroupProjective,
            ) -> $GroupProjective {
                x.as_ref() - y.as_ref()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _negate>](
                x: &$GroupProjective,
            ) -> $GroupProjective {
                -(*x.as_ref())
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _double>](
                x: &$GroupProjective,
            ) -> $GroupProjective {
                x.as_ref().double().into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _scale>](
                x: &$GroupProjective,
                y: $CamlScalarField,
            ) -> $GroupProjective {
                let y: ark_ff::BigInteger256 = y.0.into();
                x.as_ref().mul(&y).into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _random>]() -> $GroupProjective {
                let rng = &mut rand::rngs::OsRng;
                let proj: $Projective = UniformRand::rand(rng);
                proj.into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _rng>](i: u32) -> $GroupProjective {
                // We only care about entropy here, so we force a conversion i32 -> u32.
                let i: u64 = (i as u32).into();
                let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
                let proj: $Projective = UniformRand::rand(&mut rng);
                proj.into()
            }

            #[wasm_bindgen]
            pub extern "C" fn [<caml_ $name:snake _endo_base>]() -> $CamlBaseField {
                let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
                endo_q.into()
            }

            #[wasm_bindgen]
            pub extern "C" fn [<caml_ $name:snake _endo_scalar>]() -> $CamlScalarField {
                let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
                endo_r.into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _to_affine>](
                x: &$GroupProjective
                ) -> $CamlG {
                x.as_ref().into_affine().into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _of_affine>](x: $CamlG) -> $GroupProjective {
                Into::<GAffine>::into(x).into_projective().into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _of_affine_coordinates>](x: $CamlBaseField, y: $CamlBaseField) -> $GroupProjective {
                let res = $Projective::new(x.into(), y.into(), <$BaseField as ark_ff::One>::one());
                res.into()
            }

            #[wasm_bindgen]
            pub fn [<caml_ $name:snake _affine_deep_copy>](x: $CamlG) -> $CamlG {
                x
            }
        }
    }
}

pub mod pallas {
    use super::*;
    use crate::arkworks::group_affine::WasmGPallas;
    use crate::arkworks::group_projective::WasmPallasGProjective;
    use crate::arkworks::pasta_fp::WasmPastaFp;
    use crate::arkworks::pasta_fq::WasmPastaFq;
    use mina_curves::pasta::{
        fp::Fp,
        pallas::{Affine as GAffine, Projective},
    };

    impl_projective!(
        pallas,
        WasmPallasGProjective,
        WasmGPallas,
        WasmPastaFq,
        Fp,
        WasmPastaFp,
        Projective
    );
}

pub mod vesta {
    use super::*;
    use crate::arkworks::group_affine::WasmGVesta;
    use crate::arkworks::group_projective::WasmVestaGProjective;
    use crate::arkworks::pasta_fp::WasmPastaFp;
    use crate::arkworks::pasta_fq::WasmPastaFq;
    use mina_curves::pasta::{
        fq::Fq,
        vesta::{Affine as GAffine, Projective},
    };

    impl_projective!(
        vesta,
        WasmVestaGProjective,
        WasmGVesta,
        WasmPastaFp,
        Fq,
        WasmPastaFq,
        Projective
    );
}

/*
pub mod vesta {
    use super::*;
    use crate::arkworks::{CamlFp, CamlFq, CamlGVesta, CamlGroupProjectiveVesta};
    use mina_curves::pasta::{
        fq::Fq,
        vesta::{Affine as GAffine, Projective},
    };

    impl_projective!(
        vesta,
        CamlGroupProjectiveVesta,
        CamlGVesta,
        CamlFp,
        Fq,
        CamlFq,
        Projective
    );
}
*/
