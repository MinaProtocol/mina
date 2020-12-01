use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    tweedle::{
        dum::{Affine as GAffine, Projective as GProjective},
        fp::Fp,
        fq::Fq,
    },
    One, UniformRand, Zero,
};
use rand::rngs::StdRng;

use commitment_dlog::commitment::PolyComm;

#[ocaml::func]
pub fn caml_tweedle_dum_one() -> GProjective {
    GProjective::prime_subgroup_generator()
}

#[ocaml::func]
pub fn caml_tweedle_dum_add(x: ocaml::Pointer<GProjective>, y: ocaml::Pointer<GProjective>) -> GProjective {
    (*x.as_ref()) + (*y.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dum_sub(x: ocaml::Pointer<GProjective>, y: ocaml::Pointer<GProjective>) -> GProjective {
    (*x.as_ref()) - (*y.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dum_negate(x: ocaml::Pointer<GProjective>) -> GProjective {
    -(*x.as_ref())
}

#[ocaml::func]
pub fn caml_tweedle_dum_double(x: ocaml::Pointer<GProjective>) -> GProjective {
    x.as_ref().double()
}

#[ocaml::func]
pub fn caml_tweedle_dum_scale(x: ocaml::Pointer<GProjective>, y: Fq) -> GProjective {
    x.as_ref().mul(y)
}

#[ocaml::func]
pub fn caml_tweedle_dum_random() -> GProjective {
    let rng = &mut rand_core::OsRng;
    UniformRand::rand(rng)
}

#[ocaml::func]
pub fn caml_tweedle_dum_rng(i: ocaml::Int) -> GProjective {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    UniformRand::rand(&mut rng)
}

#[ocaml::func]
pub extern "C" fn caml_tweedle_dum_endo_base() -> Fp {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_q
}

#[ocaml::func]
pub extern "C" fn caml_tweedle_dum_endo_scalar() -> Fq {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    endo_r
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub enum CamlTweedleDumAffine<T> {
    Infinity,
    Finite((T, T)),
}

#[ocaml::func]
pub fn caml_tweedle_dum_to_affine(x: ocaml::Pointer<GProjective>) -> CamlTweedleDumAffine<Fp> {
    x.as_ref().into_affine().into()
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine(x: CamlTweedleDumAffine<Fp>) -> GProjective {
    Into::<GAffine>::into(x).into_projective()
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine_coordinates(x: Fp, y: Fp) -> GProjective {
    GProjective::new(x, y, Fp::one())
}

#[ocaml::func]
pub fn caml_tweedle_dum_affine_deep_copy(x: CamlTweedleDumAffine<Fp>) -> CamlTweedleDumAffine<Fp> {
    x
}

impl From<GAffine> for CamlTweedleDumAffine<Fp> {
    fn from(p: GAffine) -> Self {
        if p.is_zero() {
            CamlTweedleDumAffine::Infinity
        } else {
            CamlTweedleDumAffine::Finite((p.x, p.y))
        }
    }
}

impl From<CamlTweedleDumAffine<Fp>> for GAffine {
    fn from(p: CamlTweedleDumAffine<Fp>) -> Self {
        match p {
            CamlTweedleDumAffine::Infinity => GAffine::zero(),
            CamlTweedleDumAffine::Finite((x, y)) => GAffine::new(x, y, false),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleDumPolyComm<T> {
    pub shifted: Option<CamlTweedleDumAffine<T>>,
    pub unshifted: Vec<CamlTweedleDumAffine<Fp>>,
}

impl From<PolyComm<GAffine>> for CamlTweedleDumPolyComm<Fp> {
    fn from(c: PolyComm<GAffine>) -> Self {
        CamlTweedleDumPolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlTweedleDumPolyComm<Fp>> for PolyComm<GAffine> {
    fn from(c: CamlTweedleDumPolyComm<Fp>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}
