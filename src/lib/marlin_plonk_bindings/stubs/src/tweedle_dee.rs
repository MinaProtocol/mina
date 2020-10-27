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

impl From<CamlTweedleDeeAffine<CamlTweedleFqPtr>> for GAffine {
    fn from(p: CamlTweedleDeeAffine<CamlTweedleFqPtr>) -> Self {
        match p {
            CamlTweedleDeeAffine::Infinity => GAffine::zero(),
            CamlTweedleDeeAffine::Finite((x, y)) => GAffine::new(x.as_ref().0, y.as_ref().0, false),
        }
    }
}

/* This is heinous, but we have newtypes to deal with, so :shrug: */

pub struct CamlTweedleDeeAffineVector(pub Vec<GAffine>);

unsafe impl ocaml::FromValue for CamlTweedleDeeAffineVector {
    fn from_value(value: ocaml::Value) -> Self {
        // Intepret as an array. This is free.
        let array: ocaml::Array<CamlTweedleDeeAffine<CamlTweedleFqPtr>> =
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
        CamlTweedleDeeAffineVector(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleDeeAffineVector {
    fn to_value(self: Self) -> ocaml::Value {
        let len = self.0.len();
        // Manually allocate an OCaml array of the right size
        let mut array = ocaml::Array::alloc(len);
        for i in 0..len {
            // Construct the OCaml value for each element, then place it in the correct position in
            // the array.
            // Bounds checks are skipped because we know statically that the indices are in range.
            unsafe {
                array.set_unchecked(
                    i,
                    Into::<CamlTweedleDeeAffine<CamlTweedleFq>>::into(*self.0.get_unchecked(i))
                        .to_value(),
                );
            }
        }
        array.to_value()
    }
}
