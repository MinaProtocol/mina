use crate::tweedle_fp::{CamlTweedleFp, CamlTweedleFpPtr};
use crate::tweedle_fq::{CamlTweedleFq, CamlTweedleFqPtr};
use algebra::{
    curves::{AffineCurve, ProjectiveCurve},
    tweedle::{
        dum::{Affine as GAffine, Projective as GProjective},
        fp::Fp,
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

#[ocaml::func]
pub extern "C" fn caml_tweedle_dum_endo_base() -> CamlTweedleFp {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    CamlTweedleFp(endo_q)
}

#[ocaml::func]
pub extern "C" fn caml_tweedle_dum_endo_scalar() -> CamlTweedleFq {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    CamlTweedleFq(endo_r)
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub enum CamlTweedleDumAffine<T> {
    Infinity,
    Finite((T, T)),
}

#[ocaml::func]
pub fn caml_tweedle_dum_to_affine(x: CamlTweedleDumPtr) -> CamlTweedleDumAffine<CamlTweedleFp> {
    x.as_ref().0.into_affine().into()
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine(x: CamlTweedleDumAffine<CamlTweedleFpPtr>) -> CamlTweedleDum {
    CamlTweedleDum(Into::<GAffine>::into(x).into_projective())
}

#[ocaml::func]
pub fn caml_tweedle_dum_of_affine_coordinates(
    x: CamlTweedleFpPtr,
    y: CamlTweedleFpPtr,
) -> CamlTweedleDum {
    CamlTweedleDum(GProjective::new(x.as_ref().0, y.as_ref().0, Fp::one()))
}

impl From<GAffine> for CamlTweedleDumAffine<CamlTweedleFp> {
    fn from(p: GAffine) -> Self {
        if p.is_zero() {
            CamlTweedleDumAffine::Infinity
        } else {
            CamlTweedleDumAffine::Finite((CamlTweedleFp(p.x), CamlTweedleFp(p.y)))
        }
    }
}

impl From<CamlTweedleDumAffine<CamlTweedleFp>> for GAffine {
    fn from(p: CamlTweedleDumAffine<CamlTweedleFp>) -> Self {
        match p {
            CamlTweedleDumAffine::Infinity => GAffine::zero(),
            CamlTweedleDumAffine::Finite((x, y)) => GAffine::new(x.0, y.0, false),
        }
    }
}

impl From<CamlTweedleDumAffine<CamlTweedleFpPtr>> for GAffine {
    fn from(p: CamlTweedleDumAffine<CamlTweedleFpPtr>) -> Self {
        match p {
            CamlTweedleDumAffine::Infinity => GAffine::zero(),
            CamlTweedleDumAffine::Finite((x, y)) => GAffine::new(x.as_ref().0, y.as_ref().0, false),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleDumPolyComm<T> {
    shifted: Option<CamlTweedleDumAffine<T>>,
    unshifted: Vec<CamlTweedleDumAffine<CamlTweedleFp>>,
}

impl From<PolyComm<GAffine>> for CamlTweedleDumPolyComm<CamlTweedleFp> {
    fn from(c: PolyComm<GAffine>) -> Self {
        CamlTweedleDumPolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlTweedleDumPolyComm<CamlTweedleFp>> for PolyComm<GAffine> {
    fn from(c: CamlTweedleDumPolyComm<CamlTweedleFp>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}

impl From<CamlTweedleDumPolyComm<CamlTweedleFpPtr>> for PolyComm<GAffine> {
    fn from(c: CamlTweedleDumPolyComm<CamlTweedleFpPtr>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.into_iter().map(From::from).collect(),
        }
    }
}
