use ark_ff::{
    bytes::{FromBytes, ToBytes},
    BigInteger,
};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use ark_std::rand::{
    distributions::{Distribution, Standard},
    Rng,
};
use ark_std::{
    convert::TryFrom,
    fmt::{Debug, Display},
    io::{Read, Result as IoResult, Write},
    vec::Vec,
};
use num_bigint::BigUint;
use zeroize::Zeroize;

use crate::caml::caml_bytes_string::CamlBytesString;

//
//
//

#[derive(ocaml_gen::CustomType, Copy, Clone, PartialEq, Eq, Debug, Default, Hash, Zeroize)]
pub struct BigInteger256(pub ark_ff::BigInteger256);

impl From<ark_ff::BigInteger256> for BigInteger256 {
    fn from(other: ark_ff::BigInteger256) -> Self {
        Self(other)
    }
}

impl Into<ark_ff::BigInteger256> for BigInteger256 {
    fn into(self) -> ark_ff::BigInteger256 {
        self.0
    }
}

//
// OCaml custom type
//

ocaml::custom!(BigInteger256);

unsafe impl<'a> ocaml::FromValue<'a> for BigInteger256 {
    fn from_value(value: ocaml::Value) -> Self {
        let x: ocaml::Pointer<Self> = ocaml::FromValue::from_value(value);
        x.as_ref().clone()
    }
}

//
// necessary wrapper trait implementations
//

impl ark_ff::BigInteger for BigInteger256 {
    const NUM_LIMBS: usize = ark_ff::BigInteger256::NUM_LIMBS;

    #[inline]
    fn add_nocarry(&mut self, other: &Self) -> bool {
        self.0.add_nocarry(&other.0)
    }

    #[inline]
    fn sub_noborrow(&mut self, other: &Self) -> bool {
        self.0.sub_noborrow(&other.0)
    }

    #[inline]
    #[allow(unused)]
    fn mul2(&mut self) {
        self.0.mul2()
    }

    #[inline]
    fn muln(&mut self, n: u32) {
        self.0.muln(n)
    }

    #[inline]
    #[allow(unused)]
    fn div2(&mut self) {
        self.0.div2()
    }

    #[inline]
    fn divn(&mut self, n: u32) {
        self.0.divn(n)
    }

    #[inline]
    fn is_odd(&self) -> bool {
        self.0.is_odd()
    }

    #[inline]
    fn is_even(&self) -> bool {
        self.0.is_even()
    }

    #[inline]
    fn is_zero(&self) -> bool {
        self.0.is_zero()
    }

    #[inline]
    fn num_bits(&self) -> u32 {
        self.0.num_bits()
    }

    #[inline]
    fn get_bit(&self, i: usize) -> bool {
        self.0.get_bit(i)
    }

    #[inline]
    fn from_bits_be(bits: &[bool]) -> Self {
        Self(ark_ff::BigInteger256::from_bits_be(bits))
    }

    fn from_bits_le(bits: &[bool]) -> Self {
        Self(ark_ff::BigInteger256::from_bits_le(bits))
    }

    #[inline]
    fn to_bytes_be(&self) -> Vec<u8> {
        self.0.to_bytes_be()
    }

    #[inline]
    fn to_bytes_le(&self) -> Vec<u8> {
        self.0.to_bytes_le()
    }

    fn to_bits_be(&self) -> Vec<bool> {
        ark_ff::BitIteratorBE::new(self).collect::<Vec<_>>()
    }

    fn to_bits_le(&self) -> Vec<bool> {
        ark_ff::BitIteratorLE::new(self).collect::<Vec<_>>()
    }
}

impl ark_serialize::CanonicalSerialize for BigInteger256 {
    #[inline]
    fn serialize<W: Write>(&self, writer: W) -> Result<(), ark_serialize::SerializationError> {
        self.0.serialize::<W>(writer)
    }

    #[inline]
    fn serialized_size(&self) -> usize {
        self.0.serialized_size()
    }
}

impl ark_serialize::CanonicalDeserialize for BigInteger256 {
    #[inline]
    fn deserialize<R: Read>(reader: R) -> Result<Self, ark_serialize::SerializationError> {
        let value = Self::read(reader)?;
        Ok(value)
    }
}

impl ToBytes for BigInteger256 {
    #[inline]
    fn write<W: Write>(&self, writer: W) -> IoResult<()> {
        self.0.write(writer)
    }
}

impl FromBytes for BigInteger256 {
    #[inline]
    fn read<R: Read>(reader: R) -> IoResult<Self> {
        ark_ff::BigInteger256::read::<R>(reader).map(Into::into)
    }
}

impl Display for BigInteger256 {
    fn fmt(&self, f: &mut ::core::fmt::Formatter<'_>) -> ::core::fmt::Result {
        std::fmt::Display::fmt(&self.0, f)
    }
}

impl Ord for BigInteger256 {
    #[inline]
    fn cmp(&self, other: &Self) -> ::core::cmp::Ordering {
        self.0.cmp(&other.0)
    }
}

impl PartialOrd for BigInteger256 {
    #[inline]
    fn partial_cmp(&self, other: &Self) -> Option<::core::cmp::Ordering> {
        self.0.partial_cmp(&other.0)
    }
}

impl Distribution<BigInteger256> for Standard {
    fn sample<R: Rng + ?Sized>(&self, rng: &mut R) -> BigInteger256 {
        BigInteger256(rng.gen())
    }
}

impl AsMut<[u64]> for BigInteger256 {
    #[inline]
    fn as_mut(&mut self) -> &mut [u64] {
        self.0.as_mut()
    }
}

impl AsRef<[u64]> for BigInteger256 {
    #[inline]
    fn as_ref(&self) -> &[u64] {
        self.0.as_ref()
    }
}

impl From<u64> for BigInteger256 {
    #[inline]
    fn from(val: u64) -> BigInteger256 {
        ark_ff::BigInteger256::from(val).into()
    }
}

impl TryFrom<BigUint> for BigInteger256 {
    type Error = ark_std::string::String;

    #[inline]
    fn try_from(val: num_bigint::BigUint) -> Result<BigInteger256, Self::Error> {
        ark_ff::BigInteger256::try_from(val).map(Into::into)
    }
}

impl Into<BigUint> for BigInteger256 {
    #[inline]
    fn into(self) -> BigUint {
        BigUint::from_bytes_le(&self.to_bytes_le())
    }
}

//
// Handy constants
//

const BIGINT256_NUM_BITS: i32 = 256;
const BIGINT256_LIMB_BITS: i32 = 64;
const BIGINT256_LIMB_BYTES: i32 = BIGINT256_LIMB_BITS / 8;
const BIGINT256_NUM_LIMBS: i32 =
    (BIGINT256_NUM_BITS + BIGINT256_LIMB_BITS - 1) / BIGINT256_LIMB_BITS;

//
// Export functions
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_of_numeral(
    s: CamlBytesString,
    _len: ocaml::Int,
    base: ocaml::Int,
) -> Result<BigInteger256, ocaml::Error> {
    match BigUint::parse_bytes(
        s.0,
        base.try_into()
            .map_err(|_| ocaml::Error::Message("caml_bigint_256_of_numeral"))?,
    ) {
        Some(data) => BigInteger256::try_from(data)
            .map_err(|_| ocaml::Error::Message("caml_bigint_256_of_numeral")),
        None => Err(ocaml::Error::Message("caml_bigint_256_of_numeral")),
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_of_decimal_string(
    s: CamlBytesString,
) -> Result<BigInteger256, ocaml::Error> {
    match BigUint::parse_bytes(s.0, 10) {
        Some(data) => BigInteger256::try_from(data)
            .map_err(|_| ocaml::Error::Message("caml_bigint_256_of_decimal_string")),
        None => Err(ocaml::Error::Message("caml_bigint_256_of_decimal_string")),
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_num_limbs() -> ocaml::Int {
    BIGINT256_NUM_LIMBS.try_into().unwrap()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_bytes_per_limb() -> ocaml::Int {
    BIGINT256_LIMB_BYTES.try_into().unwrap()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_div(x: BigInteger256, y: BigInteger256) -> BigInteger256 {
    let x: BigUint = x.into();
    let y: BigUint = y.into();
    let res: BigUint = x / y;
    let inner: BigInteger256 = res.try_into().expect("BigUint division has a bug");
    inner.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_compare(
    x: ocaml::Pointer<BigInteger256>,
    y: ocaml::Pointer<BigInteger256>,
) -> ocaml::Int {
    match x.as_ref().cmp(y.as_ref()) {
        std::cmp::Ordering::Less => -1,
        std::cmp::Ordering::Equal => 0,
        std::cmp::Ordering::Greater => 1,
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_print(x: BigInteger256) {
    println!("{}", x.to_string());
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_to_string(x: BigInteger256) -> String {
    x.to_string()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_test_bit(
    x: ocaml::Pointer<BigInteger256>,
    i: ocaml::Int,
) -> Result<bool, ocaml::Error> {
    match i.try_into() {
        Ok(i) => Ok(x.as_ref().get_bit(i)),
        Err(_) => Err(ocaml::Error::invalid_argument("caml_bigint_256_test_bit")
            .err()
            .unwrap()),
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_to_bytes(
    x: ocaml::Pointer<BigInteger256>,
) -> [u8; std::mem::size_of::<BigInteger256>()] {
    let mut res = [0u8; std::mem::size_of::<BigInteger256>()];
    x.as_ref().0.serialize(&mut res[..]).unwrap();
    res
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_of_bytes(x: &[u8]) -> Result<BigInteger256, ocaml::Error> {
    let len = std::mem::size_of::<BigInteger256>();
    if x.len() != len {
        ocaml::Error::failwith("caml_bigint_256_of_bytes")?;
    };
    let result = BigInteger256::deserialize(&mut &*x)
        .map_err(|_| ocaml::Error::Message("deserialization error"))?;
    Ok(result)
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bigint_256_deep_copy(x: BigInteger256) -> BigInteger256 {
    x
}

//
// Tests
//

#[cfg(test)]
mod tests {
    use super::*;
    use num_bigint::ToBigUint;

    #[test]
    fn biguint() {
        let x = 10000.to_biguint().unwrap();
        println!("biguint.to_string: {}", x.to_string());
        let y = BigInteger256::try_from(x.clone()).unwrap();
        println!("camlbigint.to_string: {}", y.to_string());
        //assert!(&y.to_string() == "10000");
        let x2: BigUint = y.into();
        assert!(x2 == x);
        println!("biguint.to_string: {}", x2.to_string());
    }
}
