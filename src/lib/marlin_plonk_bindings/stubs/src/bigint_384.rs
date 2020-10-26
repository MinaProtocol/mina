use algebra::biginteger::{BigInteger, BigInteger384};
use num_bigint::BigUint;
use std::cmp::Ordering::{Equal, Greater, Less};
use std::convert::TryInto;

const BIGINT384_NUM_BITS: i32 = 384;
const BIGINT384_LIMB_BITS: i32 = 64;
const BIGINT384_LIMB_BYTES: i32 = BIGINT384_LIMB_BITS / 8;
const BIGINT384_NUM_LIMBS: i32 =
    (BIGINT384_NUM_BITS + BIGINT384_LIMB_BITS - 1) / BIGINT384_LIMB_BITS;
const BIGINT384_NUM_BYTES: usize = (BIGINT384_NUM_LIMBS as usize) * 8;

pub struct CamlBigint384(BigInteger384);

pub type CamlBigint384Ptr = ocaml::Pointer<CamlBigint384>;

extern "C" fn caml_bigint_384_compare_raw(x: ocaml::Value, y: ocaml::Value) -> libc::c_int {
    let x: CamlBigint384Ptr = ocaml::FromValue::from_value(x);
    let y: CamlBigint384Ptr = ocaml::FromValue::from_value(y);

    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

impl From<&CamlBigint384> for BigUint {
    fn from(x: &CamlBigint384) -> BigUint {
        let x_ = ((*x).0).0.as_ptr() as *const u8;
        let x_ = unsafe { std::slice::from_raw_parts(x_, BIGINT384_NUM_BYTES) };
        num_bigint::BigUint::from_bytes_le(x_)
    }
}

impl From<BigUint> for CamlBigint384 {
    fn from(x: BigUint) -> CamlBigint384 {
        let mut bytes = x.to_bytes_le();
        bytes.resize(BIGINT384_NUM_BYTES, 0);
        let limbs = bytes.as_ptr();
        let limbs = limbs as *const [u64; BIGINT384_NUM_LIMBS as usize];
        let limbs = unsafe { &(*limbs) };
        CamlBigint384(BigInteger384(*limbs))
    }
}

impl std::fmt::Display for CamlBigint384 {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        BigUint::from(self).fmt(f)
    }
}

ocaml::custom!(CamlBigint384 {
    compare: caml_bigint_384_compare_raw,
});

#[ocaml::func]
pub fn caml_bigint_384_of_numeral(
    s: &[u8],
    _len: u32,
    base: u32,
) -> Result<CamlBigint384, ocaml::Error> {
    match BigUint::parse_bytes(s, base) {
        Some(data) => Ok(data.into()),
        None => Err(ocaml::Error::invalid_argument("caml_bigint_384_of_numeral")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_bigint_384_of_decimal_string(s: &[u8]) -> Result<CamlBigint384, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok(data.into()),
        None => Err(
            ocaml::Error::invalid_argument("caml_bigint_384_of_decimal_string")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_bigint_384_num_limbs() -> ocaml::Int {
    return BIGINT384_NUM_LIMBS.try_into().unwrap();
}

#[ocaml::func]
pub fn caml_bigint_384_bytes_per_limb() -> ocaml::Int {
    return BIGINT384_LIMB_BYTES.try_into().unwrap();
}

#[ocaml::func]
pub fn caml_bigint_384_div(x: CamlBigint384Ptr, y: CamlBigint384Ptr) -> CamlBigint384 {
    let res: BigUint = BigUint::from(x.as_ref()) / BigUint::from(y.as_ref());
    res.into()
}

#[ocaml::func]
pub fn caml_bigint_384_compare(x: CamlBigint384Ptr, y: CamlBigint384Ptr) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_bigint_384_print(x: CamlBigint384Ptr) {
    println!("{}", BigUint::from(x.as_ref()));
}

#[ocaml::func]
pub fn caml_bigint_384_to_string(x: CamlBigint384Ptr) -> String {
    BigUint::from(x.as_ref()).to_string()
}

#[ocaml::func]
pub fn caml_bigint_384_test_bit(x: CamlBigint384Ptr, i: ocaml::Int) -> Result<bool, ocaml::Error> {
    match i.try_into() {
        Ok(i) => Ok(x.as_ref().0.get_bit(i)),
        Err(_) => Err(ocaml::Error::invalid_argument("caml_bigint_384_test_bit")
            .err()
            .unwrap()),
    }
}
