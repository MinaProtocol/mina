extern crate libc;

mod common;
pub mod bn382_dlog;
pub mod bn382_pairing;
pub mod tweedle;

use common::*;
use algebra::{
    ToBytes, FromBytes, One, Zero,
    biginteger::{BigInteger, BigInteger384},
    bn_382::{
        g::{Affine as GAffine, Projective as GProjective},
        Bn_382, G1Affine, G1Projective, G2Affine,
        g1::Bn_382G1Parameters,
        g::Bn_382GParameters,
        fp::{Fp, FpParameters as Fp_params},
        fq::{Fq, FqParameters as Fq_params},
    },
    curves::{
        PairingEngine,
        AffineCurve, ProjectiveCurve,
    },
    fields::{
        Field, FpParameters, PrimeField, SquareRootField, FftField,
    },
    UniformRand,
};
use commitment_pairing::urs::{URS};
use evaluation_domains::EvaluationDomains;
use circuits_pairing::index::{Index, VerifierIndex, MatrixValues, URSSpec};
use ff_fft::{Evaluations, DensePolynomial, EvaluationDomain, Radix2EvaluationDomain as Domain, GeneralEvaluationDomain};
use num_bigint::BigUint;
use oracle::{self, marlin_sponge::{ScalarChallenge, DefaultFqSponge, DefaultFrSponge}, poseidon, poseidon::Sponge};
use protocol_pairing::{prover::{ ProverProof, ProofEvaluations, RandomOracles}};
use rand::rngs::StdRng;
use rand_core;
use sprs::{CsMat, CsVecView, CSR};
use std::os::raw::c_char;
use std::ffi::CStr;
use std::fs::File;
use std::io::{Read, Result as IoResult, Write, BufReader, BufWriter};
use groupmap::GroupMap;

use commitment_dlog::{commitment::{CommitmentCurve, PolyComm, product, b_poly_coefficients, OpeningProof}, srs::{SRS}};
use circuits_dlog::index::{Index as DlogIndex, VerifierIndex as DlogVerifierIndex, SRSSpec, SRSValue};
use protocol_dlog::prover::{ProverProof as DlogProof, ProofEvaluations as DlogProofEvaluations};

use algebra::bn_382::g::Affine;

// Bigint stubs

const BIGINT_NUM_BITS: i32 = 384;
const BIGINT_LIMB_BITS: i32 = 64;
const BIGINT_NUM_LIMBS: i32 = (BIGINT_NUM_BITS + BIGINT_LIMB_BITS - 1) / BIGINT_LIMB_BITS;
const BIGINT_NUM_BYTES: usize = (BIGINT_NUM_LIMBS as usize) * 8;

fn bigint_of_biginteger(x: &BigInteger384) -> BigUint {
    let x_ = (*x).0.as_ptr() as *const u8;
    let x_ = unsafe { std::slice::from_raw_parts(x_, BIGINT_NUM_BYTES) };
    num_bigint::BigUint::from_bytes_le(x_)
}

// NOTE: This drops the high bits.
fn biginteger_of_bigint(x: &BigUint) -> BigInteger384 {
    let mut bytes = x.to_bytes_le();
    bytes.resize(BIGINT_NUM_BYTES, 0);
    let limbs = bytes.as_ptr();
    let limbs = limbs as *const [u64; BIGINT_NUM_LIMBS as usize];
    let limbs = unsafe { &(*limbs) };
    BigInteger384(*limbs)
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_of_decimal_string(s: *const i8) -> *mut BigInteger384 {
    let c_str: &std::ffi::CStr = unsafe { std::ffi::CStr::from_ptr(s) };
    let s_: &[u8] = c_str.to_bytes();
    let res = match BigUint::parse_bytes(s_, 10) {
        Some(x) => x,
        None => panic!("camlsnark_bn382_bigint_of_numeral: Could not convert numeral."),
    };
    return Box::into_raw(Box::new(biginteger_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_num_limbs() -> i32 {
    // HACK: Manually compute the number of limbs.
    return (BIGINT_NUM_BITS + BIGINT_LIMB_BITS - 1) / BIGINT_LIMB_BITS;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_to_data(x: *mut BigInteger384) -> *mut u64 {
    let x_ = unsafe { &mut (*x) };
    return (*x_).0.as_mut_ptr();
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_of_data(x: *mut u64) -> *mut BigInteger384 {
    let x_ = unsafe { std::slice::from_raw_parts(x, BIGINT_NUM_LIMBS as usize) };
    let mut ret: std::boxed::Box<BigInteger384> = Box::new(Default::default());
    (*ret).0.copy_from_slice(x_);
    return Box::into_raw(ret);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_bytes_per_limb() -> i32 {
    // HACK: Manually compute the bytes per limb.
    return BIGINT_LIMB_BITS / 8;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_div(
    x: *const BigInteger384,
    y: *const BigInteger384,
) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let res = bigint_of_biginteger(&x_) / &bigint_of_biginteger(&y_);
    return Box::into_raw(Box::new(biginteger_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_of_numeral(
    s: *const u8,
    len: u32,
    base: u32,
) -> *mut BigInteger384 {
    let s_ = unsafe { std::slice::from_raw_parts(s, len as usize) };
    let res = match BigUint::parse_bytes(s_, base) {
        Some(x) => x,
        None => panic!("camlsnark_bn382_bigint_of_numeral: Could not convert numeral."),
    };
    return Box::into_raw(Box::new(biginteger_of_bigint(&res)));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_compare(
    x: *const BigInteger384,
    y: *const BigInteger384,
) -> u8 {
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
pub extern "C" fn camlsnark_bn382_bigint_test_bit(x: *const BigInteger384, i: i32) -> bool {
    let _x = unsafe { &(*x) };
    return _x.get_bit(i as usize);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_delete(x: *mut BigInteger384) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_print(x: *const BigInteger384) {
    let x_ = unsafe { &(*x) };
    println!("{}", *x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_bigint_find_wnaf(
    _size: usize,
    x: *const BigInteger384,
) -> *const Vec<i64> {
    // FIXME:
    // - as it stands, we have to ignore the first parameter
    // - in snarky the return type will be a Long_vector.t, which is a C++ vector,
    //   not a rust one
    if true {
        panic!("camlsnark_bn382_bigint_find_wnaf is not implemented");
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
pub extern "C" fn camlsnark_bn382_fp_sponge_create() -> *mut poseidon::ArithmeticSponge<Fp> {
    let ret = oracle::poseidon::ArithmeticSponge::<Fp>::new();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_delete(x: *mut poseidon::ArithmeticSponge<Fp>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sponge_absorb(
    sponge: *mut poseidon::ArithmeticSponge<Fp>,
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
    sponge: *mut poseidon::ArithmeticSponge<Fp>,
    params: *const poseidon::ArithmeticSpongeParams<Fp>,
) -> *mut Fp {
    let sponge = unsafe { &mut (*sponge) };
    let params = unsafe { &(*params) };

    let ret = sponge.squeeze(params);
    Box::into_raw(Box::new(ret))
}

