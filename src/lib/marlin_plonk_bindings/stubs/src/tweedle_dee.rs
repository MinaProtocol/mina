use crate::caml_vector;
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
    x.as_ref().0.into_affine().into()
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine(x: CamlTweedleDeeAffine<CamlTweedleFqPtr>) -> CamlTweedleDee {
    CamlTweedleDee(Into::<GAffine>::into(x).into_projective())
}

#[ocaml::func]
pub fn caml_tweedle_dee_of_affine_coordinates(
    x: CamlTweedleFqPtr,
    y: CamlTweedleFqPtr,
) -> CamlTweedleDee {
    CamlTweedleDee(GProjective::new(x.as_ref().0, y.as_ref().0, Fq::one()))
}

impl From<GAffine> for CamlTweedleDeeAffine<CamlTweedleFq> {
    fn from(p: GAffine) -> Self {
        if p.is_zero() {
            CamlTweedleDeeAffine::Infinity
        } else {
            CamlTweedleDeeAffine::Finite((CamlTweedleFq(p.x), CamlTweedleFq(p.y)))
        }
    }
}

impl From<CamlTweedleDeeAffine<CamlTweedleFq>> for GAffine {
    fn from(p: CamlTweedleDeeAffine<CamlTweedleFq>) -> Self {
        match p {
            CamlTweedleDeeAffine::Infinity => GAffine::zero(),
            CamlTweedleDeeAffine::Finite((x, y)) => GAffine::new(x.0, y.0, false),
        }
    }
}

impl From<CamlTweedleDeeAffine<CamlTweedleFqPtr>> for GAffine {
    fn from(p: CamlTweedleDeeAffine<CamlTweedleFqPtr>) -> Self {
        match p {
            CamlTweedleDeeAffine::Infinity => GAffine::zero(),
            CamlTweedleDeeAffine::Finite((x, y)) => GAffine::new(x.as_ref().0, y.as_ref().0, false),
        }
    }
}

pub struct CamlTweedleDeeAffineVector(pub Vec<GAffine>);

unsafe impl ocaml::FromValue for CamlTweedleDeeAffineVector {
    fn from_value(value: ocaml::Value) -> Self {
        let vec = caml_vector::from_value_array::<CamlTweedleDeeAffine<CamlTweedleFqPtr>, _>(
            ocaml::FromValue::from_value(value),
        );
        CamlTweedleDeeAffineVector(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleDeeAffineVector {
    fn to_value(self: Self) -> ocaml::Value {
        caml_vector::to_array::<CamlTweedleDeeAffine<CamlTweedleFq>, _>(self.0).to_value()
    }
}

pub struct CamlTweedleDeeAffinePairVector(pub Vec<(GAffine, GAffine)>);

unsafe impl ocaml::FromValue for CamlTweedleDeeAffinePairVector {
    fn from_value(value: ocaml::Value) -> Self {
        let vec = caml_vector::from_array_(ocaml::FromValue::from_value(value), |value| {
            let (x1, x2): (
                CamlTweedleDeeAffine<CamlTweedleFqPtr>,
                CamlTweedleDeeAffine<CamlTweedleFqPtr>,
            ) = ocaml::FromValue::from_value(value);
            (x1.into(), x2.into())
        });
        CamlTweedleDeeAffinePairVector(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleDeeAffinePairVector {
    fn to_value(self: Self) -> ocaml::Value {
        caml_vector::to_array_(self.0, |x| {
            let (x1, x2) = x;
            let x1: CamlTweedleDeeAffine<CamlTweedleFq> = x1.into();
            let x2: CamlTweedleDeeAffine<CamlTweedleFq> = x2.into();
            ocaml::ToValue::to_value((x1, x2))
        })
        .to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleDeePolyComm<T> {
    shifted: Option<CamlTweedleDeeAffine<T>>,
    unshifted: CamlTweedleDeeAffineVector,
}

impl From<PolyComm<GAffine>> for CamlTweedleDeePolyComm<CamlTweedleFq> {
    fn from(c: PolyComm<GAffine>) -> Self {
        CamlTweedleDeePolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: CamlTweedleDeeAffineVector(c.unshifted),
        }
    }
}

impl From<CamlTweedleDeePolyComm<CamlTweedleFq>> for PolyComm<GAffine> {
    fn from(c: CamlTweedleDeePolyComm<CamlTweedleFq>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.0,
        }
    }
}

impl From<CamlTweedleDeePolyComm<CamlTweedleFqPtr>> for PolyComm<GAffine> {
    fn from(c: CamlTweedleDeePolyComm<CamlTweedleFqPtr>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.0,
        }
    }
}

pub struct CamlTweedleDeePolyCommVector(pub Vec<PolyComm<GAffine>>);

unsafe impl ocaml::FromValue for CamlTweedleDeePolyCommVector {
    fn from_value(value: ocaml::Value) -> Self {
        let vec = caml_vector::from_value_array::<CamlTweedleDeePolyComm<CamlTweedleFqPtr>, _>(
            ocaml::FromValue::from_value(value),
        );
        CamlTweedleDeePolyCommVector(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleDeePolyCommVector {
    fn to_value(self: Self) -> ocaml::Value {
        caml_vector::to_array::<CamlTweedleDeePolyComm<CamlTweedleFq>, _>(self.0).to_value()
    }
}
