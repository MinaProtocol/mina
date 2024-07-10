#![cfg_attr(not(feature = "std"), no_std)]
#![warn(unused, future_incompatible, nonstandard_style, rust_2018_idioms)]
#![forbid(unsafe_code)]
#![allow(
    clippy::op_ref,
    clippy::suspicious_op_assign_impl,
    clippy::many_single_char_names
)]

#[macro_use]
extern crate derivative;

#[macro_use]
extern crate ark_std;

use crate::group::Group;
use ark_ff::{
    bytes::{FromBytes, ToBytes},
    fields::{Field, PrimeField, SquareRootField},
    UniformRand,
};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use ark_std::{
    fmt::{Debug, Display},
    hash::Hash,
    ops::{Add, AddAssign, MulAssign, Neg, Sub, SubAssign},
    vec::Vec,
};
use num_traits::Zero;
use zeroize::Zeroize;

pub mod models;
pub use self::models::*;

pub mod group;

pub mod msm;

pub mod wnaf;

pub trait PairingEngine: Sized + 'static + Copy + Debug + Sync + Send + Eq + PartialEq {
    /// This is the scalar field of the G1/G2 groups.
    type Fr: PrimeField + SquareRootField;

    /// The projective representation of an element in G1.
    type G1Projective: ProjectiveCurve<BaseField = Self::Fq, ScalarField = Self::Fr, Affine = Self::G1Affine>
        + From<Self::G1Affine>
        + Into<Self::G1Affine>
        + MulAssign<Self::Fr>; // needed due to https://github.com/rust-lang/rust/issues/69640

    /// The affine representation of an element in G1.
    type G1Affine: AffineCurve<BaseField = Self::Fq, ScalarField = Self::Fr, Projective = Self::G1Projective>
        + From<Self::G1Projective>
        + Into<Self::G1Projective>
        + Into<Self::G1Prepared>;

    /// A G1 element that has been preprocessed for use in a pairing.
    type G1Prepared: ToBytes + Default + Clone + Send + Sync + Debug + From<Self::G1Affine>;

    /// The projective representation of an element in G2.
    type G2Projective: ProjectiveCurve<BaseField = Self::Fqe, ScalarField = Self::Fr, Affine = Self::G2Affine>
        + From<Self::G2Affine>
        + Into<Self::G2Affine>
        + MulAssign<Self::Fr>; // needed due to https://github.com/rust-lang/rust/issues/69640

    /// The affine representation of an element in G2.
    type G2Affine: AffineCurve<BaseField = Self::Fqe, ScalarField = Self::Fr, Projective = Self::G2Projective>
        + From<Self::G2Projective>
        + Into<Self::G2Projective>
        + Into<Self::G2Prepared>;

    /// A G2 element that has been preprocessed for use in a pairing.
    type G2Prepared: ToBytes + Default + Clone + Send + Sync + Debug + From<Self::G2Affine>;

    /// The base field that hosts G1.
    type Fq: PrimeField + SquareRootField;

    /// The extension field that hosts G2.
    type Fqe: SquareRootField;

    /// The extension field that hosts the target group of the pairing.
    type Fqk: Field;

    /// Compute the product of miller loops for some number of (G1, G2) pairs.
    #[must_use]
    fn miller_loop<'a, I>(i: I) -> Self::Fqk
    where
        I: IntoIterator<Item = &'a (Self::G1Prepared, Self::G2Prepared)>;

    /// Perform final exponentiation of the result of a miller loop.
    #[must_use]
    fn final_exponentiation(_: &Self::Fqk) -> Option<Self::Fqk>;

    /// Computes a product of pairings.
    #[must_use]
    fn product_of_pairings<'a, I>(i: I) -> Self::Fqk
    where
        I: IntoIterator<Item = &'a (Self::G1Prepared, Self::G2Prepared)>,
    {
        Self::final_exponentiation(&Self::miller_loop(i)).unwrap()
    }

    /// Performs multiple pairing operations
    #[must_use]
    fn pairing<G1, G2>(p: G1, q: G2) -> Self::Fqk
    where
        G1: Into<Self::G1Affine>,
        G2: Into<Self::G2Affine>,
    {
        let g1_prep = Self::G1Prepared::from(p.into());
        let g2_prep = Self::G2Prepared::from(q.into());
        Self::product_of_pairings(core::iter::once(&(g1_prep, g2_prep)))
    }
}

/// Projective representation of an elliptic curve point guaranteed to be
/// in the correct prime order subgroup.
pub trait ProjectiveCurve:
    Eq
    + 'static
    + Sized
    + ToBytes
    + FromBytes
    + CanonicalSerialize
    + CanonicalDeserialize
    + Copy
    + Clone
    + Default
    + Send
    + Sync
    + Hash
    + Debug
    + Display
    + UniformRand
    + Zeroize
    + Zero
    + Neg<Output = Self>
    + Add<Self, Output = Self>
    + Sub<Self, Output = Self>
    + AddAssign<Self>
    + SubAssign<Self>
    + MulAssign<<Self as ProjectiveCurve>::ScalarField>
    + for<'a> Add<&'a Self, Output = Self>
    + for<'a> Sub<&'a Self, Output = Self>
    + for<'a> AddAssign<&'a Self>
    + for<'a> SubAssign<&'a Self>
    + core::iter::Sum<Self>
    + for<'a> core::iter::Sum<&'a Self>
    + From<<Self as ProjectiveCurve>::Affine>
{
    const COFACTOR: &'static [u64];
    type ScalarField: PrimeField + SquareRootField;
    type BaseField: Field;
    type Affine: AffineCurve<Projective = Self, ScalarField = Self::ScalarField, BaseField = Self::BaseField>
        + From<Self>
        + Into<Self>;

    /// Returns a fixed generator of unknown exponent.
    #[must_use]
    fn prime_subgroup_generator() -> Self;

    /// Normalizes a slice of projective elements so that
    /// conversion to affine is cheap.
    fn batch_normalization(v: &mut [Self]);

    /// Normalizes a slice of projective elements and outputs a vector
    /// containing the affine equivalents.
    fn batch_normalization_into_affine(v: &[Self]) -> Vec<Self::Affine> {
        let mut v = v.to_vec();
        Self::batch_normalization(&mut v);
        v.into_iter().map(|v| v.into()).collect()
    }

    /// Checks if the point is already "normalized" so that
    /// cheap affine conversion is possible.
    #[must_use]
    fn is_normalized(&self) -> bool;

    /// Doubles this element.
    #[must_use]
    fn double(&self) -> Self {
        let mut copy = *self;
        copy.double_in_place();
        copy
    }

    /// Doubles this element in place.
    fn double_in_place(&mut self) -> &mut Self;

    /// Converts self into the affine representation.
    fn into_affine(&self) -> Self::Affine {
        (*self).into()
    }

    /// Set `self` to be `self + other`, where `other: Self::Affine`.
    /// This is usually faster than adding `other` in projective form.
    fn add_mixed(mut self, other: &Self::Affine) -> Self {
        self.add_assign_mixed(other);
        self
    }

    /// Set `self` to be `self + other`, where `other: Self::Affine`.
    /// This is usually faster than adding `other` in projective form.
    fn add_assign_mixed(&mut self, other: &Self::Affine);

    /// Performs scalar multiplication of this element.
    fn mul<S: AsRef<[u64]>>(mut self, other: S) -> Self {
        let mut res = Self::zero();
        for b in ark_ff::BitIteratorBE::without_leading_zeros(other) {
            res.double_in_place();
            if b {
                res += self;
            }
        }

        self = res;
        self
    }
}

/// Affine representation of an elliptic curve point guaranteed to be
/// in the correct prime order subgroup.
pub trait AffineCurve:
    Eq
    + 'static
    + Sized
    + ToBytes
    + FromBytes
    + CanonicalSerialize
    + CanonicalDeserialize
    + Copy
    + Clone
    + Default
    + Send
    + Sync
    + Hash
    + Debug
    + Display
    + Zero
    + Neg<Output = Self>
    + Zeroize
    + core::iter::Sum<Self>
    + for<'a> core::iter::Sum<&'a Self>
    + From<<Self as AffineCurve>::Projective>
{
    const COFACTOR: &'static [u64];
    type ScalarField: PrimeField + SquareRootField + Into<<Self::ScalarField as PrimeField>::BigInt>;
    type BaseField: Field;
    type Projective: ProjectiveCurve<Affine = Self, ScalarField = Self::ScalarField, BaseField = Self::BaseField>
        + From<Self>
        + Into<Self>
        + MulAssign<Self::ScalarField>; // needed due to https://github.com/rust-lang/rust/issues/69640

    /// Returns a fixed generator of unknown exponent.
    #[must_use]
    fn prime_subgroup_generator() -> Self;

    /// Converts self into the projective representation.
    fn into_projective(&self) -> Self::Projective {
        (*self).into()
    }

    /// Returns a group element if the set of bytes forms a valid group element,
    /// otherwise returns None. This function is primarily intended for sampling
    /// random group elements from a hash-function or RNG output.
    fn from_random_bytes(bytes: &[u8]) -> Option<Self>;

    /// Performs scalar multiplication of this element with mixed addition.
    #[must_use]
    fn mul<S: Into<<Self::ScalarField as PrimeField>::BigInt>>(&self, other: S)
        -> Self::Projective;

    /// Multiply this element by the cofactor and output the
    /// resulting projective element.
    #[must_use]
    fn mul_by_cofactor_to_projective(&self) -> Self::Projective;

    /// Multiply this element by the cofactor.
    #[must_use]
    fn mul_by_cofactor(&self) -> Self {
        self.mul_by_cofactor_to_projective().into()
    }

    /// Multiply this element by the inverse of the cofactor in
    /// `Self::ScalarField`.
    #[must_use]
    fn mul_by_cofactor_inv(&self) -> Self;
}

impl<C: ProjectiveCurve> Group for C {
    type ScalarField = C::ScalarField;

    #[inline]
    #[must_use]
    fn double(&self) -> Self {
        let mut tmp = *self;
        tmp += self;
        tmp
    }

    #[inline]
    fn double_in_place(&mut self) -> &mut Self {
        <C as ProjectiveCurve>::double_in_place(self)
    }
}

/// Preprocess a G1 element for use in a pairing.
pub fn prepare_g1<E: PairingEngine>(g: impl Into<E::G1Affine>) -> E::G1Prepared {
    let g: E::G1Affine = g.into();
    E::G1Prepared::from(g)
}

/// Preprocess a G2 element for use in a pairing.
pub fn prepare_g2<E: PairingEngine>(g: impl Into<E::G2Affine>) -> E::G2Prepared {
    let g: E::G2Affine = g.into();
    E::G2Prepared::from(g)
}

pub trait CurveCycle
where
    <Self::E1 as AffineCurve>::Projective: MulAssign<<Self::E2 as AffineCurve>::BaseField>,
    <Self::E2 as AffineCurve>::Projective: MulAssign<<Self::E1 as AffineCurve>::BaseField>,
{
    type E1: AffineCurve<
        BaseField = <Self::E2 as AffineCurve>::ScalarField,
        ScalarField = <Self::E2 as AffineCurve>::BaseField,
    >;
    type E2: AffineCurve;
}

pub trait PairingFriendlyCycle: CurveCycle {
    type Engine1: PairingEngine<
        G1Affine = Self::E1,
        G1Projective = <Self::E1 as AffineCurve>::Projective,
        Fq = <Self::E1 as AffineCurve>::BaseField,
        Fr = <Self::E1 as AffineCurve>::ScalarField,
    >;

    type Engine2: PairingEngine<
        G1Affine = Self::E2,
        G1Projective = <Self::E2 as AffineCurve>::Projective,
        Fq = <Self::E2 as AffineCurve>::BaseField,
        Fr = <Self::E2 as AffineCurve>::ScalarField,
    >;
}
