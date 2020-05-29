extern crate libc;
use algebra::{
    ToBytes, FromBytes,
    biginteger::{BigInteger, BigInteger384},
    curves::{
        PairingCurve, PairingEngine,
        bn_382::{
            g::{Affine as GAffine, Projective as GProjective},
            Bn_382, G1Affine, G1Projective, G2Affine,
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
use commitment_pairing::urs::{URS};
use evaluation_domains::EvaluationDomains;
use circuits_pairing::index::{Index, VerifierIndex, MatrixValues, URSSpec};
use ff_fft::{Evaluations, DensePolynomial, EvaluationDomain};
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

use algebra::curves::bn_382::g::Affine;

fn ceil_pow2(x : usize) -> usize {
    let mut res = 1;
    while x > res {
        res *= 2;
    }
    res
}

fn write_vec<A: ToBytes, W: Write>(v : & Vec<A>, mut writer: W) -> IoResult<()> {
    u64::write(&(v.len() as u64), &mut writer)?;
    for x in v {
        x.write(&mut writer)?;
    };
    Ok(())
}

fn read_vec<A: FromBytes, R: Read>(mut reader: R) -> IoResult<Vec<A>> {
    let mut v = vec![];
    let n = u64::read(&mut reader)? as usize;
    for _ in 0..n {
        v.push(A::read(&mut reader)?);
    }
    Ok(v)
}

fn write_cs_mat<A: ToBytes + Clone, W:Write >(m: &CsMat<A>, mut w: W) -> IoResult<()> {
    fn v(s: &[usize]) -> Vec<u64> {
        s.iter().map(|x| *x as u64).collect()
    }

    let (a, b) = m.shape();
    u64::write(&(a as u64), &mut w)?;
    u64::write(&(b as u64), &mut w)?;

    write_vec::<u64, _>(&v(m.indptr()), &mut w)?;
    write_vec(&v(m.indices()), &mut w)?;
    write_vec(& m.data().to_vec(), &mut w)?;
    Ok(())
}

fn read_cs_mat<A: FromBytes + Copy, R: Read>(mut r: R) -> IoResult<CsMat<A>> {
    fn v(s: Vec<u64>) -> Vec<usize> {
        s.iter().map(|x| *x as usize).collect()
    }

    let a = u64::read(&mut r)? as usize;
    let b = u64::read(&mut r)? as usize;
    let shape = (a, b);

    let indptr = v(read_vec(&mut r)?);
    let indices = v(read_vec(&mut r)?);
    let data : Vec<A> = read_vec(&mut r)?;
    Ok(CsMat::new(shape, indptr, indices, data))
}

fn write_matrix_values<A: ToBytes, W: Write>(m : &MatrixValues<A>, mut w: W) -> IoResult<()> {
    A::write(&m.row, &mut w)?;
    A::write(&m.col, &mut w)?;
    A::write(&m.val, &mut w)?;
    A::write(&m.rc, &mut w)?;
    Ok(())
}

fn read_matrix_values<A: FromBytes, R: Read>(mut r: R) -> IoResult<MatrixValues<A>> {
    let row = A::read(&mut r)?;
    let col = A::read(&mut r)?;
    let val = A::read(&mut r)?;
    let rc = A::read(&mut r)?;
    Ok(MatrixValues {row, col, val, rc})
}

fn write_option<A : ToBytes, W: Write>(a : &Option<A>, mut w: W) -> IoResult<()> {
    match a {
        None => {
            u8::write(&0, &mut w)
        },
        Some(a) => {
            u8::write(&1, &mut w)?;
            A::write(a, &mut w)
        },
    }
}

fn read_option<A : FromBytes, R: Read>(mut r : R) -> IoResult<Option<A>> {
    match u8::read(&mut r)? {
        0 => Ok(None),
        1 => Ok(Some(A::read(&mut r)?)),
        _ => panic!("read_option: expected 0 or 1")
    }
}

fn write_poly_comm<A : ToBytes + AffineCurve, W: Write>(p : &PolyComm<A>, mut w: W) -> IoResult<()> {
    write_vec(&p.unshifted, &mut w)?;
    write_option(&p.shifted, &mut w)
}

fn read_poly_comm<A : FromBytes + AffineCurve, R: Read>(mut r : R) -> IoResult<PolyComm<A>> {
    let unshifted = read_vec(&mut r)?;
    let shifted = read_option(&mut r)?;
    Ok(PolyComm { unshifted, shifted })
}

fn write_dlog_matrix_values<A: ToBytes + AffineCurve, W: Write>(m : &circuits_dlog::index::MatrixValues<A>, mut w: W) -> IoResult<()> {
    write_poly_comm(&m.row, &mut w)?;
    write_poly_comm(&m.col, &mut w)?;
    write_poly_comm(&m.val, &mut w)?;
    write_poly_comm(&m.rc, &mut w)?;
    Ok(())
}

fn read_dlog_matrix_values<A: FromBytes + AffineCurve, R: Read>(mut r: R) -> IoResult<circuits_dlog::index::MatrixValues<A>> {
    let row = read_poly_comm(&mut r)?;
    let col = read_poly_comm(&mut r)?;
    let val = read_poly_comm(&mut r)?;
    let rc =  read_poly_comm(&mut r)?;
    Ok(circuits_dlog::index::MatrixValues {row, col, val, rc})
}

fn write_dense_polynomial<A: ToBytes + Field, W: Write>(p : &DensePolynomial<A>, mut w: W) -> IoResult<()> {
    write_vec(&p.coeffs, w)
}

fn read_dense_polynomial<A: ToBytes + Field, R: Read>(mut r: R) -> IoResult<DensePolynomial<A>> {
    let coeffs = read_vec(r)?;
    Ok(DensePolynomial { coeffs })
}

fn write_domain<A: ToBytes + PrimeField, W: Write>(d : &EvaluationDomain<A>, mut w: W) -> IoResult<()> {
    d.size.write(&mut w)?;
    d.log_size_of_group.write(&mut w)?;
    d.size_as_field_element.write(&mut w)?;
    d.size_inv.write(&mut w)?;
    d.group_gen.write(&mut w)?;
    d.group_gen_inv.write(&mut w)?;
    d.generator_inv.write(&mut w)?;
    Ok(())
}

fn read_domain<A: ToBytes + PrimeField, R: Read>(mut r: R) -> IoResult<EvaluationDomain<A>> {
    let size = u64::read(&mut r)?;
    let log_size_of_group = u32::read(&mut r)?;

    let size_as_field_element = A::read(&mut r)?;
    let size_inv = A::read(&mut r)?;
    let group_gen = A::read(&mut r)?;
    let group_gen_inv = A::read(&mut r)?;
    let generator_inv = A::read(&mut r)?;
    Ok(EvaluationDomain { size, log_size_of_group, size_as_field_element, size_inv, group_gen, group_gen_inv, generator_inv })
}

fn write_evaluations<A: ToBytes + PrimeField, W: Write>(e : &Evaluations<A>, mut w: W) -> IoResult<()> {
    write_vec(&e.evals, &mut w)?;
    Ok(())
}

fn read_evaluations<A: ToBytes + PrimeField, R: Read>(mut r: R) -> IoResult<Evaluations<A>> {
    let evals = read_vec(&mut r)?;
    let domain = EvaluationDomain::new(evals.len()).unwrap();
    assert_eq!(evals.len(), domain.size());
    Ok( Evaluations::from_vec_and_domain(evals, domain) )
}

fn write_evaluation_domains<A: PrimeField, W: Write>(d : &EvaluationDomains<A>, mut w: W) -> IoResult<()> {
    u64::write(&(d.h.size() as u64), &mut w)?;
    u64::write(&(d.k.size() as u64), &mut w)?;
    u64::write(&(d.b.size() as u64), &mut w)?;
    u64::write(&(d.x.size() as u64), &mut w)?;
    Ok(())
}

fn read_evaluation_domains<A: PrimeField, R: Read>(mut r: R) -> IoResult<EvaluationDomains<A>> {
    let h = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    let k = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    let b = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    let x = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    Ok(EvaluationDomains { h, k, b, x })
}

fn witness_position_to_index(public_inputs: usize, h_to_x_ratio: usize, w: usize) -> usize {
    if w % h_to_x_ratio == 0 {
        w / h_to_x_ratio
    } else {
        let m = h_to_x_ratio - 1;

        // w - 1 = h_to_x_ratio * (aux_index / m) + (aux_index % m)
        let aux_index_mod_m = (w - 1) % h_to_x_ratio;
        let aux_index_over_m = ((w - 1) - aux_index_mod_m) / h_to_x_ratio;
        let aux_index = aux_index_mod_m + m * aux_index_over_m;
        aux_index + public_inputs
    }
}

fn index_to_witness_position(public_inputs: usize, h_to_x_ratio: usize, i: usize) -> usize {
    let res =
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
    };
    assert_eq!(witness_position_to_index(public_inputs, h_to_x_ratio, res), i);
    res
}

fn rows_to_csmat<F: Clone + Copy + std::fmt::Debug>(
    public_inputs: usize,
    h_group_size : usize,
    h_to_x_ratio: usize,
    v: &Vec<(Vec<usize>, Vec<F>)>,
) -> CsMat<F> {
    let mut m = CsMat::empty(CSR, /* number of columns */ h_group_size);
    m.reserve_outer_dim(h_group_size);

    for (indices, coefficients) in v.iter() {
        let mut shifted: Vec<(usize, F)> = indices
            .iter()
            .map(|&i| index_to_witness_position(public_inputs, h_to_x_ratio, i))
            .zip(coefficients)
            .map(|(i, &x)| (i, x))
            .collect();

        shifted.sort_by(|(i, _), (j, _)| i.cmp(j));

        let shifted_indices : Vec<usize> = shifted.iter().map(|(i, _)| *i).collect();
        let shifted_coefficients : Vec<F> = shifted.iter().map(|(_, x)| *x).collect();

        match CsVecView::<F>::new_view(h_group_size, &shifted_indices, &shifted_coefficients) {
            Ok(r) => m = m.append_outer_csvec(r),
            Err(e) => panic!("new_view failed {} ({:?}, {:?})", e, shifted_indices, shifted_coefficients)
        };
    }

    for _ in 0..(h_group_size - v.len()) {
        match CsVecView::<F>::new_view(h_group_size, & vec![], & vec![]) {
            Ok(v) => m = m.append_outer_csvec(v),
            Err(e) => panic!("new_view failed {}", e)
        };
    }

    m
}

fn prepare_witness<F : PrimeField>(
    domains : EvaluationDomains<F>, 
    primary_input : &Vec<F>,
    auxiliary_input : &Vec<F>) -> Vec<F> {
    let mut witness = vec![F::zero(); domains.h.size()];
    let ratio = domains.h.size() / domains.x.size();

    witness[0] = F::one();
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

    witness
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
pub extern "C" fn camlsnark_bn382_fp_endo_base() -> *const Fq {
    let (endo_q, _endo_r) = circuits_pairing::index::endos::<Bn_382>();
    return Box::into_raw(Box::new(endo_q));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_endo_scalar() -> *const Fp {
    let (_endo_q, endo_r) = circuits_pairing::index::endos::<Bn_382>();
    return Box::into_raw(Box::new(endo_r));
}

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
pub extern "C" fn camlsnark_bn382_fp_mut_square(x: *mut Fp) {
    let x_ = unsafe { &mut (*x) };
    x_.square_in_place();
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

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_to_bigint_raw(x: *const Fp) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr_raw()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_to_bigint_raw_noalloc(x: *const Fp) -> *const BigInteger384 {
    let x_ = unsafe { &(*x) };
    &x_.0 as *const BigInteger384
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_of_bigint_raw(x: *const BigInteger384) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fp::from_repr_raw(*x_)));
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

#[no_mangle]
pub extern "C" fn camlsnark_bn382_batch_pairing_check(
// Pardon the tortured encoding. It's this way because we have to add
// additional OCaml bindings for each specialized vector type.
//
// Each haloified proof i contains group elements
// s_i
// u_{i,j} for j in d
// t_i
// p_i
//
// and we must check
// e(t_i, H) - e(p_i, beta H) = 0
// e(s_i, H) - sum_j e(u_{i,j}, beta^{max-j} H) = 0 
//
// To check this we sample a, b at random and check
//
// e(sum_i b^i t_i, H) - e(sum_i b^i p_i, beta H) = 0
// e(sum_i b^i s_i, H) - sum_j e(sum_i b^i u_{i,j}, beta^{max-j} H) = 0
//
// a [ e(sum_i b^i t_i, H) - e(sum_i b^i p_i, beta H) ] +
// e(sum_i b^i s_i, H) - sum_j e(sum_i b^i u_{i,j}, beta^{max-j} H) = 0
//
// e(-a sum_i b^i p_i, beta H) +
// e(sum_i b^i (s_i + a t_i), H) - sum_j e(sum_i b^i u_{i,j}, beta^{max-j} H) = 0
    urs: *const URS<Bn_382>,
    d: *const Vec<usize>,
    s: *const Vec<G1Affine>,
    u: *const Vec<G1Affine>,
    t: *const Vec<G1Affine>,
    p: *const Vec<G1Affine>,
) -> bool {
    let urs = unsafe { &(*urs) };
    let d = unsafe { &(*d) };
    let s = unsafe { &(*s) };
    let u = unsafe { &(*u) };
    let t = unsafe { &(*t) };
    let p = unsafe { &(*p) };

    let n = s.len();
    let k = d.len();
    assert_eq!(n * k, u.len());
    assert_eq!(n, t.len());
    assert_eq!(n, p.len());

    // Optimizations: These could both be 128 bits
    let a: Fp = UniformRand::rand(&mut rand::thread_rng());
    let b: Fp = UniformRand::rand(&mut rand::thread_rng());

    // Final value: d[j] = - sum_i b^i u_{i,j}
    let mut acc_d = vec![G1Projective::zero(); k];

    // Final value: sum_i b^i (s_i + a t_i)
    let mut acc_h = G1Projective::zero();

    // Final value: -a sum_i b^i p_i
    let mut acc_beta_h = G1Projective::zero();

    let u : Vec<Vec<G1Affine>> =
        (0..n).map(|i| (0..k).map(|j| u[k*i + j]).collect()).collect();

    // Optimization: Parallelize
    // Optimization:
    //   Experiment with scalar multiplying the affine point by b^i before adding into the
    //   accumulator.
    for ((p_i, (s_i, t_i)), u_i) in p.iter().zip(s.iter().zip(t)).zip(u) {
        acc_beta_h *= &b;
        acc_beta_h.add_assign_mixed(p_i);

        acc_h *= &b;
        acc_h.add_assign_mixed(s_i);
        acc_h += &t_i.mul(a);

        for (j, u_ij) in u_i.iter().enumerate() {
            acc_d[j] *= &b;
            acc_d[j].add_assign_mixed(u_ij);
        }
    }
    acc_beta_h *= &(-a);
    for acc_j in acc_d.iter_mut() {
        *acc_j = -(*acc_j);
    }

    let mut table = vec![
        (acc_h.into_affine().prepare(), G2Affine::prime_subgroup_generator().prepare()),
        (acc_beta_h.into_affine().prepare(), urs.hx.prepare())
    ];
    for (acc_j, j) in acc_d.iter().zip(d) {
        table.push((acc_j.into_affine().prepare(), urs.hn[&(urs.depth - j)].prepare()));
    }

    let x: Vec<(&_, & _)> = table.iter().map(|x| (&x.0, &x.1)).collect();
    Bn_382::final_exponentiation(&Bn_382::miller_loop(&x)).unwrap() == <Bn_382 as PairingEngine>::Fqk::one()
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

    let witness = prepare_witness(index.domains, primary_input, auxiliary_input);

    let proof = ProverProof::create::<DefaultFqSponge<Bn_382G1Parameters>, DefaultFrSponge<Fp> > (&witness, &index).unwrap();

    return Box::into_raw(Box::new(proof));
}

// TODO: Batch verify across different indexes
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_batch_verify(
    index: *const VerifierIndex<Bn_382>,
    proofs: *const Vec<ProverProof<Bn_382>>,
) -> bool {
    let index = unsafe { &(*index) };
    let proofs = unsafe { &(*proofs) };

    match ProverProof::<Bn_382>::verify::<DefaultFqSponge<Bn_382G1Parameters>, DefaultFrSponge<Fp> >(
        proofs, index, &mut rand_core::OsRng) {
        Ok(_) => true,
        Err(_) => false
    }
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_verify(
    index: *const VerifierIndex<Bn_382>,
    proof: *const ProverProof<Bn_382>,
) -> bool {

    let index = unsafe { &(*index) };
    let proof = unsafe { (*proof).clone() };

    match ProverProof::verify::<DefaultFqSponge<Bn_382G1Parameters>, DefaultFrSponge<Fp>>
    (
        &[proof].to_vec(),
        &index,
        &mut rand_core::OsRng
    )
    {
        Ok(status) => status,
        _ => false
    }
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

    rc_0: *const Fp,
    rc_1: *const Fp,
    rc_2: *const Fp,
) -> *const ProverProof<Bn_382> {
    let mut public = unsafe { &(*primary_input) }.clone();
    public.resize(ceil_pow2(public.len()), Fp::zero());

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
            rc:
                [ (unsafe {*rc_0}).clone(),
                  (unsafe {*rc_1}).clone(),
                  (unsafe {*rc_2}).clone() ],
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
    let x = unsafe {(*p).g1_comm};
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h2_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h2_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g2_comm_nocopy(p: *mut ProverProof<Bn_382>) -> *const (G1Affine, G1Affine) {
    let x = unsafe { (*p).g2_comm };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_h3_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h3_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_g3_comm_nocopy(p: *mut ProverProof<Bn_382>) -> *const (G1Affine, G1Affine) {
    let x = unsafe { (*p).g3_comm };
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
pub extern "C" fn camlsnark_bn382_fp_proof_rc_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.rc };
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

// Fp proof vector

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_vector_create() -> *mut Vec<ProverProof<Bn_382>> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_vector_length(v: *const Vec<ProverProof<Bn_382>>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_vector_emplace_back(v: *mut Vec<ProverProof<Bn_382>>, x: *const ProverProof<Bn_382>) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(x_.clone());
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_vector_get(v: *mut Vec<ProverProof<Bn_382>>, i: u32) -> *mut ProverProof<Bn_382> {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new(v_[i as usize].clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_proof_vector_delete(v: *mut Vec<ProverProof<Bn_382>>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp oracles
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_create(
    index: *const VerifierIndex<Bn_382>,
    proof: *const ProverProof<Bn_382>,
) -> *const RandomOracles<Fp> {
    let index = unsafe { &(*index) };
    let proof = unsafe { &(*proof) };

    let x_hat = Evaluations::<Fp>::from_vec_and_domain(proof.public.clone(), index.domains.x).interpolate();
    let x_hat_comm = index.urs.commit(&x_hat).unwrap();

    let oracles = proof.oracles::<DefaultFqSponge<Bn_382G1Parameters>, DefaultFrSponge<Fp> >(index, x_hat_comm, &x_hat).unwrap();
    return Box::into_raw(Box::new(oracles));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_alpha(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).alpha.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_eta_a(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).eta_a.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_eta_b(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).eta_b.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_eta_c(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).eta_c.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_beta1(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).beta[0].0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_beta2(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).beta[1].0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_beta3(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).beta[2].0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_r_k(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).r_k.0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_batch(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).batch.0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_r(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).r.0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_x_hat_beta1(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).x_hat_beta1.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_oracles_digest_before_evaluations(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).digest_before_evaluations.clone() ));
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
    constraints: usize,
    nonzero_entries: usize,
    max_degree: usize,
    urs: *const URS<Bn_382>,
    row_a: *const G1Affine,
    col_a: *const G1Affine,
    val_a: *const G1Affine,
    rc_a: *const G1Affine,

    row_b: *const G1Affine,
    col_b: *const G1Affine,
    val_b: *const G1Affine,
    rc_b: *const G1Affine,

    row_c: *const G1Affine,
    col_c: *const G1Affine,
    val_c: *const G1Affine,
    rc_c: *const G1Affine,
) -> *const VerifierIndex<Bn_382> {
    let urs : URS<Bn_382> = (unsafe { &*urs }).clone();
    let (endo_q, endo_r) = circuits_pairing::index::endos::<Bn_382>();
    let index = VerifierIndex {
        domains: EvaluationDomains::create(variables, constraints, public_inputs, nonzero_entries).unwrap(),
        matrix_commitments: [
            MatrixValues { row: (unsafe {*row_a}).clone(), col: (unsafe {*col_a}).clone(), val: (unsafe {*val_a}).clone(), rc: (unsafe {*rc_a}).clone() },
            MatrixValues { row: (unsafe {*row_b}).clone(), col: (unsafe {*col_b}).clone(), val: (unsafe {*val_b}).clone(), rc: (unsafe {*rc_b}).clone() },
            MatrixValues { row: (unsafe {*row_c}).clone(), col: (unsafe {*col_c}).clone(), val: (unsafe {*val_c}).clone(), rc: (unsafe {*rc_c}).clone() },
        ],
        fq_sponge_params: oracle::bn_382::fq::params(),
        fr_sponge_params: oracle::bn_382::fp::params(),
        max_degree,
        public_inputs,
        urs,
        endo_q, endo_r
    };
    Box::into_raw(Box::new(index))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_delete(
    x: *mut VerifierIndex<Bn_382>
) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_write<'a>(
    index : *const VerifierIndex<Bn_382>,
    path: *const c_char) {
    let index = unsafe { & *index };

    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut w = BufWriter::new(File::create(path).unwrap());

    let t : IoResult<()> = (|| {
        for c in index.matrix_commitments.iter() {
            write_matrix_values(c, &mut w)?;
        }
        write_evaluation_domains(&index.domains, &mut w)?;
        u64::write(&(index.public_inputs as u64), &mut w)?;
        u64::write(&(index.max_degree as u64), &mut w)?;
        index.urs.write(&mut w)?;
        Ok(())
    })();
    t.unwrap()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_read<'a>(
    path: *const c_char) -> *const VerifierIndex<Bn_382> {
    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut r = BufReader::new(File::open(path).unwrap());

    let t : IoResult<_> = (|| {
        let m0 = read_matrix_values(&mut r)?;
        let m1 = read_matrix_values(&mut r)?;
        let m2 = read_matrix_values(&mut r)?;
        let domains = read_evaluation_domains(&mut r)?;
        let public_inputs = u64::read(&mut r)? as usize;
        let max_degree = u64::read(&mut r)? as usize;
        let urs = URS::<Bn_382>::read(&mut r)?;
        let (endo_q, endo_r) = circuits_pairing::index::endos::<Bn_382>();
        Ok(VerifierIndex {
            matrix_commitments: [m0, m1, m2],
            domains,
            public_inputs,
            max_degree,
            urs,
            endo_q, endo_r,
            fr_sponge_params: oracle::bn_382::fp::params(),
            fq_sponge_params: oracle::bn_382::fq::params(),
        })
    })();
    Box::into_raw(Box::new(t.unwrap()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_a_row_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[0].row }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_a_col_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[0].col }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_a_val_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[0].val }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_a_rc_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[0].rc }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_b_row_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[1].row }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_b_col_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[1].col }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_b_val_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[1].val }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_b_rc_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[1].rc }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_c_row_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[2].row }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_c_col_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[2].col }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_c_val_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[2].val }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_verifier_index_c_rc_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new((unsafe { (*index).matrix_commitments[2].rc }).clone()))
}

// Fp URS stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_create(depth : usize) -> *const URS<Bn_382> {
    Box::into_raw(Box::new(URS::create(depth, (0..depth).collect(), &mut rand_core::OsRng)))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_write(urs : *mut URS<Bn_382>, path: *mut c_char) {
    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let file = BufWriter::new(File::create(path).unwrap());
    let urs = unsafe { &*urs };
    let _ = urs.write(file);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_read(path: *mut c_char) -> *const URS<Bn_382> {
    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let file = BufReader::new(File::open(path).unwrap());
    let res = URS::<Bn_382>::read(file).unwrap();
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_lagrange_commitment(
    urs : *const URS<Bn_382>,
    domain_size : usize,
    i: usize)
-> *const G1Affine {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = (0..domain_size).map(|j| if i == j { Fp::one() } else { Fp::zero() }).collect();
    let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
    let res = urs.commit(&p).unwrap();

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_commit_evaluations(
    urs : *const URS<Bn_382>,
    domain_size : usize,
    evals : *const Vec<Fp>)
-> *const G1Affine {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = unsafe { &*evals };
    let p = Evaluations::<Fp>::from_vec_and_domain(evals.clone(), x_domain).interpolate();
    let res = urs.commit(&p).unwrap();

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_dummy_degree_bound_checks(
    urs : *const URS<Bn_382>,
    bounds : *const Vec<usize>,
    )
-> *const Vec<G1Affine> {
    let urs = unsafe { &*urs };
    let bounds = unsafe { &*bounds };
    let comms : Vec<_> = bounds.iter().map(|b| {
        let p = DensePolynomial::<Fp>::from_coefficients_vec((0..*b).map(|i| {
            if i == 0 {
                Fp::one()
            } else {
                Fp::zero()
            }
        }).collect());
        urs.commit_with_degree_bound(&p, *b).unwrap()
    }).collect();

    let cs = comms.iter().map(|(_, c)| *c);
    let ss = comms.iter().map(|(s, _)| *s);

    let rs : Vec<Fp> = bounds.iter().enumerate().map(|(_, i)| ((i + 2) as u64).into()).collect();

    let shifted = ss.zip(rs.iter()).map(|(s, r)| s.into_projective() * r)
        .fold(G1Projective::zero(), |acc, x| acc + &x).into_affine();

    let mut res = vec![ shifted ];
    res.extend(
        cs.zip(rs).map(|(c, r)| (c.into_projective() * &r).into_affine()));

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_urs_dummy_opening_check(
    urs : *const URS<Bn_382>)
-> *const (G1Affine, G1Affine) {
    /*
       (f - [v] + z pi, pi)

       for the accumulator for the check

       e(f - [v] + z pi, H) = e(pi, beta*H)
    */
    let urs = unsafe { &*urs };

    let z = Fp::one();
    let p = DensePolynomial::<Fp>::from_coefficients_vec(vec![Fp::one(), Fp::one()]);
    let f = urs.commit(&p).unwrap();
    let v = p.evaluate(z);
    let pi = urs.open(vec![&p], Fp::one(), z).unwrap();

    let res = ((f.into_projective() -
     &(G1Projective::prime_subgroup_generator() * &v)
     + & (pi.into_projective() * &z)).into_affine(),
     pi);

    Box::into_raw(Box::new(res))
}

// Fq URS stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_urs_create(depth : usize) -> *const SRS<GAffine> {
    Box::into_raw(Box::new(SRS::create(depth)))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_urs_write(urs : *mut SRS<GAffine>, path: *mut c_char) {
    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let file = BufWriter::new(File::create(path).unwrap());
    let urs = unsafe { &*urs };
    let _ = urs.write(file);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_urs_read(path: *mut c_char) -> *const SRS<GAffine> {
    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let file = BufReader::new(File::open(path).unwrap());
    let res = SRS::<GAffine>::read(file).unwrap();
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_urs_lagrange_commitment(
    urs : *const SRS<GAffine>,
    domain_size : usize,
    i: usize)
-> *const PolyComm<GAffine> {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fq>::new(domain_size).unwrap();

    let evals = (0..domain_size).map(|j| if i == j { Fq::one() } else { Fq::zero() }).collect();
    let p = Evaluations::<Fq>::from_vec_and_domain(evals, x_domain).interpolate();
    let res = urs.commit(&p, None);

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_urs_commit_evaluations(
    urs : *const SRS<GAffine>,
    domain_size : usize,
    evals : *const Vec<Fq>)
-> *const PolyComm<GAffine> {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fq>::new(domain_size).unwrap();

    let evals = unsafe { &*evals };
    let p = Evaluations::<Fq>::from_vec_and_domain(evals.clone(), x_domain).interpolate();
    let res = urs.commit(&p, None);

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_urs_b_poly_commitment(
    urs : *const SRS<GAffine>,
    chals : *const Vec<Fq>)
-> *const PolyComm<GAffine> {
    let chals = unsafe { & *chals };
    let urs = unsafe { &*urs };

    let s0 = product(chals.iter().map(|x| *x)).inverse().unwrap();
    let chal_squareds : Vec<Fq> = chals.iter().map(|x| x.square()).collect();
    let coeffs = b_poly_coefficients(s0, &chal_squareds);
    let p = DensePolynomial::<Fq>::from_coefficients_vec(coeffs);
    let g = urs.commit(&p, None);

    Box::into_raw(Box::new(g))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_urs_h(
    urs : *const SRS<GAffine>, )
-> *const GAffine {
    let urs = unsafe { &*urs };
    let res = urs.h;
    Box::into_raw(Box::new(res))
}

// Fp index stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_domain_h_size<'a>(i : *const Index<'a, Bn_382>) -> usize {
    (unsafe { & *i }).domains.h.size()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_domain_k_size<'a>(i : *const Index<'a, Bn_382>) -> usize {
    (unsafe { & *i }).domains.k.size()
}

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

    let m = if num_constraints > vars { num_constraints } else { vars };

    let h_group_size = EvaluationDomain::<Fp>::compute_size_of_domain(m).unwrap();
    let h_to_x_ratio = {
        let x_group_size = EvaluationDomain::<Fp>::compute_size_of_domain(public_inputs).unwrap();
        h_group_size / x_group_size
    };

    return Box::into_raw(Box::new(
        Index::<Bn_382>::create(
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, a),
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, b),
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, c),
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

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_write<'a>(
    index : *const Index<'a, Bn_382>,
    path: *const c_char) {

    fn write_compiled<W:Write>(c: &circuits_pairing::compiled::Compiled<Bn_382>, mut w:W) -> IoResult<()> {
        c.col_comm.write(&mut w)?;
        c.row_comm.write(&mut w)?;
        c.val_comm.write(&mut w)?;
        c.rc_comm.write(&mut w)?;
        write_dense_polynomial(&c.rc, &mut w)?;
        write_dense_polynomial(&c.row, &mut w)?;
        write_dense_polynomial(&c.col, &mut w)?;
        write_dense_polynomial(&c.val, &mut w)?;
        write_evaluations(& c.row_eval_k, &mut w)?;
        write_evaluations(& c.col_eval_k, &mut w)?;
        write_evaluations(& c.val_eval_k, &mut w)?;
        write_evaluations(& c.row_eval_b, &mut w)?;
        write_evaluations(& c.col_eval_b, &mut w)?;
        write_evaluations(& c.val_eval_b, &mut w)?;
        write_evaluations(& c.rc_eval_b , &mut w)?;
        Ok(())
    }

    let index = unsafe { & *index };

    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut w = BufWriter::new(File::create(path).unwrap());

    let t : IoResult<()> = (|| {
        write_evaluation_domains(&index.domains, &mut w)?;

        for c in index.compiled.iter() {
            write_compiled(c, &mut w)?;
        }

        u64::write(&(index.public_inputs as u64), &mut w)?;
        Ok(())
    })();
    t.unwrap()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fp_index_read<'a>(
    srs : *const URS<Bn_382>,
    a: *const Vec<(Vec<usize>, Vec<Fp>)>,
    b: *const Vec<(Vec<usize>, Vec<Fp>)>,
    c: *const Vec<(Vec<usize>, Vec<Fp>)>,
    public_inputs : usize,
    path: *const c_char) -> *const Index<'a, Bn_382> {

    fn read_compiled<R:Read>(public_inputs: usize, ds: EvaluationDomains<Fp>, m: *const Vec<(Vec<usize>, Vec<Fp>)>, mut r: R) -> IoResult<circuits_pairing::compiled::Compiled<Bn_382>> {
        let constraints = rows_to_csmat(public_inputs, ds.h.size(), ds.h.size() / ds.x.size(), unsafe { &*m });

        let col_comm = G1Affine::read(&mut r)?;
        let row_comm = G1Affine::read(&mut r)?;
        let val_comm = G1Affine::read(&mut r)?;
        let rc_comm = G1Affine::read(&mut r)?;
        let rc  = read_dense_polynomial(&mut r)?;
        let row = read_dense_polynomial(&mut r)?;
        let col = read_dense_polynomial(&mut r)?;
        let val = read_dense_polynomial(&mut r)?;
        let row_eval_k = read_evaluations(&mut r)?;
        let col_eval_k = read_evaluations(&mut r)?;
        let val_eval_k = read_evaluations(&mut r)?;
        let row_eval_b = read_evaluations(&mut r)?;
        let col_eval_b = read_evaluations(&mut r)?;
        let val_eval_b = read_evaluations(&mut r)?;
        let rc_eval_b  = read_evaluations(&mut r)?;

        Ok(circuits_pairing::compiled::Compiled {
            constraints,
            col_comm   ,
            row_comm   ,
            val_comm   ,
            rc_comm    ,
            rc         ,
            row        ,
            col        ,
            val        ,
            row_eval_k ,
            col_eval_k ,
            val_eval_k ,
            row_eval_b ,
            col_eval_b ,
            val_eval_b ,
            rc_eval_b   })
    }

    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut r = BufReader::new(File::open(path).unwrap());

    let srs = unsafe { &*srs };

    let t : IoResult<_> = (|| {
        let domains = read_evaluation_domains(&mut r)?;

        let c0 = read_compiled(public_inputs, domains, a, &mut r)?;
        let c1 = read_compiled(public_inputs, domains, b, &mut r)?;
        let c2 = read_compiled(public_inputs, domains, c, &mut r)?;

        let public_inputs = u64::read(&mut r)? as usize;
        let (endo_q, endo_r) = circuits_pairing::index::endos::<Bn_382>();
        Ok( Index::<Bn_382> {
            compiled: [c0, c1, c2],
            domains,
            public_inputs,
            urs: circuits_pairing::index::URSValue::Ref(srs),
            fr_sponge_params: oracle::bn_382::fp::params(),
            fq_sponge_params: oracle::bn_382::fq::params(),
            endo_q,
            endo_r
        })
    })();
    Box::into_raw(Box::new(t.unwrap()))
}

// Fq index stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_domain_h_size<'a>(i : *const DlogIndex<'a, GAffine>) -> usize {
    (unsafe { & *i }).domains.h.size()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_domain_k_size<'a>(i : *const DlogIndex<'a, GAffine>) -> usize {
    (unsafe { & *i }).domains.k.size()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_create<'a>(
    a: *mut Vec<(Vec<usize>, Vec<Fq>)>,
    b: *mut Vec<(Vec<usize>, Vec<Fq>)>,
    c: *mut Vec<(Vec<usize>, Vec<Fq>)>,
    vars: usize,
    public_inputs: usize,
    srs : *mut SRS<GAffine>
) -> *mut DlogIndex<'a, GAffine> {
    assert!(public_inputs > 0);

    let srs = unsafe { &*srs };
    let a = unsafe { &*a };
    let b = unsafe { &*b };
    let c = unsafe { &*c };

    let num_constraints = a.len();

    let m = if num_constraints > vars { num_constraints } else { vars };

    let h_group_size = EvaluationDomain::<Fq>::compute_size_of_domain(m).unwrap();
    let h_to_x_ratio = {
        let x_group_size = EvaluationDomain::<Fq>::compute_size_of_domain(public_inputs).unwrap();
        h_group_size / x_group_size
    };

    return Box::into_raw(Box::new(
        DlogIndex::<GAffine>::create(
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, a),
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, b),
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, c),
            public_inputs,
            srs.max_degree(),
            oracle::bn_382::fq::params(),
            oracle::bn_382::fp::params(),
            SRSSpec::Use(srs),
        )
        .unwrap(),
    ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_delete(x: *mut DlogIndex<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_nonzero_entries(
    index: *const DlogIndex<GAffine>,
) -> usize {
    let index = unsafe { &*index };
    index.compiled.iter().map(|x| x.constraints.nnz()).max().unwrap()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_max_degree(
    index: *const DlogIndex<GAffine>,
) -> usize {
    let index = unsafe { &*index };
    index.srs.get_ref().max_degree()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_num_variables(
    index: *const DlogIndex<GAffine>,
) -> usize {
    let index = unsafe { &*index };
    index.compiled[0].constraints.shape().0
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_public_inputs(
    index: *const DlogIndex<GAffine>,
) -> usize {
    let index = unsafe { &*index };
    index.public_inputs
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_write<'a>(
    index : *const DlogIndex<'a, GAffine>,
    path: *const c_char) {

    fn write_compiled<W:Write>(c: &circuits_dlog::compiled::Compiled<GAffine>, mut w:W) -> IoResult<()> {
        write_poly_comm(&c.col_comm, &mut w)?;
        write_poly_comm(&c.row_comm, &mut w)?;
        write_poly_comm(&c.val_comm, &mut w)?;
        write_poly_comm(&c.rc_comm, &mut w)?;
        write_dense_polynomial(&c.rc, &mut w)?;
        write_dense_polynomial(&c.row, &mut w)?;
        write_dense_polynomial(&c.col, &mut w)?;
        write_dense_polynomial(&c.val, &mut w)?;
        write_evaluations(& c.row_eval_k, &mut w)?;
        write_evaluations(& c.col_eval_k, &mut w)?;
        write_evaluations(& c.val_eval_k, &mut w)?;
        write_evaluations(& c.row_eval_b, &mut w)?;
        write_evaluations(& c.col_eval_b, &mut w)?;
        write_evaluations(& c.val_eval_b, &mut w)?;
        write_evaluations(& c.rc_eval_b , &mut w)?;
        Ok(())
    }

    let index = unsafe { & *index };

    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut w = BufWriter::new(File::create(path).unwrap());

    let t : IoResult<()> = (|| {
        write_evaluation_domains(&index.domains, &mut w)?;

        for c in index.compiled.iter() {
            write_compiled(c, &mut w)?;
        }

        u64::write(&(index.public_inputs as u64), &mut w)?;
        Ok(())
    })();
    t.unwrap()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_index_read<'a>(
    srs : *const SRS<GAffine>,
    a: *const Vec<(Vec<usize>, Vec<Fq>)>,
    b: *const Vec<(Vec<usize>, Vec<Fq>)>,
    c: *const Vec<(Vec<usize>, Vec<Fq>)>,
    public_inputs : usize,
    path: *const c_char) -> *const DlogIndex<'a, GAffine> {

    fn read_compiled<R:Read>(public_inputs: usize, ds: EvaluationDomains<Fq>, m: *const Vec<(Vec<usize>, Vec<Fq>)>, mut r: R) -> IoResult<circuits_dlog::compiled::Compiled<GAffine>> {
        let constraints = rows_to_csmat(public_inputs, ds.h.size(), ds.h.size() / ds.x.size(), unsafe { &*m });

        let col_comm = read_poly_comm(&mut r)?;
        let row_comm = read_poly_comm(&mut r)?;
        let val_comm = read_poly_comm(&mut r)?;
        let rc_comm =  read_poly_comm(&mut r)?;
        let rc  = read_dense_polynomial(&mut r)?;
        let row = read_dense_polynomial(&mut r)?;
        let col = read_dense_polynomial(&mut r)?;
        let val = read_dense_polynomial(&mut r)?;
        let row_eval_k = read_evaluations(&mut r)?;
        let col_eval_k = read_evaluations(&mut r)?;
        let val_eval_k = read_evaluations(&mut r)?;
        let row_eval_b = read_evaluations(&mut r)?;
        let col_eval_b = read_evaluations(&mut r)?;
        let val_eval_b = read_evaluations(&mut r)?;
        let rc_eval_b  = read_evaluations(&mut r)?;

        Ok(circuits_dlog::compiled::Compiled {
            constraints,
            col_comm   ,
            row_comm   ,
            val_comm   ,
            rc_comm    ,
            rc         ,
            row        ,
            col        ,
            val        ,
            row_eval_k ,
            col_eval_k ,
            val_eval_k ,
            row_eval_b ,
            col_eval_b ,
            val_eval_b ,
            rc_eval_b   })
    }

    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut r = BufReader::new(File::open(path).unwrap());

    let srs = unsafe { &*srs };

    let t : IoResult<_> = (|| {
        let domains = read_evaluation_domains(&mut r)?;

        let c0 = read_compiled(public_inputs, domains, a, &mut r)?;
        let c1 = read_compiled(public_inputs, domains, b, &mut r)?;
        let c2 = read_compiled(public_inputs, domains, c, &mut r)?;

        let public_inputs = u64::read(&mut r)? as usize;

        Ok( DlogIndex::<GAffine> {
            compiled: [c0, c1, c2],
            domains,
            public_inputs,
            max_poly_size: srs.max_degree(),
            srs: SRSValue::Ref(srs),
            fr_sponge_params: oracle::bn_382::fq::params(),
            fq_sponge_params: oracle::bn_382::fp::params(),
        })
    })();
    let res = Box::into_raw(Box::new(t.unwrap()));
    res
}

// Fq verifier index stubs
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_create(
    index: *const DlogIndex<GAffine>
) -> *const DlogVerifierIndex<GAffine> {
    Box::into_raw(Box::new(unsafe {&(*index)}.verifier_index()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_urs<'a>(
    index: *const DlogVerifierIndex<'a, GAffine>
) -> *const SRS<GAffine> {
    let index = unsafe { & *index };
    let urs = index.srs.get_ref().clone();
    Box::into_raw(Box::new(urs))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_make<'a>(
    public_inputs: usize,
    variables: usize,
    constraints: usize,
    nonzero_entries: usize,
    max_poly_size: usize,
    urs: *const SRS<GAffine>,
    row_a: *const PolyComm<GAffine>,
    col_a: *const PolyComm<GAffine>,
    val_a: *const PolyComm<GAffine>,
    rc_a: *const PolyComm<GAffine>,

    row_b: *const PolyComm<GAffine>,
    col_b: *const PolyComm<GAffine>,
    val_b: *const PolyComm<GAffine>,
    rc_b: *const PolyComm<GAffine>,

    row_c: *const PolyComm<GAffine>,
    col_c: *const PolyComm<GAffine>,
    val_c: *const PolyComm<GAffine>,
    rc_c: *const PolyComm<GAffine>,
) -> *const DlogVerifierIndex<'a, GAffine> {
    let srs : SRS<GAffine> = (unsafe { &*urs }).clone();
    let index = DlogVerifierIndex::<GAffine> {
        domains: EvaluationDomains::create(variables, constraints, public_inputs, nonzero_entries).unwrap(),
        matrix_commitments: [
            circuits_dlog::index::MatrixValues { row: (unsafe {&*row_a}).clone(), col: (unsafe {&*col_a}).clone(), val: (unsafe {&*val_a}).clone(), rc: (unsafe {&*rc_a}).clone() },
            circuits_dlog::index::MatrixValues { row: (unsafe {&*row_b}).clone(), col: (unsafe {&*col_b}).clone(), val: (unsafe {&*val_b}).clone(), rc: (unsafe {&*rc_b}).clone() },
            circuits_dlog::index::MatrixValues { row: (unsafe {&*row_c}).clone(), col: (unsafe {&*col_c}).clone(), val: (unsafe {&*val_c}).clone(), rc: (unsafe {&*rc_c}).clone() },
        ],
        fq_sponge_params: oracle::bn_382::fp::params(),
        fr_sponge_params: oracle::bn_382::fq::params(),
        max_poly_size,
        public_inputs,
        srs: SRSValue::Value(srs),
    };
    Box::into_raw(Box::new(index))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_delete(
    x: *mut DlogVerifierIndex<GAffine>
) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_write<'a>(
    index : *const DlogVerifierIndex<GAffine>,
    path: *const c_char) {
    let index = unsafe { & *index };

    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut w = BufWriter::new(File::create(path).unwrap());

    let t : IoResult<()> = (|| {
        for c in index.matrix_commitments.iter() {
            write_dlog_matrix_values(c, &mut w)?;
        }
        write_evaluation_domains(&index.domains, &mut w)?;
        u64::write(&(index.public_inputs as u64), &mut w)?;
        u64::write(&(index.max_poly_size as u64), &mut w)?;
        Ok(())
    })();
    t.unwrap()
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_read<'a>(
    srs : *const SRS<GAffine>,
    path: *const c_char) -> *const DlogVerifierIndex<'a, GAffine> {
    let srs = unsafe { &*srs };

    let path = (unsafe { CStr::from_ptr(path) }).to_string_lossy().into_owned();
    let mut r = BufReader::new(File::open(path).unwrap());

    let t : IoResult<_> = (|| {
        let m0 = read_dlog_matrix_values(&mut r)?;
        let m1 = read_dlog_matrix_values(&mut r)?;
        let m2 = read_dlog_matrix_values(&mut r)?;
        let domains = read_evaluation_domains(&mut r)?;
        let public_inputs = u64::read(&mut r)? as usize;
        let max_poly_size = u64::read(&mut r)? as usize;
        Ok(DlogVerifierIndex {
            matrix_commitments: [m0, m1, m2],
            domains,
            public_inputs,
            max_poly_size,
            srs: SRSValue::Ref(srs),
            fr_sponge_params: oracle::bn_382::fq::params(),
            fq_sponge_params: oracle::bn_382::fp::params(),
        })
    })();
    Box::into_raw(Box::new(t.unwrap()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_a_row_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[0].row }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_a_col_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[0].col }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_a_val_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[0].val }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_a_rc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[0].rc }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_b_row_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[1].row }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_b_col_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[1].col }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_b_val_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[1].val }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_b_rc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[1].rc }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_c_row_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[2].row }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_c_col_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[2].col }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_c_val_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[2].val }).clone()))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_verifier_index_c_rc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine>{
    Box::into_raw(Box::new((unsafe { &(*index).matrix_commitments[2].rc }).clone()))
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
pub extern "C" fn camlsnark_bn382_g_double(
    x: *const GProjective,
) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let ret = x_.double();
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
pub extern "C" fn camlsnark_bn382_g_affine_is_zero(p: *const GAffine) -> bool {
    let p = unsafe { &*p };
    return p.is_zero();
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
pub extern "C" fn camlsnark_bn382_g1_double(
    x: *const G1Projective,
) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let ret = x_.double();
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
pub extern "C" fn camlsnark_bn382_g1_affine_is_zero(p: *const G1Affine) -> bool {
    let p = unsafe { &*p };
    return p.is_zero();
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
pub extern "C" fn camlsnark_bn382_fq_endo_base() -> *const Fp {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    return Box::into_raw(Box::new(endo_q));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_endo_scalar() -> *const Fq {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    return Box::into_raw(Box::new(endo_r));
}

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
pub extern "C" fn camlsnark_bn382_fq_mut_square(x: *mut Fq) {
    let x_ = unsafe { &mut (*x) };
    x_.square_in_place();
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

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_to_bigint_raw(x: *const Fq) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr_raw()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_to_bigint_raw_noalloc(x: *const Fq) -> *const BigInteger384 {
    let x_ = unsafe { &(*x) };
    &x_.0 as *const BigInteger384
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_of_bigint_raw(x: *const BigInteger384) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fq::from_repr_raw(*x_)));
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
    let x = unsafe { (*x) };

    sponge.absorb(params, &[x]);
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

// Fq triple
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_triple_0(evals: *const [Fq; 3]) -> *const Fq {
    let x = (unsafe { (*evals) })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_triple_1(evals: *const [Fq; 3]) -> *const Fq {
    let x = (unsafe { (*evals) })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_triple_2(evals: *const [Fq; 3]) -> *const Fq {
    let x = (unsafe { (*evals) })[2].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_triple_0(evals: *const [Vec<Fq>; 3]) -> *const Vec<Fq> {
    let x = (unsafe { &(*evals) })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_triple_1(evals: *const [Vec<Fq>; 3]) -> *const Vec<Fq> {
    let x = (unsafe { &(*evals) })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_vector_triple_2(evals: *const [Vec<Fq>; 3]) -> *const Vec<Fq> {
    let x = (unsafe { &(*evals) })[2].clone();
    return Box::into_raw(Box::new(x));
}


// G1 affine pair#[no_mangle]
#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_0(
    p: *const (G1Affine, G1Affine)) -> *const G1Affine {
    let (x0, _) = unsafe { (*p)};
    return Box::into_raw(Box::new(x0.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_1(
    p: *const (G1Affine, G1Affine)) -> *const G1Affine {
    let (_, x1) = unsafe { (*p)};
    return Box::into_raw(Box::new(x1.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_make(x0 : *const G1Affine, x1 : *const G1Affine)
-> *const (G1Affine, G1Affine) {
    let res = ((unsafe { *x0 }), (unsafe { *x1 }));
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_vector_create() -> *mut Vec<(G1Affine, G1Affine)> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_vector_length(v: *const Vec<(G1Affine, G1Affine)>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_vector_emplace_back(v: *mut Vec<(G1Affine, G1Affine)>, x: *const (G1Affine, G1Affine)) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_vector_get(v: *mut Vec<(G1Affine, G1Affine)>, i: u32) -> *mut (G1Affine, G1Affine) {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g1_affine_pair_vector_delete(v: *mut Vec<(G1Affine, G1Affine)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// G affine pair
#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_0(
    p: *const (GAffine, GAffine)) -> *const GAffine {
    let (x0, _) = unsafe { (*p)};
    return Box::into_raw(Box::new(x0.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_1(
    p: *const (GAffine, GAffine)) -> *const GAffine {
    let (_, x1) = unsafe { (*p)};
    return Box::into_raw(Box::new(x1.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_make(x0 : *const GAffine, x1 : *const GAffine)
-> *const (GAffine, GAffine) {
    let res = ((unsafe { *x0 }), (unsafe { *x1 }));
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_vector_create() -> *mut Vec<(GAffine, GAffine)> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_vector_length(v: *const Vec<(GAffine, GAffine)>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_vector_emplace_back(v: *mut Vec<(GAffine, GAffine)>, x: *const (GAffine, GAffine)) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_vector_get(v: *mut Vec<(GAffine, GAffine)>, i: u32) -> *mut (GAffine, GAffine) {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_g_affine_pair_vector_delete(v: *mut Vec<(GAffine, GAffine)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fq oracles
pub struct FqOracles {
    o: protocol_dlog::prover::RandomOracles<Fq>,
    opening_prechallenges: Vec<ScalarChallenge<Fq>>,
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_create(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> *const FqOracles {
    let index = unsafe { &(*index) };
    let proof = unsafe { &(*proof) };

    let x_hat = 
        Evaluations::<Fq>::from_vec_and_domain(proof.public.clone(), index.domains.x).interpolate();
        // TODO: Should have no degree bound when we add the correct degree bound method
    let x_hat_comm = index.srs.get_ref().commit(&x_hat, None);

    let (mut sponge, o) = proof.oracles::<
        DefaultFqSponge<Bn_382GParameters>,
        DefaultFrSponge<Fq>,
        >(index, x_hat_comm, &x_hat);
    let opening_prechallenges = proof.proof.prechallenges(&mut sponge);

    return Box::into_raw(Box::new(FqOracles { o, opening_prechallenges }));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_opening_prechallenges(
    oracles: *const FqOracles
) -> *const Vec<Fq> {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).opening_prechallenges.iter().map(|x| x.0).collect() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_alpha(
    oracles: *const FqOracles
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.alpha.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_eta_a(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.eta_a.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_eta_b(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.eta_b.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_eta_c(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.eta_c.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_beta1(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.beta[0].0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_beta2(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.beta[1].0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_beta3(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.beta[2].0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_polys(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.polys.0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_evals(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.evals.0.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_x_hat_nocopy(
    oracles: *const FqOracles,
) -> *const [Vec<Fq>; 3] {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.x_hat.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_digest_before_evaluations(
    oracles: *const FqOracles,
) -> *const Fq {
    return Box::into_raw(Box::new( (unsafe {&(*oracles)}).o.digest_before_evaluations.clone() ));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_oracles_delete(
    x: *mut FqOracles,
    ) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fq proof
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_create(
    index: *const DlogIndex<GAffine>,
    primary_input: *const Vec<Fq>,
    auxiliary_input: *const Vec<Fq>,
    prev_challenges: *const Vec<Fq>,
    prev_sgs : *const Vec<GAffine>,
) -> *const DlogProof<GAffine> {
    let index = unsafe { &(*index) };
    let primary_input = unsafe { &(*primary_input) };
    let auxiliary_input = unsafe { &(*auxiliary_input) };

    let witness = prepare_witness(index.domains, primary_input, auxiliary_input);

    let prev : Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
        let prev_challenges = unsafe { &*prev_challenges};
        let prev_sgs = unsafe { &*prev_sgs };
        if prev_challenges.len() == 0 {Vec::new()} else
        {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs.iter().enumerate().map( |(i, sg)| {
                (
                    prev_challenges[(i * challenges_per_sg)..(i+1)*challenges_per_sg].iter().map(|x| *x).collect(),
                    PolyComm::<GAffine>{unshifted: vec![sg.clone()], shifted: None}
                )
            }).collect()
        }
    };
    
    let rng = &mut rand_core::OsRng;

    let map = <Affine as CommitmentCurve>::Map::setup();
    let proof = DlogProof::create::<DefaultFqSponge<Bn_382GParameters>, DefaultFrSponge<Fq> >
        (&map, &witness, &index, prev, rng).unwrap();

    return Box::into_raw(Box::new(proof));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> bool {

    let index = unsafe { &(*index) };
    let proof = unsafe { (*proof).clone() };
    let group_map = <Affine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<DefaultFqSponge<Bn_382GParameters>, DefaultFrSponge<Fq>>
    (
        &group_map,
        &[proof].to_vec(),
        &index,
        &mut rand_core::OsRng
    )
}

// TODO: Batch verify across different indexes
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_batch_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proofs: *const Vec<DlogProof<GAffine>>,
) -> bool {
    let index = unsafe { &(*index) };
    let proofs = unsafe { &(*proofs) };
    let group_map = <Affine as CommitmentCurve>::Map::setup();

    DlogProof::<GAffine>::verify::<DefaultFqSponge<Bn_382GParameters>, DefaultFrSponge<Fq> >(
        &group_map, proofs, index, &mut rand_core::OsRng)
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_make(
    primary_input : *const Vec<Fq>,

    w_comm        : *const PolyComm<GAffine>,
    za_comm       : *const PolyComm<GAffine>,
    zb_comm       : *const PolyComm<GAffine>,
    h1_comm       : *const PolyComm<GAffine>,
    g1_comm       : *const PolyComm<GAffine>,
    h2_comm       : *const PolyComm<GAffine>,
    g2_comm       : *const PolyComm<GAffine>,
    h3_comm       : *const PolyComm<GAffine>,
    g3_comm       : *const PolyComm<GAffine>,

    sigma2        : *const Fq,
    sigma3        : *const Fq, 

    lr : *const Vec<(GAffine, GAffine)>,
    z1 : *const Fq,
    z2 : *const Fq,
    delta : *const GAffine,
    sg : *const GAffine,

    evals0 : *const DlogProofEvaluations<Fq>,
    evals1 : *const DlogProofEvaluations<Fq>,
    evals2 : *const DlogProofEvaluations<Fq>,

    prev_challenges: *const Vec<Fq>,
    prev_sgs : *const Vec<GAffine>,
    ) -> *const DlogProof<GAffine> {

    let public = unsafe { &(*primary_input) }.clone();
    // public.resize(ceil_pow2(public.len()), Fq::zero());

    let prev : Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
        let prev_challenges = unsafe { &*prev_challenges};
        let prev_sgs = unsafe { &*prev_sgs };
        if prev_challenges.len() == 0 {Vec::new()} else
        {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs.iter().enumerate().map( |(i, sg)| {
                (
                    prev_challenges[(i * challenges_per_sg)..(i+1)*challenges_per_sg].iter().map(|x| *x).collect(),
                    PolyComm::<GAffine>{unshifted: vec![sg.clone()], shifted: None}
                )
            }).collect()
        }
    };

    let res = DlogProof {

        prev_challenges: prev,
        proof: OpeningProof {
            lr: (unsafe { &*lr }).clone(),
            z1: (unsafe { *z1 }).clone(),
            z2: (unsafe { *z2 }).clone(),
            delta: (unsafe { *delta }).clone(),
            sg: (unsafe { *sg }).clone(),
        },
        w_comm: (unsafe { &*w_comm }).clone(),
        za_comm: (unsafe { &*za_comm }).clone() ,
        zb_comm: (unsafe { &*zb_comm }).clone() ,
        h1_comm: (unsafe { &*h1_comm }).clone() ,
        g1_comm: (unsafe { &*g1_comm }).clone(),
        h2_comm: (unsafe { &*h2_comm }).clone() ,
        g2_comm: (unsafe { &*g2_comm }).clone(),
        h3_comm: (unsafe { &*h3_comm }).clone() ,
        g3_comm: (unsafe { &*g3_comm }).clone(),

        sigma2: (unsafe { *sigma2 }).clone(),
        sigma3: (unsafe { *sigma3 }).clone(),

        public,
        evals: [(unsafe { &*evals0 }).clone(), (unsafe {& *evals1 }).clone(), (unsafe { &*evals2 }).clone(), ],
    };
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_delete(x: *mut DlogProof<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_w_comm(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).w_comm )}).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_za_comm(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe {&((*p).za_comm )}).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_zb_comm(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe {&((*p).zb_comm )}).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_h1_comm(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe {&((*p).h1_comm )}).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_g1_comm_nocopy(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).g1_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_h2_comm(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe {&((*p).h2_comm )}).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_g2_comm_nocopy(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).g2_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_h3_comm(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).h3_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_g3_comm_nocopy(p: *mut DlogProof<GAffine>) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).g3_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_sigma2(p: *mut DlogProof<GAffine>) -> *const Fq {
    let x = (unsafe { (*p).sigma2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_sigma3(p: *mut DlogProof<GAffine>) -> *const Fq {
    let x = (unsafe { (*p).sigma3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_proof(p: *mut DlogProof<GAffine>) -> *const OpeningProof<GAffine> {
    let x = (unsafe { &(*p).proof }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evals_nocopy(p: *mut DlogProof<GAffine>) -> *const [DlogProofEvaluations<Fq>; 3] {
    let x = (unsafe { &(*p).evals }).clone();
    return Box::into_raw(Box::new(x));
}

// Fq proof vector

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_vector_create() -> *mut Vec<DlogProof<GAffine>> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_vector_length(v: *const Vec<DlogProof<GAffine>>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_vector_emplace_back(v: *mut Vec<DlogProof<GAffine>>, x: *const DlogProof<GAffine>) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(x_.clone());
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_vector_get(v: *mut Vec<DlogProof<GAffine>>, i: u32) -> *mut DlogProof<GAffine> {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize].clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_vector_delete(v: *mut Vec<DlogProof<GAffine>>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fq opening proof
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_opening_proof_delete(p: *mut OpeningProof<GAffine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(p) };
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_opening_proof_sg(p: *const OpeningProof<GAffine>) -> *const GAffine {
    let x = (unsafe { &(*p).sg }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_opening_proof_lr(p: *const OpeningProof<GAffine>) -> *const Vec<(GAffine, GAffine)> {
    let x = (unsafe { &(*p).lr }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_opening_proof_z1(p: *const OpeningProof<GAffine>) -> *const Fq {
    let x = (unsafe { &(*p).z1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_opening_proof_z2(p: *const OpeningProof<GAffine>) -> *const Fq {
    let x = (unsafe { &(*p).z2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_opening_proof_delta(p: *const OpeningProof<GAffine>) -> *const GAffine {
    let x = (unsafe { &(*p).delta }).clone();
    return Box::into_raw(Box::new(x));
}

// Fq proof evaluations

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_w(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).w }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_za(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).za }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_zb(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).zb }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_h1(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).h1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_h2(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).h2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_h3(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).h3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_g1(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).g1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_g2(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).g2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_g3(e: *const DlogProofEvaluations<Fq>) -> *const Vec<Fq> {
    let x = (unsafe { & (*e).g3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_row_nocopy(e: *const DlogProofEvaluations<Fq>) -> *const [Vec<Fq>; 3] {
    let x = (unsafe { &(*e).row }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_val_nocopy(e: *const DlogProofEvaluations<Fq>) -> *const [Vec<Fq>; 3] {
    let x = (unsafe { &(*e).val }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_col_nocopy(e: *const DlogProofEvaluations<Fq>) -> *const [Vec<Fq>; 3] {
    let x = (unsafe { &(*e).col }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_rc_nocopy(e: *const DlogProofEvaluations<Fq>) -> *const [Vec<Fq>; 3] {
    let x = (unsafe { &(*e).rc }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_triple_0(e: *const [DlogProofEvaluations<Fq>; 3]) -> *const DlogProofEvaluations<Fq> {
    let x = (unsafe { & (*e)[0] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_triple_1(e: *const [DlogProofEvaluations<Fq>; 3]) -> *const DlogProofEvaluations<Fq> {
    let x = (unsafe { & (*e)[1] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_triple_2(e: *const [DlogProofEvaluations<Fq>; 3]) -> *const DlogProofEvaluations<Fq> {
    let x = (unsafe { & (*e)[2] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_proof_evaluations_make(
    w: *const Vec<Fq>,
    za: *const Vec<Fq>,
    zb: *const Vec<Fq>,
    h1: *const Vec<Fq>,
    g1: *const Vec<Fq>,
    h2: *const Vec<Fq>,
    g2: *const Vec<Fq>,
    h3: *const Vec<Fq>,
    g3: *const Vec<Fq>,

    row_0: *const Vec<Fq>,
    row_1: *const Vec<Fq>,
    row_2: *const Vec<Fq>,

    col_0: *const Vec<Fq>,
    col_1: *const Vec<Fq>,
    col_2: *const Vec<Fq>,

    val_0: *const Vec<Fq>,
    val_1: *const Vec<Fq>,
    val_2: *const Vec<Fq>,

    rc_0: *const Vec<Fq>,
    rc_1: *const Vec<Fq>,
    rc_2: *const Vec<Fq>) -> *const DlogProofEvaluations<Fq> {
    let res : DlogProofEvaluations<Fq> = DlogProofEvaluations {
        w: (unsafe { &*w }).clone(),
        za: (unsafe { &*za }).clone(),
        zb: (unsafe { &*zb }).clone(),
        g1: (unsafe { &*g1 }).clone(),
        g2: (unsafe { &*g2 }).clone(),
        g3: (unsafe { &*g3 }).clone(),
        h1: (unsafe { &*h1 }).clone(),
        h2: (unsafe { &*h2 }).clone(),
        h3: (unsafe { &*h3 }).clone(),
        row:
            [ (unsafe {&*row_0}).clone(),
                (unsafe {&*row_1}).clone(),
                (unsafe {&*row_2}).clone() ],
        col:
            [ (unsafe {&*col_0}).clone(),
                (unsafe {&*col_1}).clone(),
                (unsafe {&*col_2}).clone() ],
        val:
            [ (unsafe {&*val_0}).clone(),
                (unsafe {&*val_1}).clone(),
                (unsafe {&*val_2}).clone() ],
        rc:
            [ (unsafe {&*rc_0}).clone(),
                (unsafe {&*rc_1}).clone(),
                (unsafe {&*rc_2}).clone() ],
    };

    return Box::into_raw(Box::new(res));
}

// fq poly comm
#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_poly_comm_unshifted(c: *const PolyComm<GAffine>) -> *const Vec<GAffine> {
    let c = unsafe {& (*c) };
    return Box::into_raw(Box::new(c.unshifted.clone()));
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_poly_comm_shifted(c: *const PolyComm<GAffine>) -> *const GAffine {
    let c = unsafe {& (*c) };
    match c.shifted {
        Some(g) => Box::into_raw(Box::new(g.clone())),
        None =>  std::ptr::null()
    }
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_poly_comm_make
(
    unshifted: *const Vec<GAffine>,
    shifted: *const GAffine
) -> *const PolyComm<GAffine>
{
    let unsh = unsafe {& (*unshifted) };

    let commitment = PolyComm
    {
        unshifted: unsh.clone(),
        shifted: if shifted == std::ptr::null() {None} else {Some ({let sh = unsafe {& (*shifted) }; *sh})}
    };

    Box::into_raw(Box::new(commitment))
}

#[no_mangle]
pub extern "C" fn camlsnark_bn382_fq_poly_comm_delete(c: *mut PolyComm<GAffine>) {
    let _box = unsafe { Box::from_raw(c) };
}
