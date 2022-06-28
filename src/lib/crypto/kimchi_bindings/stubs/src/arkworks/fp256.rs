// we re-implement BigInteger256 and Fp256 here, from arkworks,
// to be able to implement OCaml bindings directly on them.
//
// These are the solutions:
// 1. Fork arkworks
// 2. Implement a wrapper Fp(Fp)
// 3. Implement our own Fp
//
// We used to do 1, we then moved to 2, we now do 3.

use std::{
    cmp::Ordering,
    fmt::{Debug, Display, Formatter, Result as FmtResult},
    hash::Hash,
    io::{Read, Result as IoResult, Write},
    ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Neg, Sub, SubAssign},
    str::FromStr,
};

#[derive(ocaml_gen::CustomType)]
pub struct Fp256<P>(ark_ff::Fp256<P>);

//
// Conversions
//

impl<P> From<ark_ff::Fp256<P>> for Fp256<P> {
    fn from(ark_fp: ark_ff::Fp256<P>) -> Self {
        Self(ark_fp)
    }
}

impl<P> From<&ark_ff::Fp256<P>> for Fp256<P> {
    fn from(ark_fp: &ark_ff::Fp256<P>) -> Self {
        Self(*ark_fp)
    }
}

impl<P> From<Fp256<P>> for ark_ff::Fp256<P> {
    fn from(fp: Fp256<P>) -> Self {
        fp.0
    }
}

impl<P> From<&Fp256<P>> for ark_ff::Fp256<P> {
    fn from(fp: &Fp256<P>) -> Self {
        fp.0
    }
}

//
// OCaml
//

ocaml::custom!(Fp256<P>);

unsafe impl<'a, P> ocaml::FromValue<'a> for Fp256<P> {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

//
//
//

impl<P> Default for Fp256<P> {
    fn default() -> Self {
        ark_ff::Fp256::default().into()
    }
}
impl<P> Hash for Fp256<P> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.0.hash(state);
    }
}
impl<P> Clone for Fp256<P> {
    fn clone(&self) -> Self {
        self.0.clone().into()
    }
}
impl<P> Copy for Fp256<P> {}
impl<P> Debug for Fp256<P> {
    fn fmt(&self, f: &mut Formatter<'_>) -> FmtResult {
        f.debug_tuple("Fp256").field(&self.0).finish()
    }
}
impl<P> PartialEq for Fp256<P> {
    fn eq(&self, other: &Self) -> bool {
        self.0.eq(&other.0)
    }
}
impl<P> Eq for Fp256<P> {}

//
//
//

impl<P> Fp256<P> {
    pub fn new(x: ark_ff::BigInteger256) -> Self {
        ark_ff::Fp256::new(x).into()
    }
}

impl<P> ark_ff::Zero for Fp256<P>
where
    P: ark_ff::Fp256Parameters,
{
    #[inline]
    fn zero() -> Self {
        ark_ff::Fp256::zero().into()
    }

    #[inline]
    fn is_zero(&self) -> bool {
        self.0.is_zero()
    }
}

impl<P> ark_ff::One for Fp256<P>
where
    P: ark_ff::Fp256Parameters,
{
    #[inline]
    fn one() -> Self {
        ark_ff::Fp256::one().into()
    }

    #[inline]
    fn is_one(&self) -> bool {
        self.0.is_one()
    }
}

impl<P> ark_ff::Field for Fp256<P>
where
    P: ark_ff::Fp256Parameters,
{
    type BasePrimeField = Self;

    fn extension_degree() -> u64 {
        ark_ff::Fp256::<P>::extension_degree()
    }

    fn from_base_prime_field_elems(elems: &[Self::BasePrimeField]) -> Option<Self> {
        // TODO: this looks suboptimal
        let elems: Vec<<ark_ff::Fp256<P> as ark_ff::Field>::BasePrimeField> =
            elems.iter().map(|x| x.0).collect();
        ark_ff::Fp256::from_base_prime_field_elems(&elems).map(Into::into)
    }

    #[inline]
    fn double(&self) -> Self {
        self.0.double().into()
    }

    #[inline]
    fn double_in_place(&mut self) -> &mut Self {
        self.0.double_in_place();
        self
    }

    #[inline]
    fn characteristic() -> &'static [u64] {
        ark_ff::Fp256::<P>::characteristic()
    }

    #[inline]
    fn from_random_bytes_with_flags<F>(bytes: &[u8]) -> Option<(Self, F)>
    where
        F: ark_serialize::Flags,
    {
        ark_ff::Fp256::from_random_bytes_with_flags(bytes).map(|(x, f)| (x.into(), f))
    }

    #[inline]
    fn square(&self) -> Self {
        self.0.square().into()
    }

    #[inline]
    fn square_in_place(&mut self) -> &mut Self {
        self.0.square_in_place();
        self
    }

    #[inline]
    fn inverse(&self) -> Option<Self> {
        self.0.inverse().map(Into::into)
    }

    fn inverse_in_place(&mut self) -> Option<&mut Self> {
        if self.0.inverse_in_place().is_some() {
            Some(self)
        } else {
            None
        }
    }

    /// The Frobenius map has no effect in a prime field.
    #[inline]
    fn frobenius_map(&mut self, x: usize) {
        self.0.frobenius_map(x)
    }
}

impl<P> ark_ff::PrimeField for Fp256<P>
where
    P: ark_ff::Fp256Parameters,
{
    type Params = P;
    type BigInt = ark_ff::BigInteger256;

    #[inline]
    fn from_repr(r: Self::BigInt) -> Option<Self> {
        ark_ff::Fp256::from_repr(r).map(Into::into)
    }

    fn into_repr(&self) -> Self::BigInt {
        self.0.into_repr()
    }
}

impl<P> ark_ff::FftField for Fp256<P>
where
    P: ark_ff::Fp256Parameters,
{
    type FftParams = P;

    #[inline]
    fn two_adic_root_of_unity() -> Self {
        ark_ff::Fp256::two_adic_root_of_unity().into()
    }

    #[inline]
    fn large_subgroup_root_of_unity() -> Option<Self> {
        ark_ff::Fp256::large_subgroup_root_of_unity().map(Into::into)
    }

    #[inline]
    fn multiplicative_generator() -> Self {
        ark_ff::Fp256::multiplicative_generator().into()
    }
}

impl<P: ark_ff::Fp256Parameters> ark_ff::SquareRootField for Fp256<P> {
    #[inline]
    fn legendre(&self) -> ark_ff::LegendreSymbol {
        self.0.legendre()
    }

    #[inline]
    fn sqrt(&self) -> Option<Self> {
        self.0.sqrt().map(Into::into)
    }

    fn sqrt_in_place(&mut self) -> Option<&mut Self> {
        if self.0.sqrt_in_place().is_some() {
            Some(self)
        } else {
            None
        }
    }
}

impl<P: ark_ff::Fp256Parameters> Ord for Fp256<P> {
    #[inline(always)]
    fn cmp(&self, other: &Self) -> Ordering {
        self.0.cmp(&other.0)
    }
}

impl<P: ark_ff::Fp256Parameters> PartialOrd for Fp256<P> {
    #[inline(always)]
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        self.0.partial_cmp(&other.0)
    }
}

impl<P: ark_ff::Fp256Parameters> From<u128> for Fp256<P> {
    fn from(other: u128) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<i128> for Fp256<P> {
    fn from(other: i128) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<bool> for Fp256<P> {
    fn from(other: bool) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<u64> for Fp256<P> {
    fn from(other: u64) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<i64> for Fp256<P> {
    fn from(other: i64) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<u32> for Fp256<P> {
    fn from(other: u32) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<i32> for Fp256<P> {
    fn from(other: i32) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<u16> for Fp256<P> {
    fn from(other: u16) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<i16> for Fp256<P> {
    fn from(other: i16) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<u8> for Fp256<P> {
    fn from(other: u8) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<i8> for Fp256<P> {
    fn from(other: i8) -> Self {
        ark_ff::Fp256::from(other).into()
    }
}

impl<P: ark_ff::Fp256Parameters> ark_ff::ToBytes for Fp256<P> {
    #[inline]
    fn write<W: Write>(&self, writer: W) -> IoResult<()> {
        self.0.write(writer)
    }
}

impl<P: ark_ff::Fp256Parameters> ark_ff::FromBytes for Fp256<P> {
    #[inline]
    fn read<R: Read>(reader: R) -> IoResult<Self> {
        ark_ff::Fp256::read(reader).map(Into::into)
    }
}

impl<P: ark_ff::Fp256Parameters> FromStr for Fp256<P> {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        ark_ff::Fp256::from_str(s).map(Into::into)
    }
}

impl<P: ark_ff::Fp256Parameters> Display for Fp256<P> {
    #[inline]
    fn fmt(&self, f: &mut Formatter<'_>) -> FmtResult {
        Display::fmt(&self.0, f)
    }
}

impl<P: ark_ff::Fp256Parameters> Neg for Fp256<P> {
    type Output = Self;
    #[inline]
    #[must_use]
    fn neg(self) -> Self {
        self.0.neg().into()
    }
}

impl<'a, P: ark_ff::Fp256Parameters> Add<&'a Fp256<P>> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn add(self, other: &Self) -> Self {
        self.0.add(&other.0).into()
    }
}

impl<'a, P: ark_ff::Fp256Parameters> Sub<&'a Fp256<P>> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn sub(self, other: &Self) -> Self {
        self.0.sub(&other.0).into()
    }
}

impl<'a, P: ark_ff::Fp256Parameters> Mul<&'a Fp256<P>> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn mul(self, other: &Self) -> Self {
        self.0.mul(&other.0).into()
    }
}

impl<'a, P: ark_ff::Fp256Parameters> Div<&'a Fp256<P>> for Fp256<P> {
    type Output = Self;

    /// Returns `self * other.inverse()` if `other.inverse()` is `Some`, and
    /// panics otherwise.
    #[inline]
    fn div(self, other: &Self) -> Self {
        self.0.div(&other.0).into()
    }
}

impl<'a, P: ark_ff::Fp256Parameters> AddAssign<&'a Self> for Fp256<P> {
    #[inline]
    fn add_assign(&mut self, other: &Self) {
        self.0.add_assign(&other.0);
    }
}

impl<'a, P: ark_ff::Fp256Parameters> SubAssign<&'a Self> for Fp256<P> {
    #[inline]
    fn sub_assign(&mut self, other: &Self) {
        self.0.sub_assign(&other.0);
    }
}

impl<'a, P: ark_ff::Fp256Parameters> MulAssign<&'a Self> for Fp256<P> {
    #[inline]
    fn mul_assign(&mut self, other: &Self) {
        self.0.mul_assign(&other.0);
    }
}

impl<'a, P: ark_ff::Fp256Parameters> DivAssign<&'a Self> for Fp256<P> {
    #[inline]
    fn div_assign(&mut self, other: &Self) {
        self.0.div_assign(&other.0);
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::Add<Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn add(self, other: Self) -> Self {
        self.0.add(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::Add<&'a mut Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn add(self, other: &'a mut Self) -> Self {
        self.0.add(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::Sub<Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn sub(self, other: Self) -> Self {
        self.0.sub(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::Sub<&'a mut Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn sub(self, other: &'a mut Self) -> Self {
        self.0.sub(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::iter::Sum<Self> for Fp256<P> {
    fn sum<I: Iterator<Item = Self>>(iter: I) -> Self {
        ark_ff::Fp256::<P>::sum(iter.map(|x| x.0)).into()
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::iter::Sum<&'a Self> for Fp256<P> {
    fn sum<I: Iterator<Item = &'a Self>>(iter: I) -> Self {
        ark_ff::Fp256::<P>::sum(iter.map(|x| x.0)).into()
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::AddAssign<Self> for Fp256<P> {
    fn add_assign(&mut self, other: Self) {
        self.0.add_assign(&other.0)
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::SubAssign<Self> for Fp256<P> {
    fn sub_assign(&mut self, other: Self) {
        self.0.sub_assign(&other.0)
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::AddAssign<&'a mut Self> for Fp256<P> {
    fn add_assign(&mut self, other: &'a mut Self) {
        self.0.add_assign(&other.0)
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::SubAssign<&'a mut Self> for Fp256<P> {
    fn sub_assign(&mut self, other: &'a mut Self) {
        self.0.sub_assign(&other.0)
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::Mul<Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn mul(self, other: Self) -> Self {
        self.0.mul(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::Div<Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn div(self, other: Self) -> Self {
        self.0.div(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::Mul<&'a mut Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn mul(self, other: &'a mut Self) -> Self {
        self.0.mul(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::Div<&'a mut Self> for Fp256<P> {
    type Output = Self;

    #[inline]
    fn div(self, other: &'a mut Self) -> Self {
        self.0.div(other.0).into()
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::iter::Product<Self> for Fp256<P> {
    fn product<I: Iterator<Item = Self>>(iter: I) -> Self {
        ark_ff::Fp256::product(iter.map(|x| x.0)).into()
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::iter::Product<&'a Self> for Fp256<P> {
    fn product<I: Iterator<Item = &'a Self>>(iter: I) -> Self {
        ark_ff::Fp256::product(iter.map(|x| x.0)).into()
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::MulAssign<Self> for Fp256<P> {
    fn mul_assign(&mut self, other: Self) {
        self.0.mul_assign(&other.0)
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::DivAssign<&'a mut Self> for Fp256<P> {
    fn div_assign(&mut self, other: &'a mut Self) {
        self.0.div_assign(&other.0)
    }
}

#[allow(unused_qualifications)]
impl<'a, P: ark_ff::Fp256Parameters> core::ops::MulAssign<&'a mut Self> for Fp256<P> {
    fn mul_assign(&mut self, other: &'a mut Self) {
        self.0.mul_assign(&other.0)
    }
}

#[allow(unused_qualifications)]
impl<P: ark_ff::Fp256Parameters> core::ops::DivAssign<Self> for Fp256<P> {
    fn div_assign(&mut self, other: Self) {
        self.0.div_assign(&other.0)
    }
}

impl<P: ark_ff::Fp256Parameters> zeroize::Zeroize for Fp256<P> {
    // The phantom data does not contain element-specific data
    // and thus does not need to be zeroized.
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}

impl<P: ark_ff::Fp256Parameters> Into<ark_ff::BigInteger256> for Fp256<P> {
    fn into(self) -> ark_ff::BigInteger256 {
        self.0.into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<ark_ff::BigInteger256> for Fp256<P> {
    /// Converts `Self::BigInteger` into `Self`
    ///
    /// # Panics
    /// This method panics if `int` is larger than `P::MODULUS`.
    fn from(int: ark_ff::BigInteger256) -> Self {
        ark_ff::Fp256::from(int).into()
    }
}

impl<P: ark_ff::Fp256Parameters> From<num_bigint::BigUint> for Fp256<P> {
    #[inline]
    fn from(val: num_bigint::BigUint) -> Self {
        ark_ff::Fp256::from(val).into()
    }
}

impl<P: ark_ff::Fp256Parameters> Into<num_bigint::BigUint> for Fp256<P> {
    #[inline]
    fn into(self) -> num_bigint::BigUint {
        self.0.into()
    }
}

impl<P: ark_ff::Fp256Parameters> ark_serialize::CanonicalSerializeWithFlags for Fp256<P> {
    fn serialize_with_flags<W: std::io::Write, F: ark_serialize::Flags>(
        &self,
        writer: W,
        flags: F,
    ) -> Result<(), ark_serialize::SerializationError> {
        self.0.serialize_with_flags(writer, flags)
    }

    fn serialized_size_with_flags<F: ark_serialize::Flags>(&self) -> usize {
        self.0.serialized_size_with_flags::<F>()
    }
}

impl<P: ark_ff::Fp256Parameters> ark_serialize::CanonicalSerialize for Fp256<P> {
    #[inline]
    fn serialize<W: std::io::Write>(
        &self,
        writer: W,
    ) -> Result<(), ark_serialize::SerializationError> {
        self.0.serialize(writer)
    }

    #[inline]
    fn serialized_size(&self) -> usize {
        self.0.serialized_size()
    }
}

impl<P: ark_ff::Fp256Parameters> ark_serialize::CanonicalDeserializeWithFlags for Fp256<P> {
    fn deserialize_with_flags<R: std::io::Read, F: ark_serialize::Flags>(
        reader: R,
    ) -> Result<(Self, F), ark_serialize::SerializationError> {
        ark_ff::Fp256::deserialize_with_flags::<R, F>(reader).map(|(x, f)| (x.into(), f))
    }
}

impl<P: ark_ff::Fp256Parameters> ark_serialize::CanonicalDeserialize for Fp256<P> {
    fn deserialize<R: std::io::Read>(reader: R) -> Result<Self, ark_serialize::SerializationError> {
        ark_ff::Fp256::deserialize(reader).map(Into::into)
    }
}

impl<P: ark_ff::Fp256Parameters> ark_std::rand::distributions::Distribution<Fp256<P>>
    for ark_std::rand::distributions::Standard
{
    #[inline]
    fn sample<R: ark_std::rand::Rng + ?Sized>(&self, rng: &mut R) -> Fp256<P> {
        let ark_fp: ark_ff::Fp256<P> = self.sample(rng);
        Fp256(ark_fp)
    }
}
