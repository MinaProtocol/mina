use crate::tweedle_fp::{CamlTweedleFp, CamlTweedleFpPtr};
use crate::tweedle_fq::CamlTweedleFqPtr;
use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    tweedle::{
        dum::{Affine as GAffine, Projective as GProjective},
        fp::Fp,
    },
    One, UniformRand, Zero,
};
use rand::rngs::StdRng;

/* Projective representation is raw bytes on the OCaml heap. */

pub struct CamlTweedleDum(pub GProjective);
pub type CamlTweedleDumPtr = ocaml::Pointer<CamlTweedleDum>;

ocaml::custom!(CamlTweedleDum);

#[ocaml::func]
pub fn caml_tweedle_dum_one() -> CamlTweedleDum {
    CamlTweedleDum(GProjective::prime_subgroup_generator())
}

#[ocaml::func]
pub fn caml_tweedle_dum_add(x: CamlTweedleDumPtr, y: CamlTweedleDumPtr) -> CamlTweedleDum {
    CamlTweedleDum(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_dum_sub(x: CamlTweedleDumPtr, y: CamlTweedleDumPtr) -> CamlTweedleDum {
    CamlTweedleDum(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_dum_negate(x: CamlTweedleDumPtr) -> CamlTweedleDum {
    CamlTweedleDum(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_dum_double(x: CamlTweedleDumPtr) -> CamlTweedleDum {
    CamlTweedleDum(x.as_ref().0.double())
}

#[ocaml::func]
pub fn caml_tweedle_dum_scale(x: CamlTweedleDumPtr, y: CamlTweedleFqPtr) -> CamlTweedleDum {
    CamlTweedleDum(x.as_ref().0.mul(y.as_ref().0))
}

#[ocaml::func]
pub fn caml_tweedle_dum_random() -> CamlTweedleDum {
    let rng = &mut rand_core::OsRng;
    CamlTweedleDum(UniformRand::rand(rng))
}

#[ocaml::func]
pub fn caml_tweedle_dum_rng(i: ocaml::Int) -> CamlTweedleDum {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlTweedleDum(UniformRand::rand(&mut rng))
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub enum CamlTweedleDumAffine<T> {
    Infinity,
    Finite((T, T)),
}

#[ocaml::func]
pub fn caml_tweedle_dum_to_affine(x: CamlTweedleDumPtr) -> CamlTweedleDumAffine<CamlTweedleFp> {
    let p = x.as_ref().0.into_affine();
    if p.is_zero() {
        CamlTweedleDumAffine::Infinity
    } else {
        CamlTweedleDumAffine::Finite((CamlTweedleFp(p.x), CamlTweedleFp(p.y)))
    }
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine(x: CamlTweedleDumAffine<CamlTweedleFpPtr>) -> CamlTweedleDum {
    match x {
        CamlTweedleDumAffine::Infinity => CamlTweedleDum(GAffine::zero().into_projective()),
        CamlTweedleDumAffine::Finite((x, y)) => {
            CamlTweedleDum(GAffine::new(x.as_ref().0, y.as_ref().0, false).into_projective())
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine_coordinates(
    x: CamlTweedleFpPtr,
    y: CamlTweedleFpPtr,
) -> CamlTweedleDum {
    CamlTweedleDum(GProjective::new(x.as_ref().0, y.as_ref().0, Fp::one()))
}
