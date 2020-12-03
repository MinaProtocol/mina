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
pub fn caml_tweedle_dum_scale(x: CamlTweedleDumPtr, y: Fq) -> CamlTweedleDum {
    CamlTweedleDum(x.as_ref().0.mul(y))
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
pub fn caml_tweedle_dum_to_affine(x: CamlTweedleDumPtr) -> CamlTweedleDumAffine<Fp> {
    x.as_ref().0.into_affine().into()
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine(x: CamlTweedleDumAffine<Fp>) -> CamlTweedleDum {
    CamlTweedleDum(Into::<GAffine>::into(x).into_projective())
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine_coordinates(
    x: Fp,
    y: Fp,
) -> CamlTweedleDum {
    CamlTweedleDum(GProjective::new(x, y, Fp::one()))
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
    shifted: Option<CamlTweedleDumAffine<T>>,
    unshifted: Vec<CamlTweedleDumAffine<Fp>>,
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
