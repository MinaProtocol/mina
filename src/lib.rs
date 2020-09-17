#![allow(non_snake_case)]
extern crate libc;

pub mod bn382_dlog;
pub mod bn382_pairing;
pub mod common;
pub mod tweedledee;
pub mod tweedledee_plonk;
pub mod tweedledum;
pub mod tweedledum_plonk;

use algebra::{
    biginteger::{BigInteger, BigInteger256, BigInteger384},
    bn_382::fp::Fp,
};

use num_bigint::BigUint;
use oracle::{
    self, poseidon,
    poseidon::{MarlinSpongeConstants as SC, Sponge},
};

// Bigint stubs

const BIGINT384_NUM_BITS: i32 = 384;
const BIGINT384_LIMB_BITS: i32 = 64;
const BIGINT384_NUM_LIMBS: i32 =
    (BIGINT384_NUM_BITS + BIGINT384_LIMB_BITS - 1) / BIGINT384_LIMB_BITS;
const BIGINT384_NUM_BYTES: usize = (BIGINT384_NUM_LIMBS as usize) * 8;

fn bigint_of_biginteger384(x: &BigInteger384) -> BigUint {
    let x_ = (*x).0.as_ptr() as *const u8;
    let x_ = unsafe { std::slice::from_raw_parts(x_, BIGINT384_NUM_BYTES) };
    num_bigint::BigUint::from_bytes_le(x_)
}

// NOTE: This drops the high bits.
fn biginteger384_of_bigint(x: &BigUint) -> BigInteger384 {
    let mut bytes = x.to_bytes_le();
    bytes.resize(BIGINT384_NUM_BYTES, 0);
    let limbs = bytes.as_ptr();
    let limbs = limbs as *const [u64; BIGINT384_NUM_LIMBS as usize];
    let limbs = unsafe { &(*limbs) };
    BigInteger384(*limbs)
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_of_decimal_string(s: *const i8) -> *mut BigInteger384 {
    let c_str: &std::ffi::CStr = unsafe { std::ffi::CStr::from_ptr(s) };
    let s_: &[u8] = c_str.to_bytes();
    let res = match BigUint::parse_bytes(s_, 10) {
        Some(x) => x,
        None => panic!("zexe_bigint384_of_numeral: Could not convert numeral."),
    };
    return Box::into_raw(Box::new(biginteger384_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_num_limbs() -> i32 {
    // HACK: Manually compute the number of limbs.
    return (BIGINT384_NUM_BITS + BIGINT384_LIMB_BITS - 1) / BIGINT384_LIMB_BITS;
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_to_data(x: *mut BigInteger384) -> *mut u64 {
    let x_ = unsafe { &mut (*x) };
    return (*x_).0.as_mut_ptr();
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_of_data(x: *mut u64) -> *mut BigInteger384 {
    let x_ = unsafe { std::slice::from_raw_parts(x, BIGINT384_NUM_LIMBS as usize) };
    let mut ret: std::boxed::Box<BigInteger384> = Box::new(Default::default());
    (*ret).0.copy_from_slice(x_);
    return Box::into_raw(ret);
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_bytes_per_limb() -> i32 {
    // HACK: Manually compute the bytes per limb.
    return BIGINT384_LIMB_BITS / 8;
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_div(
    x: *const BigInteger384,
    y: *const BigInteger384,
) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let res = bigint_of_biginteger384(&x_) / &bigint_of_biginteger384(&y_);
    return Box::into_raw(Box::new(biginteger384_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_of_numeral(
    s: *const u8,
    len: u32,
    base: u32,
) -> *mut BigInteger384 {
    let s_ = unsafe { std::slice::from_raw_parts(s, len as usize) };
    let res = match BigUint::parse_bytes(s_, base) {
        Some(x) => x,
        None => panic!("zexe_bigint384_of_numeral: Could not convert numeral."),
    };
    return Box::into_raw(Box::new(biginteger384_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_compare(x: *const BigInteger384, y: *const BigInteger384) -> u8 {
    let _x = unsafe { &(*x) };
    let _y = unsafe { &(*y) };
    if _x < _y {
        255
    } else if _x == _y {
        0
    } else {
        1
    }
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_test_bit(x: *const BigInteger384, i: i32) -> bool {
    let _x = unsafe { &(*x) };
    return _x.get_bit(i as usize);
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_delete(x: *mut BigInteger384) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_print(x: *const BigInteger384) {
    let x_ = unsafe { &(*x) };
    println!("{}", *x_);
}

#[no_mangle]
pub extern "C" fn zexe_bigint384_find_wnaf(
    _size: usize,
    x: *const BigInteger384,
) -> *const Vec<i64> {
    // FIXME:
    // - as it stands, we have to ignore the first parameter
    // - in snarky the return type will be a Long_vector.t, which is a C++ vector,
    //   not a rust one
    if true {
        panic!("zexe_bigint384_find_wnaf is not implemented");
    }
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.find_wnaf()));
}

const BIGINT256_NUM_BITS: i32 = 256;
const BIGINT256_LIMB_BITS: i32 = 64;
const BIGINT256_NUM_LIMBS: i32 =
    (BIGINT256_NUM_BITS + BIGINT256_LIMB_BITS - 1) / BIGINT256_LIMB_BITS;
const BIGINT256_NUM_BYTES: usize = (BIGINT256_NUM_LIMBS as usize) * 8;

fn bigint_of_biginteger256(x: &BigInteger256) -> BigUint {
    let x_ = (*x).0.as_ptr() as *const u8;
    let x_ = unsafe { std::slice::from_raw_parts(x_, BIGINT256_NUM_BYTES) };
    num_bigint::BigUint::from_bytes_le(x_)
}

// NOTE: This drops the high bits.
fn biginteger256_of_bigint(x: &BigUint) -> BigInteger256 {
    let mut bytes = x.to_bytes_le();
    bytes.resize(BIGINT256_NUM_BYTES, 0);
    let limbs = bytes.as_ptr();
    let limbs = limbs as *const [u64; BIGINT256_NUM_LIMBS as usize];
    let limbs = unsafe { &(*limbs) };
    BigInteger256(*limbs)
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_of_decimal_string(s: *const i8) -> *mut BigInteger256 {
    let c_str: &std::ffi::CStr = unsafe { std::ffi::CStr::from_ptr(s) };
    let s_: &[u8] = c_str.to_bytes();
    let res = match BigUint::parse_bytes(s_, 10) {
        Some(x) => x,
        None => panic!("zexe_bigint256_of_numeral: Could not convert numeral."),
    };
    return Box::into_raw(Box::new(biginteger256_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_num_limbs() -> i32 {
    // HACK: Manually compute the number of limbs.
    return (BIGINT256_NUM_BITS + BIGINT256_LIMB_BITS - 1) / BIGINT256_LIMB_BITS;
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_to_data(x: *mut BigInteger256) -> *mut u64 {
    let x_ = unsafe { &mut (*x) };
    return (*x_).0.as_mut_ptr();
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_of_data(x: *mut u64) -> *mut BigInteger256 {
    let x_ = unsafe { std::slice::from_raw_parts(x, BIGINT256_NUM_LIMBS as usize) };
    let mut ret: std::boxed::Box<BigInteger256> = Box::new(Default::default());
    (*ret).0.copy_from_slice(x_);
    return Box::into_raw(ret);
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_bytes_per_limb() -> i32 {
    // HACK: Manually compute the bytes per limb.
    return BIGINT256_LIMB_BITS / 8;
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_div(
    x: *const BigInteger256,
    y: *const BigInteger256,
) -> *mut BigInteger256 {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let res = bigint_of_biginteger256(&x_) / &bigint_of_biginteger256(&y_);
    return Box::into_raw(Box::new(biginteger256_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_of_numeral(
    s: *const u8,
    len: u32,
    base: u32,
) -> *mut BigInteger256 {
    let s_ = unsafe { std::slice::from_raw_parts(s, len as usize) };
    let res = match BigUint::parse_bytes(s_, base) {
        Some(x) => x,
        None => panic!("zexe_bigint256_of_numeral: Could not convert numeral."),
    };
    return Box::into_raw(Box::new(biginteger256_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_compare(x: *const BigInteger256, y: *const BigInteger256) -> u8 {
    let _x = unsafe { &(*x) };
    let _y = unsafe { &(*y) };
    if _x < _y {
        255
    } else if _x == _y {
        0
    } else {
        1
    }
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_test_bit(x: *const BigInteger256, i: i32) -> bool {
    let _x = unsafe { &(*x) };
    return _x.get_bit(i as usize);
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_delete(x: *mut BigInteger256) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_print(x: *const BigInteger256) {
    let x_ = unsafe { &(*x) };
    println!("{}", *x_);
}

#[no_mangle]
pub extern "C" fn zexe_bigint256_find_wnaf(
    _size: usize,
    x: *const BigInteger256,
) -> *const Vec<i64> {
    // FIXME:
    // - as it stands, we have to ignore the first parameter
    // - in snarky the return type will be a Long_vector.t, which is a C++ vector,
    //   not a rust one
    if true {
        panic!("zexe_bigint384_find_wnaf is not implemented");
    }
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.find_wnaf()));
}

// Fp sponge stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_params_create(
) -> *mut poseidon::ArithmeticSpongeParams<Fp> {
    let ret = oracle::bn_382::fp::params();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_params_delete(
    x: *mut poseidon::ArithmeticSpongeParams<Fp>,
) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_create() -> *mut poseidon::ArithmeticSponge<Fp, SC> {
    let ret = oracle::poseidon::ArithmeticSponge::<Fp, SC>::new();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_delete(x: *mut poseidon::ArithmeticSponge<Fp, SC>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_absorb(
    sponge: *mut poseidon::ArithmeticSponge<Fp, SC>,
    params: *const poseidon::ArithmeticSpongeParams<Fp>,
    x: *const Fp,
) {
    let sponge = unsafe { &mut (*sponge) };
    let params = unsafe { &(*params) };
    let x = unsafe { &(*x) };

    sponge.absorb(params, &[*x]);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_squeeze(
    sponge: *mut poseidon::ArithmeticSponge<Fp, SC>,
    params: *const poseidon::ArithmeticSpongeParams<Fp>,
) -> *mut Fp {
    let sponge = unsafe { &mut (*sponge) };
    let params = unsafe { &(*params) };

    let ret = sponge.squeeze(params);
    Box::into_raw(Box::new(ret))
}
