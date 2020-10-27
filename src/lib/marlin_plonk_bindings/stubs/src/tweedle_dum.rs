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

impl From<CamlTweedleDumAffine<CamlTweedleFpPtr>> for GAffine {
    fn from(p: CamlTweedleDumAffine<CamlTweedleFpPtr>) -> Self {
        match p {
            CamlTweedleDumAffine::Infinity => GAffine::zero(),
            CamlTweedleDumAffine::Finite((x, y)) => GAffine::new(x.as_ref().0, y.as_ref().0, false),
        }
    }
}

/* This is heinous, but we have type conversions to deal with, so :shrug: */

pub struct CamlTweedleDumAffineVector(pub Vec<GAffine>);

unsafe impl ocaml::FromValue for CamlTweedleDumAffineVector {
    fn from_value(value: ocaml::Value) -> Self {
        // Intepret as an array. This is free.
        let array: ocaml::Array<CamlTweedleDumAffine<CamlTweedleFpPtr>> =
            ocaml::FromValue::from_value(value);
        let len = array.len();
        let mut vec: Vec<GAffine> = Vec::with_capacity(len);
        for i in 0..len {
            // get_unchecked does the conversion to the caml representation, and then into brings
            // us back to a raw GAffine.
            unsafe {
                vec.push(array.get_unchecked(i).into());
            }
        }
        CamlTweedleDumAffineVector(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleDumAffineVector {
    fn to_value(self: Self) -> ocaml::Value {
        let len = self.0.len();
        // Manually allocate an OCaml array of the right size
        let mut array = ocaml::Array::alloc(len);
        let mut i = 0;
        for c in self.0.into_iter() {
            unsafe {
                // Construct the OCaml value for each element, then place it in the correct position in
                // the array.
                // Bounds checks are skipped because we know statically that the indices are in range.
                array.set_unchecked(
                    i,
                    Into::<CamlTweedleDumAffine<CamlTweedleFp>>::into(c).to_value(),
                );
            }
            i = i + 1;
        }
        array.to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleDumPolyComm<T> {
    shifted: Option<CamlTweedleDumAffine<T>>,
    unshifted: CamlTweedleDumAffineVector,
}

impl From<PolyComm<GAffine>> for CamlTweedleDumPolyComm<CamlTweedleFp> {
    fn from(c: PolyComm<GAffine>) -> Self {
        CamlTweedleDumPolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: CamlTweedleDumAffineVector(c.unshifted),
        }
    }
}

impl From<CamlTweedleDumPolyComm<CamlTweedleFpPtr>> for PolyComm<GAffine> {
    fn from(c: CamlTweedleDumPolyComm<CamlTweedleFpPtr>) -> Self {
        PolyComm {
            shifted: Option::map(c.shifted, Into::into),
            unshifted: c.unshifted.0,
        }
    }
}

/* This is also heinous, but we still have type conversions to deal with, so :shrug: */

pub struct CamlTweedleDumPolyCommVector(pub Vec<PolyComm<GAffine>>);

unsafe impl ocaml::FromValue for CamlTweedleDumPolyCommVector {
    fn from_value(value: ocaml::Value) -> Self {
        // Intepret as an array. This is free.
        let array: ocaml::Array<CamlTweedleDumPolyComm<CamlTweedleFpPtr>> =
            ocaml::FromValue::from_value(value);
        let len = array.len();
        let mut vec: Vec<PolyComm<GAffine>> = Vec::with_capacity(len);
        for i in 0..len {
            // get_unchecked does the conversion to the caml representation, and then into brings
            // us back to a raw GAffine.
            unsafe {
                vec.push(array.get_unchecked(i).into());
            }
        }
        CamlTweedleDumPolyCommVector(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleDumPolyCommVector {
    fn to_value(self: Self) -> ocaml::Value {
        let len = self.0.len();
        // Manually allocate an OCaml array of the right size
        let mut array = ocaml::Array::alloc(len);
        let mut i = 0;
        for c in self.0.into_iter() {
            unsafe {
                // Construct the OCaml value for each element, then place it in the correct position in
                // the array.
                // Bounds checks are skipped because we know statically that the indices are in range.
                array.set_unchecked(
                    i,
                    Into::<CamlTweedleDumPolyComm<CamlTweedleFp>>::into(c).to_value(),
                );
            }
            i = i + 1;
        }
        array.to_value()
    }
}
