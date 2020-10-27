use crate::tweedle_fp::CamlTweedleFpPtr;
use crate::tweedle_fq::{CamlTweedleFq, CamlTweedleFqPtr};
use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    tweedle::{
        dee::{Affine as GAffine, Projective as GProjective},
        fq::Fq,
    },
    One, UniformRand, Zero,
};
use rand::rngs::StdRng;

/* Projective representation is raw bytes on the OCaml heap. */

pub struct CamlTweedleDee(pub GProjective);
pub type CamlTweedleDeePtr = ocaml::Pointer<CamlTweedleDee>;

ocaml::custom!(CamlTweedleDee);

#[ocaml::func]
pub fn caml_tweedle_dee_one() -> CamlTweedleDee {
    CamlTweedleDee(GProjective::prime_subgroup_generator())
}

#[ocaml::func]
pub fn caml_tweedle_dee_add(x: CamlTweedleDeePtr, y: CamlTweedleDeePtr) -> CamlTweedleDee {
    CamlTweedleDee(x.as_ref().0 + y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_dee_sub(x: CamlTweedleDeePtr, y: CamlTweedleDeePtr) -> CamlTweedleDee {
    CamlTweedleDee(x.as_ref().0 - y.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_dee_negate(x: CamlTweedleDeePtr) -> CamlTweedleDee {
    CamlTweedleDee(-x.as_ref().0)
}

#[ocaml::func]
pub fn caml_tweedle_dee_double(x: CamlTweedleDeePtr) -> CamlTweedleDee {
    CamlTweedleDee(x.as_ref().0.double())
}

#[ocaml::func]
pub fn caml_tweedle_dee_scale(x: CamlTweedleDeePtr, y: CamlTweedleFpPtr) -> CamlTweedleDee {
    CamlTweedleDee(x.as_ref().0.mul(y.as_ref().0))
}

#[ocaml::func]
pub fn caml_tweedle_dee_random() -> CamlTweedleDee {
    let rng = &mut rand_core::OsRng;
    CamlTweedleDee(UniformRand::rand(rng))
}

#[ocaml::func]
pub fn caml_tweedle_dee_rng(i: ocaml::Int) -> CamlTweedleDee {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    CamlTweedleDee(UniformRand::rand(&mut rng))
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub enum CamlTweedleDeeAffine<T> {
    Infinity,
    Finite((T, T)),
}

#[ocaml::func]
pub fn caml_tweedle_dee_to_affine(x: CamlTweedleDeePtr) -> CamlTweedleDeeAffine<CamlTweedleFq> {
    let p = x.as_ref().0.into_affine();
    if p.is_zero() {
        CamlTweedleDeeAffine::Infinity
    } else {
        CamlTweedleDeeAffine::Finite((CamlTweedleFq(p.x), CamlTweedleFq(p.y)))
    }
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine(x: CamlTweedleDeeAffine<CamlTweedleFqPtr>) -> CamlTweedleDee {
    match x {
        CamlTweedleDeeAffine::Infinity => CamlTweedleDee(GAffine::zero().into_projective()),
        CamlTweedleDeeAffine::Finite((x, y)) => {
            CamlTweedleDee(GAffine::new(x.as_ref().0, y.as_ref().0, false).into_projective())
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine_coordinates(
    x: CamlTweedleFqPtr,
    y: CamlTweedleFqPtr,
) -> CamlTweedleDee {
    CamlTweedleDee(GProjective::new(x.as_ref().0, y.as_ref().0, Fq::one()))
}
