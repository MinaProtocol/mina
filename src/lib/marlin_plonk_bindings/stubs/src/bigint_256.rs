use algebra::biginteger::{BigInteger, BigInteger256};
use num_bigint::BigUint;
use std::cmp::Ordering::{Equal, Greater, Less};
use std::convert::TryInto;

const BIGINT256_NUM_BITS: i32 = 256;
const BIGINT256_LIMB_BITS: i32 = 64;
const BIGINT256_LIMB_BYTES: i32 = BIGINT256_LIMB_BITS / 8;
const BIGINT256_NUM_LIMBS: i32 =
    (BIGINT256_NUM_BITS + BIGINT256_LIMB_BITS - 1) / BIGINT256_LIMB_BITS;
const BIGINT256_NUM_BYTES: usize = (BIGINT256_NUM_LIMBS as usize) * 8;

#[derive(Copy, Clone)]
pub struct CamlBigint256(pub BigInteger256);

pub type CamlBigint256Ptr = ocaml::Pointer<CamlBigint256>;

extern "C" fn caml_bigint_256_compare_raw(x: ocaml::Value, y: ocaml::Value) -> libc::c_int {
    let x: CamlBigint256Ptr = ocaml::FromValue::from_value(x);
    let y: CamlBigint256Ptr = ocaml::FromValue::from_value(y);

    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

impl From<&CamlBigint256> for BigUint {
    fn from(x: &CamlBigint256) -> BigUint {
        let x_ = (x.0).0.as_ptr() as *const u8;
        let x_ = unsafe { std::slice::from_raw_parts(x_, BIGINT256_NUM_BYTES) };
        num_bigint::BigUint::from_bytes_le(x_)
    }
}

impl From<&BigUint> for CamlBigint256 {
    fn from(x: &BigUint) -> CamlBigint256 {
        let mut bytes = x.to_bytes_le();
        bytes.resize(BIGINT256_NUM_BYTES, 0);
        let limbs = bytes.as_ptr();
        let limbs = limbs as *const [u64; BIGINT256_NUM_LIMBS as usize];
        let limbs = unsafe { &(*limbs) };
        CamlBigint256(BigInteger256(*limbs))
    }
}

impl std::fmt::Display for CamlBigint256 {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        BigUint::from(self).fmt(f)
    }
}

ocaml::custom!(CamlBigint256 {
    compare: caml_bigint_256_compare_raw,
});

#[ocaml::func]
pub fn caml_bigint_256_of_numeral(
    s: &[u8],
    _len: u32,
    base: u32,
) -> Result<CamlBigint256, ocaml::Error> {
    match BigUint::parse_bytes(s, base) {
        Some(data) => Ok((&data).into()),
        None => Err(ocaml::Error::invalid_argument("caml_bigint_256_of_numeral")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_bigint_256_of_decimal_string(s: &[u8]) -> Result<CamlBigint256, ocaml::Error> {
    match BigUint::parse_bytes(s, 10) {
        Some(data) => Ok((&data).into()),
        None => Err(
            ocaml::Error::invalid_argument("caml_bigint_256_of_decimal_string")
                .err()
                .unwrap(),
        ),
    }
}

#[ocaml::func]
pub fn caml_bigint_256_num_limbs() -> ocaml::Int {
    return BIGINT256_NUM_LIMBS.try_into().unwrap();
}

#[ocaml::func]
pub fn caml_bigint_256_bytes_per_limb() -> ocaml::Int {
    return BIGINT256_LIMB_BYTES.try_into().unwrap();
}

#[ocaml::func]
pub fn caml_bigint_256_div(x: CamlBigint256Ptr, y: CamlBigint256Ptr) -> CamlBigint256 {
    let res: BigUint = BigUint::from(x.as_ref()) / BigUint::from(y.as_ref());
    (&res).into()
}

#[ocaml::func]
pub fn caml_bigint_256_compare(x: CamlBigint256Ptr, y: CamlBigint256Ptr) -> ocaml::Int {
    match x.as_ref().0.cmp(&y.as_ref().0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[ocaml::func]
pub fn caml_bigint_256_print(x: CamlBigint256Ptr) {
    println!("{}", BigUint::from(x.as_ref()));
}

#[ocaml::func]
pub fn caml_bigint_256_to_string(x: CamlBigint256Ptr) -> String {
    BigUint::from(x.as_ref()).to_string()
}

#[ocaml::func]
pub fn caml_bigint_256_test_bit(x: CamlBigint256Ptr, i: ocaml::Int) -> Result<bool, ocaml::Error> {
    match i.try_into() {
        Ok(i) => Ok(x.as_ref().0.get_bit(i)),
        Err(_) => Err(ocaml::Error::invalid_argument("caml_bigint_256_test_bit")
            .err()
            .unwrap()),
    }
}

#[ocaml::func]
pub fn caml_bigint_256_to_bytes(x: CamlBigint256Ptr) -> ocaml::Value {
    let len = std::mem::size_of::<CamlBigint256>();
    let str = unsafe { ocaml::sys::caml_alloc_string(len) };
    unsafe {
        core::ptr::copy_nonoverlapping(x.as_ptr() as *const u8, ocaml::sys::string_val(str), len);
    }
    ocaml::Value(str)
}

#[ocaml::func]
pub fn caml_bigint_256_of_bytes(x: &[u8]) -> Result<CamlBigint256, ocaml::Error> {
    let len = std::mem::size_of::<CamlBigint256>();
    if x.len() != len {
        ocaml::Error::failwith("caml_bigint_256_of_bytes")?;
    };
    let x = unsafe { *(x.as_ptr() as *const CamlBigint256) };
    Ok(x)
}
