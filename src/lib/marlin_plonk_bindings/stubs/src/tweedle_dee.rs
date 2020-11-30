use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    tweedle::{
        dee::{Affine as GAffine, Projective as GProjective},
        fp::Fp,
        fq::Fq,
    },
    One, UniformRand, Zero,
};
use rand::rngs::StdRng;

use commitment_dlog::commitment::PolyComm;

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
pub fn caml_tweedle_dee_scale(x: CamlTweedleDeePtr, y: Fp) -> CamlTweedleDee {
    CamlTweedleDee(x.as_ref().0.mul(y))
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

#[ocaml::func]
pub extern "C" fn caml_tweedle_dee_endo_base() -> Fq {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_q
}

#[ocaml::func]
pub extern "C" fn caml_tweedle_dee_endo_scalar() -> Fp {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_r
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub enum CamlTweedleDeeAffine<T> {
    Infinity,
    Finite((T, T)),
}

#[ocaml::func]
pub fn caml_tweedle_dee_to_affine(x: CamlTweedleDeePtr) -> CamlTweedleDeeAffine<Fq> {
    x.as_ref().0.into_affine().into()
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine(x: CamlTweedleDeeAffine<Fq>) -> CamlTweedleDee {
    CamlTweedleDee(Into::<GAffine>::into(x).into_projective())
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine_coordinates(x: Fq, y: Fq) -> CamlTweedleDee {
    CamlTweedleDee(GProjective::new(x, y, Fq::one()))
}

#[ocaml::func]
pub fn caml_tweedle_dee_affine_deep_copy(x: CamlTweedleDeeAffine<Fq>) -> CamlTweedleDeeAffine<Fq> {
    x
}

impl From<GAffine> for CamlTweedleDeeAffine<Fq> {
    fn from(p: GAffine) -> Self {
        if p.is_zero() {
            CamlTweedleDeeAffine::Infinity
        } else {
            CamlTweedleDeeAffine::Finite((p.x, p.y))
        }
    }
}

impl From<CamlTweedleDeeAffine<Fq>> for GAffine {
    fn from(p: CamlTweedleDeeAffine<Fq>) -> Self {
        match p {
            CamlTweedleDeeAffine::Infinity => GAffine::zero(),
            CamlTweedleDeeAffine::Finite((x, y)) => GAffine::new(x, y, false),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleDeePolyComm<T> {
    pub shifted: Option<CamlTweedleDeeAffine<T>>,
    pub unshifted: Vec<CamlTweedleDeeAffine<Fq>>,
}

impl From<PolyComm<GAffine>> for CamlTweedleDeePolyComm<Fq> {
    fn from(c: PolyComm<GAffine>) -> Self {
        CamlTweedleDeePolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlTweedleDeePolyComm<Fq>> for PolyComm<GAffine> {
    fn from(c: CamlTweedleDeePolyComm<Fq>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}
