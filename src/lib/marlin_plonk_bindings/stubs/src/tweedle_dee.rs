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

#[ocaml::func]
pub fn caml_tweedle_dee_one() -> GProjective {
    GProjective::prime_subgroup_generator()
}

#[ocaml::func]
pub fn caml_tweedle_dee_add(x: ocaml::Pointer<GProjective>, y: ocaml::Pointer<GProjective>) -> GProjective {
    (*x.as_ref()) + (*y.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dee_sub(x: ocaml::Pointer<GProjective>, y: ocaml::Pointer<GProjective>) -> GProjective {
    (*x.as_ref()) - (*y.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dee_negate(x: ocaml::Pointer<GProjective>) -> GProjective {
    -(*x.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dee_double(x: ocaml::Pointer<GProjective>) -> GProjective {
    x.as_ref().double()
}

#[ocaml::func]
pub fn caml_tweedle_dee_scale(x: ocaml::Pointer<GProjective>, y: Fp) -> GProjective {
    x.as_ref().mul(y)
}

#[ocaml::func]
pub fn caml_tweedle_dee_random() -> GProjective {
    let rng = &mut rand_core::OsRng;
    UniformRand::rand(rng)
}

#[ocaml::func]
pub fn caml_tweedle_dee_rng(i: ocaml::Int) -> GProjective {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    UniformRand::rand(&mut rng)
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
pub fn caml_tweedle_dee_to_affine(x: ocaml::Pointer<GProjective>) -> CamlTweedleDeeAffine<Fq> {
    x.as_ref().into_affine().into()
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine(x: CamlTweedleDeeAffine<Fq>) -> GProjective {
    Into::<GAffine>::into(x).into_projective()
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine_coordinates(x: Fq, y: Fq) -> GProjective {
    GProjective::new(x, y, Fq::one())
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
