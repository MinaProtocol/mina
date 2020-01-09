extern crate libc;
use algebra::{
    biginteger::{BigInteger, BigInteger384},
    curves::{
        bn_382::{
            g::{Affine as GAffine, Projective as GProjective},
            Bn_382, G1Affine, G1Projective,
            g1::Bn_382G1Parameters,
            g::Bn_382GParameters,
        },
        AffineCurve, ProjectiveCurve,
    },
    fields::{
        bn_382::{
            fp::{Fp, FpParameters as Fp_params},
            fq::{Fq, FqParameters as Fq_params},
        },
        Field, FpParameters, PrimeField, SquareRootField,
    },
    UniformRand,
};
use commitment::urs::{ URS};
use circuits::index::{Index, VerifierIndex, EvaluationDomains, MatrixValues, URSSpec, URSValue};
use ff_fft::{Evaluations, EvaluationDomain};
use num_bigint::BigUint;
use oracle::{self, poseidon, poseidon::Sponge};
use protocol::{prover::{ ProverProof, ProofEvaluations, RandomOracles}, marlin_sponge::{DefaultFqSponge, DefaultFrSponge}};
use rand::rngs::StdRng;
use rand_core;
use sprs::{CsMat, CsVecView, CSR};
use std::os::raw::c_char;
use std::ffi::CStr;
use std::fs::File;

fn index_to_witness_position(public_inputs: usize, h_to_x_ratio: usize, i: usize) -> usize {
    if i < public_inputs {
        i * h_to_x_ratio
    } else {
        // x_0 y_0 y_1     ... y_{k-2}
        // x_1 y_{k-1} y_{k} ... y_{2k-3}
        // x_2 y_{2k-2} ... y_{3k-4}
        // ...
        //
        // let m := k - 1
        // x_0 y_0 y_1     ... y_{m - 1}
        // x_1 y_{m} y_{m+1} ... y_{2m - 1}
        // x_2 y_{2 m} y_{2m+1} ... y_{3m - 1}
        // ...
        let m = h_to_x_ratio - 1;
        let aux_index = i - public_inputs;
        let block = aux_index / m;
        let intra_block = aux_index % m;
        h_to_x_ratio * block + 1 + intra_block
    }
}

fn rows_to_csmat<F: Clone>(
    public_inputs: usize,
    h_to_x_ratio: usize,
    v: &Vec<(Vec<usize>, Vec<F>)>,
) -> CsMat<F> {
    let constraints = v.len();

    // By using "constraints" as the number of columns, we are
    // implicitly padding this matrix to be square.

    let mut m = CsMat::empty(CSR, /* number of columns */ constraints);
    m.reserve_outer_dim(constraints);

    for (indices, coefficients) in v.iter() {
        let mut shifted_indices: Vec<usize> = indices
            .iter()
            .map(|&i| index_to_witness_position(public_inputs, h_to_x_ratio, i))
            .collect();
        shifted_indices.sort();
        m = m.append_outer_csvec(
            CsVecView::<F>::new_view(constraints, &shifted_indices, &coefficients).unwrap(),
        )
    }
    m
}

// NOTE: We always 'box' these values as pointers, since the FFI doesn't know
// the size of the target type, and annotating them with (void *) on the other
// side of the FFI would cause only the first 64 bits to be copied.

// usize vector stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_usize_vector_create() -> *mut Vec<usize> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_usize_vector_length(v: *const Vec<usize>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_usize_vector_emplace_back(v: *mut Vec<usize>, x: usize) {
    let v_ = unsafe { &mut (*v) };
    v_.push(x);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_usize_vector_get(v: *mut Vec<usize>, i: u32) -> usize {
    let v = unsafe { &mut (*v) };
    v[i as usize]
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_usize_vector_delete(v: *mut Vec<usize>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

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

// Fp stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_size_in_bits() -> i32 {
    return Fp_params::MODULUS_BITS as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_size() -> *mut BigInteger384 {
    let ret = Fp_params::MODULUS;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_is_square(x: *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let s0 = x_.pow(Fp_params::MODULUS_MINUS_ONE_DIV_TWO);
    s0.is_zero() || s0.is_one()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sqrt(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = match x_.sqrt() {
        Some(x) => x,
        None => Fp::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_random() -> *mut Fp {
    let ret: Fp = UniformRand::rand(&mut rand::thread_rng());
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_of_int(i: u64) -> *mut Fp {
    let ret = Fp::from(i);
    return Box::into_raw(Box::new(ret));
}

// TODO: Leaky
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_to_string(x: *const Fp) -> *const u8 {
    let x = unsafe { *x };
    let s: String = format!("{}", x);
    s.as_ptr()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_inv(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = match x_.inverse() {
        Some(x) => x,
        None => Fp::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_square(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = x_.square();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_add(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_negate(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_mul(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ * &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_div(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ / &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_sub(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_mut_add(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ += &y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_mut_mul(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ *= &y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_mut_sub(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ -= &y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_copy(x: *mut Fp, y: *const Fp) {
    unsafe { (*x) = *y };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_rng(i: i32) -> *mut Fp {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    let ret: Fp = UniformRand::rand(&mut rng);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_delete(x: *mut Fp) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_print(x: *const Fp) {
    let x_ = unsafe { &(*x) };
    println!("{}", *x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_equal(x: *const Fp, y: *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    return *x_ == *y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_to_bigint(x: *const Fp) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_of_bigint(x: *const BigInteger384) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fp::from_repr(*x_)));
}

// Fp vector stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_vector_create() -> *mut Vec<Fp> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_vector_length(v: *const Vec<Fp>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_vector_emplace_back(v: *mut Vec<Fp>, x: *const Fp) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_vector_get(v: *mut Vec<Fp>, i: u32) -> *mut Fp {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_vector_delete(v: *mut Vec<Fp>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp constraint-matrix stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_constraint_matrix_create() -> *mut Vec<(Vec<usize>, Vec<Fp>)> {
    return Box::into_raw(Box::new(vec![]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_constraint_matrix_append_row(
    m: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    indices: *mut Vec<usize>,
    coefficients: *mut Vec<Fp>,
) {
    let m_ = unsafe { &mut (*m) };
    let indices_ = unsafe { &mut (*indices) };
    let coefficients_ = unsafe { &mut (*coefficients) };
    m_.push((indices_.clone(), coefficients_.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_constraint_matrix_delete(x: *mut Vec<(Vec<usize>, Vec<Fp>)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
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

    sponge.absorb(params, x);
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

// Fp proof
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_create(
    index: *const Index<Bn_382>,
    primary_input: *const Vec<Fp>,
    auxiliary_input: *const Vec<Fp>,
) -> *const ProverProof<Bn_382> {
    let index = unsafe { &(*index) };
    let primary_input = unsafe { &(*primary_input) };
    let auxiliary_input = unsafe { &(*auxiliary_input) };

    let mut witness = vec![Fp::zero(); index.domains.h.size()];
    let ratio = index.domains.h.size() / index.domains.x.size();

    witness[0] = Fp::one();
    for (i, x) in primary_input.iter().enumerate() {
        let i = 1 + i;
        witness[i * ratio] = *x;
    }

    let m = ratio - 1;
    for (i, w) in auxiliary_input.iter().enumerate() {
        let block = i / m;
        let intra_block = i % m;
        witness[ratio * block + 1 + intra_block] = w.clone();
    }

    let proof = ProverProof::create::<DefaultFqSponge<Bn_382G1Parameters>, DefaultFrSponge<Fp> > (&witness, &index).unwrap();

    return Box::into_raw(Box::new(proof));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_make(
    primary_input : *const Vec<Fp>,

    w_comm        : *const G1Affine,
    za_comm       : *const G1Affine,
    zb_comm       : *const G1Affine,
    h1_comm       : *const G1Affine,
    g1_comm_0     : *const G1Affine,
    g1_comm_1     : *const G1Affine,
    h2_comm       : *const G1Affine,
    g2_comm_0     : *const G1Affine,
    g2_comm_1     : *const G1Affine,
    h3_comm       : *const G1Affine,
    g3_comm_0     : *const G1Affine,
    g3_comm_1     : *const G1Affine,
    proof1        : *const G1Affine,
    proof2        : *const G1Affine,
    proof3        : *const G1Affine,

    sigma2        : *const Fp,
    sigma3        : *const Fp,

    w: *const Fp,
    za: *const Fp,
    zb: *const Fp,
    h1: *const Fp,
    g1: *const Fp,
    h2: *const Fp,
    g2: *const Fp,
    h3: *const Fp,
    g3: *const Fp,
    row_0: *const Fp,
    row_1: *const Fp,
    row_2: *const Fp,
    col_0: *const Fp,
    col_1: *const Fp,
    col_2: *const Fp,
    val_0: *const Fp,
    val_1: *const Fp,
    val_2: *const Fp,
) -> *const ProverProof<Bn_382> {
    let public = unsafe { &(*primary_input) }.clone();

    let proof = ProverProof {
        w_comm: (unsafe { *w_comm }).clone(),
        za_comm: (unsafe { *za_comm }).clone() ,
        zb_comm: (unsafe { *zb_comm }).clone() ,
        h1_comm: (unsafe { *h1_comm }).clone() ,
        g1_comm: ((unsafe { *g1_comm_0 }).clone(),(unsafe { *g1_comm_1 }).clone()),
        h2_comm: (unsafe { *h2_comm }).clone() ,
        g2_comm: ((unsafe { *g2_comm_0 }).clone(),(unsafe { *g2_comm_1 }).clone()),
        h3_comm: (unsafe { *h3_comm }).clone() ,
        g3_comm: ((unsafe { *g3_comm_0 }).clone(),(unsafe { *g3_comm_1 }).clone()),
        proof1: (unsafe { *proof1 }).clone() ,
        proof2: (unsafe { *proof2 }).clone() ,
        proof3: (unsafe { *proof3 }).clone() ,
        public,
        sigma2: (unsafe { *sigma2 }).clone(),
        sigma3: (unsafe { *sigma3 }).clone(),
        evals: ProofEvaluations {
            w :(unsafe {*w}).clone(),
            za:(unsafe {*za}).clone(),
            zb:(unsafe {*zb}).clone(),
            h1:(unsafe {*h1}).clone(),
            g1:(unsafe {*g1}).clone(),
            h2:(unsafe {*h2}).clone(),
            g2:(unsafe {*g2}).clone(),
            h3:(unsafe {*h3}).clone(),
            g3:(unsafe {*g3}).clone(),
            row:
                [ (unsafe {*row_0}).clone(),
                  (unsafe {*row_1}).clone(),
                  (unsafe {*row_2}).clone() ],
            col:
                [ (unsafe {*col_0}).clone(),
                  (unsafe {*col_1}).clone(),
                  (unsafe {*col_2}).clone() ],
            val:
                [ (unsafe {*val_0}).clone(),
                  (unsafe {*val_1}).clone(),
                  (unsafe {*val_2}).clone() ],
        }
    };

    return Box::into_raw(Box::new(proof));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_delete(x: *mut ProverProof<Bn_382>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_w_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).w_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_za_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).za_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_zb_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).zb_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h1_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h1_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g1_comm_nocopy(p: *mut ProverProof<Bn_382>) -> *const (G1Affine, G1Affine) {
    let x = (unsafe { (*p).g1_comm });
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h2_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h2_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g2_comm_nocopy(p: *mut ProverProof<Bn_382>) -> *const (G1Affine, G1Affine) {
    let x = (unsafe { (*p).g2_comm });
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h3_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h3_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g3_comm_nocopy(p: *mut ProverProof<Bn_382>) -> *const (G1Affine, G1Affine) {
    let x = (unsafe { (*p).g3_comm });
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_commitment_with_degree_bound_0(
    p: *const (G1Affine, G1Affine)) -> *const G1Affine {
    let (x0, _) = unsafe { (*p)};
    return Box::into_raw(Box::new(x0.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_commitment_with_degree_bound_1(
    p: *const (G1Affine, G1Affine)) -> *const G1Affine {
    let (_, x1) = unsafe { (*p)};
    return Box::into_raw(Box::new(x1.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_proof1(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).proof1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_proof2(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).proof2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_proof3(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).proof3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_sigma2(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).sigma2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_sigma3(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).sigma3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_w_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.w }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_za_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.za }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_zb_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.zb }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h1_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.h1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g1_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.g1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h2_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.h2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g2_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.g2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h3_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.h3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g3_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.g3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_row_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.row };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_col_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.col };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_val_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.val };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_evals_0(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { (*evals) })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_evals_1(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { (*evals) })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_evals_2(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { (*evals) })[2].clone();
    return Box::into_raw(Box::new(x));
}

// Fp oracles
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_create(
    index: *const VerifierIndex<Bn_382>,
    proof: *const ProverProof<Bn_382>,
) -> *const RandomOracles<Fp> {
    let index = unsafe { &(*index) };
    let proof = unsafe { &(*proof) };
    let oracles = proof.oracles::<DefaultFqSponge<Bn_382G1Parameters>, DefaultFrSponge<Fp> >(index).unwrap();
    return Box::into_raw(Box::new(oracles));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_alpha(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).alpha ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_eta_a(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).eta_a ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_eta_b(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).eta_b ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_eta_c(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).eta_c ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_beta1(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).beta[0] ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_beta2(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).beta[1] ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_beta3(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).beta[2] ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_r_k(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).r_k ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_batch(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).batch ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_r(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).r ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_x_hat_beta1(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).x_hat_beta1 ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_digest_before_evaluations(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).digest_before_evaluations ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_delete(
    x: *mut RandomOracles<Fp>) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fp verifier index stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_create(
    index: *const Index<Bn_382>
) -> *const VerifierIndex<Bn_382> {
    Box::into_raw(Box::new(unsafe {&(*index)}.verifier_index()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_urs(
    index: *const VerifierIndex<Bn_382>
) -> *const URS<Bn_382> {
    let index = unsafe { & *index };
    let urs = index.urs.clone();
    Box::into_raw(Box::new(urs))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_make(
    public_inputs: usize,
    variables: usize,
    nonzero_entries: usize,
    max_degree: usize,
    urs: *const URS<Bn_382>,
    row_a: *const G1Affine,
    col_a: *const G1Affine,
    val_a: *const G1Affine,
    row_b: *const G1Affine,
    col_b: *const G1Affine,
    val_b: *const G1Affine,
    row_c: *const G1Affine,
    col_c: *const G1Affine,
    val_c: *const G1Affine,
) -> *const VerifierIndex<Bn_382> {
    let urs : URS<Bn_382> = (unsafe { &*urs }).clone();
    let index = VerifierIndex {
        domains: EvaluationDomains::create(variables, public_inputs, nonzero_entries).unwrap(),
        matrix_commitments: [
            MatrixValues { row: (unsafe {*row_a}).clone(), col: (unsafe {*col_a}).clone(), val: (unsafe {*val_a}).clone() },
            MatrixValues { row: (unsafe {*row_b}).clone(), col: (unsafe {*col_b}).clone(), val: (unsafe {*val_b}).clone() },
            MatrixValues { row: (unsafe {*row_c}).clone(), col: (unsafe {*col_c}).clone(), val: (unsafe {*val_c}).clone() },
        ],
        fq_sponge_params: oracle::bn_382::fq::params(),
        fr_sponge_params: oracle::bn_382::fp::params(),
        max_degree,
        public_inputs,
        urs,
    };
    Box::into_raw(Box::new(index))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_delete(
    x: *mut Index<Bn_382>
) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fp URS stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_create(depth : usize) -> *const URS<Bn_382> {
    Box::into_raw(Box::new(URS::create(depth, (0..depth).collect(), &mut rand_core::OsRng)))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_write(urs : *mut URS<Bn_382>, path: *mut c_char) {
    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let file = File::create(path).unwrap();
    let urs = unsafe { &*urs };
    let _ = urs.write(file);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_read(path: *mut c_char) -> *const URS<Bn_382> {
    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let file = File::open(path).unwrap();
    let res = URS::<Bn_382>::read(file).unwrap();
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_lagrange_commitment(
    urs : *const URS<Bn_382>,
    domain_size : usize,
    stride : usize,
    i: usize)
-> *const G1Affine {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = (0..domain_size).map(|j| if i == j { Fp::one() } else { Fp::zero() }).collect();
    let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
    let res = urs.exponentiate_sub_domain(&p, stride).unwrap();

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_commit_subdomain(
    urs : *const URS<Bn_382>,
    domain_size : usize,
    stride : usize,
    evals : *const Vec<Fp>)
-> *const G1Affine {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = unsafe { &*evals };
    let p = Evaluations::<Fp>::from_vec_and_domain(evals.clone(), x_domain).interpolate();
    let res = urs.exponentiate_sub_domain(&p, stride).unwrap();

    Box::into_raw(Box::new(res))
}

// Fp index stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_create<'a>(
    a: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    b: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    c: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    vars: usize,
    public_inputs: usize,
    urs : *mut URS<Bn_382>
) -> *mut Index<'a, Bn_382> {
    assert!(public_inputs > 0);

    let urs = unsafe { &*urs };
    let a = unsafe { &*a };
    let b = unsafe { &*b };
    let c = unsafe { &*c };

    let num_constraints = a.len();
    assert!(num_constraints >= vars);

    let h_to_x_ratio = {
        let x_group_size = EvaluationDomain::<Fp>::compute_size_of_domain(public_inputs).unwrap();
        let h_group_size = EvaluationDomain::<Fp>::compute_size_of_domain(num_constraints).unwrap();
        h_group_size / x_group_size
    };

    return Box::into_raw(Box::new(
        Index::<Bn_382>::create(
            rows_to_csmat(public_inputs, h_to_x_ratio, a),
            rows_to_csmat(public_inputs, h_to_x_ratio, b),
            rows_to_csmat(public_inputs, h_to_x_ratio, c),
            public_inputs,
            oracle::bn_382::fp::params(),
            oracle::bn_382::fq::params(),
            URSSpec::Use(urs),
        )
        .unwrap(),
    ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_delete(x: *mut Index<Bn_382>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_a_row_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].row_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_a_col_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].col_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_a_val_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].val_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_b_row_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].row_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_b_col_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].col_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_b_val_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].val_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_c_row_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].row_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_c_col_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].col_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_c_val_comm(
    index: *const Index<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).compiled[0].val_comm }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_nonzero_entries(
    index: *const Index<Bn_382>,
) -> usize {
    let index = unsafe { &*index };
    index.compiled.iter().map(|x| x.constraints.nnz()).max().unwrap()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_max_degree(
    index: *const Index<Bn_382>,
) -> usize {
    let index = unsafe { &*index };
    index.urs.get_ref().max_degree()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_num_variables(
    index: *const Index<Bn_382>,
) -> usize {
    let index = unsafe { &*index };
    index.compiled[0].constraints.shape().0
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_public_inputs(
    index: *const Index<Bn_382>,
) -> usize {
    let index = unsafe { &*index };
    index.public_inputs
}

// G / Fp stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_random() -> *const GProjective {
    let rng = &mut rand_core::OsRng;
    Box::into_raw(Box::new(GProjective::rand(rng)))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_delete(x: *mut GProjective) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_one() -> *const GProjective {
    let ret = GProjective::prime_subgroup_generator();
    Box::into_raw(Box::new(ret))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_add(
    x: *const GProjective,
    y: *const GProjective,
) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_scale(
    x: *const GProjective,
    s: *const Fq,
) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let s_ = unsafe { &(*s) };
    let ret = (*x_) * s_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_sub(
    x: *const GProjective,
    y: *const GProjective,
) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_negate(x: *const GProjective) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_to_affine(p: *const GProjective) -> *const GAffine {
    let p = unsafe { *p };
    let q = p.clone().into_affine();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_of_affine(p: *const GAffine) -> *const GProjective {
    let p = unsafe { *p };
    let q = p.clone().into_projective();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_of_affine_coordinates(
    x: *const Fp,
    y: *const Fp,
) -> *const GProjective {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    return Box::into_raw(Box::new(GProjective::new(x, y, Fp::one())));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_create(
    x: *const Fp,
    y: *const Fp
    ) -> *const GAffine {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    Box::into_raw(Box::new(GAffine::new(x, y, false)))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_x(p: *const GAffine) -> *const Fp {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.x.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_y(p: *const GAffine) -> *const Fp {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.y.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_delete(x: *mut GAffine) {
    let _box = unsafe { Box::from_raw(x) };
}

// G vector stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_vector_create() -> *mut Vec<GAffine> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_vector_length(v: *const Vec<GAffine>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_vector_emplace_back(v: *mut Vec<GAffine>, x: *const GAffine) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_vector_get(v: *mut Vec<GAffine>, i: u32) -> *mut GAffine {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_vector_delete(v: *mut Vec<GAffine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// G1 / Fq stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_random() -> *const G1Projective {
    let rng = &mut rand_core::OsRng;
    Box::into_raw(Box::new(G1Projective::rand(rng)))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_delete(x: *mut G1Projective) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_one() -> *const G1Projective {
    let ret = G1Projective::prime_subgroup_generator();
    Box::into_raw(Box::new(ret))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_add(
    x: *const G1Projective,
    y: *const G1Projective,
) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_scale(
    x: *const G1Projective,
    s: *const Fp,
) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let s_ = unsafe { &(*s) };
    let ret = (*x_) * s_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_sub(
    x: *const G1Projective,
    y: *const G1Projective,
) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_negate(x: *const G1Projective) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_to_affine(p: *const G1Projective) -> *const G1Affine {
    let p = unsafe { *p };
    let q = p.clone().into_affine();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_of_affine(p: *const G1Affine) -> *const G1Projective {
    let p = unsafe { *p };
    let q = p.clone().into_projective();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_of_affine_coordinates(
    x: *const Fq,
    y: *const Fq,
) -> *const G1Projective {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    return Box::into_raw(Box::new(G1Projective::new(x, y, Fq::one())));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_create(
    x: *const Fq,
    y: *const Fq
    ) -> *const G1Affine {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    Box::into_raw(Box::new(G1Affine::new(x, y, false)))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_x(p: *const G1Affine) -> *const Fq {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.x.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_y(p: *const G1Affine) -> *const Fq {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.y.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_delete(x: *mut G1Affine) {
    let _box = unsafe { Box::from_raw(x) };
}

// G1 vector stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_vector_create() -> *mut Vec<G1Affine> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_vector_length(v: *const Vec<G1Affine>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_vector_emplace_back(v: *mut Vec<G1Affine>, x: *const G1Affine) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_vector_get(v: *mut Vec<G1Affine>, i: u32) -> *mut G1Affine {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_vector_delete(v: *mut Vec<G1Affine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fq stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_size_in_bits() -> i32 {
    return Fq_params::MODULUS_BITS as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_size() -> *mut BigInteger384 {
    let ret = Fq_params::MODULUS;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_is_square(x: *const Fq) -> bool {
    let x_ = unsafe { &(*x) };
    let s0 = x_.pow(Fq_params::MODULUS_MINUS_ONE_DIV_TWO);
    s0.is_zero() || s0.is_one()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sqrt(x: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret = match x_.sqrt() {
        Some(x) => x,
        None => Fq::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_random() -> *mut Fq {
    let ret: Fq = UniformRand::rand(&mut rand::thread_rng());
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_of_int(i: u64) -> *mut Fq {
    let ret = Fq::from(i);
    return Box::into_raw(Box::new(ret));
}

// TODO: Leaky
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_to_string(x: *const Fq) -> *const u8 {
    let x = unsafe { *x };
    let s: String = format!("{}", x);
    s.as_ptr()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_inv(x: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret = match x_.inverse() {
        Some(x) => x,
        None => Fq::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_square(x: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret = x_.square();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_add(x: *const Fq, y: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_negate(x: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_mul(x: *const Fq, y: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ * &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_div(x: *const Fq, y: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ / &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sub(x: *const Fq, y: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - &y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_mut_add(x: *mut Fq, y: *const Fq) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ += &y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_mut_mul(x: *mut Fq, y: *const Fq) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ *= &y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_mut_sub(x: *mut Fq, y: *const Fq) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ -= &y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_copy(x: *mut Fq, y: *const Fq) {
    unsafe { (*x) = *y };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_rng(i: i32) -> *mut Fq {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    let ret: Fq = UniformRand::rand(&mut rng);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_delete(x: *mut Fq) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_print(x: *const Fq) {
    let x_ = unsafe { &(*x) };
    println!("{}", x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_equal(x: *const Fq, y: *const Fq) -> bool {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    return *x_ == *y_;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_to_bigint(x: *const Fq) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_of_bigint(x: *const BigInteger384) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fq::from_repr(*x_)));
}

// Fq vector stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_create() -> *mut Vec<Fq> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_length(v: *const Vec<Fq>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_emplace_back(v: *mut Vec<Fq>, x: *const Fq) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_get(v: *mut Vec<Fq>, i: u32) -> *mut Fq {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_delete(v: *mut Vec<Fq>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fq constraint-matrix stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_constraint_matrix_create() -> *mut Vec<(Vec<usize>, Vec<Fq>)> {
    return Box::into_raw(Box::new(vec![]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_constraint_matrix_append_row(
    m: *mut Vec<(Vec<usize>, Vec<Fq>)>,
    indices: *mut Vec<usize>,
    coefficients: *mut Vec<Fq>,
) {
    let m_ = unsafe { &mut (*m) };
    let indices_ = unsafe { &mut (*indices) };
    let coefficients_ = unsafe { &mut (*coefficients) };
    m_.push((indices_.clone(), coefficients_.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_constraint_matrix_delete(x: *mut Vec<(Vec<usize>, Vec<Fq>)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

// Fq sponge stubs

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sponge_params_create(
) -> *mut poseidon::ArithmeticSpongeParams<Fq> {
    let ret = oracle::bn_382::fq::params();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sponge_params_delete(
    x: *mut poseidon::ArithmeticSpongeParams<Fq>,
) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sponge_create() -> *mut poseidon::ArithmeticSponge<Fq> {
    let ret = oracle::poseidon::ArithmeticSponge::<Fq>::new();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sponge_delete(x: *mut poseidon::ArithmeticSponge<Fp>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sponge_absorb(
    sponge: *mut poseidon::ArithmeticSponge<Fq>,
    params: *const poseidon::ArithmeticSpongeParams<Fq>,
    x: *const Fq,
) {
    let sponge = unsafe { &mut (*sponge) };
    let params = unsafe { &(*params) };
    let x = unsafe { &(*x) };

    sponge.absorb(params, x);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_sponge_squeeze(
    sponge: *mut poseidon::ArithmeticSponge<Fq>,
    params: *const poseidon::ArithmeticSpongeParams<Fq>,
) -> *mut Fq {
    let sponge = unsafe { &mut (*sponge) };
    let params = unsafe { &(*params) };

    let ret = sponge.squeeze(params);
    Box::into_raw(Box::new(ret))
}
