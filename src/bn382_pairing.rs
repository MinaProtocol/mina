use crate::common::*;
use algebra::{
    FftField,
    biginteger::BigInteger384,
    bn_382::{
        fp::{Fp, FpParameters as Fp_params},
        fq::Fq,
        g1::Bn_382G1Parameters,
        Bn_382, G1Affine, G1Projective, G2Affine,
    },
    curves::{AffineCurve, PairingEngine, ProjectiveCurve},
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    FromBytes, One, ToBytes, UniformRand, Zero,
};
use commitment_pairing::urs::URS;
use ff_fft::{DensePolynomial, EvaluationDomain, Evaluations, Radix2EvaluationDomain as Domain};
use dlog_solver::{DetSquareRootField, decompose};
use marlin_circuits::domains::EvaluationDomains;
use marlin_protocol_pairing::index::{Index, MatrixValues, URSSpec, VerifierIndex};

use marlin_protocol_pairing::prover::{ProofEvaluations, ProverProof, RandomOracles};
use oracle::{
    self, poseidon,
    poseidon::{MarlinSpongeConstants as SC, Sponge},
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use rand::rngs::StdRng;
use rand_core;

use std::{
    ffi::CStr,
    fs::File,
    io::{BufReader, BufWriter, Read, Result as IoResult, Write},
    os::raw::c_char,
};

// Fp stubs

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_endo_base() -> *const Fq {
    let (endo_q, _endo_r) = marlin_protocol_pairing::index::endos::<Bn_382>();
    return Box::into_raw(Box::new(endo_q));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_endo_scalar() -> *const Fp {
    let (_endo_q, endo_r) = marlin_protocol_pairing::index::endos::<Bn_382>();
    return Box::into_raw(Box::new(endo_r));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_size_in_bits() -> i32 {
    return Fp_params::MODULUS_BITS as i32;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_size() -> *mut BigInteger384 {
    let ret = Fp_params::MODULUS;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_is_square(x: *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let s0 = x_.pow(Fp_params::MODULUS_MINUS_ONE_DIV_TWO);
    s0.is_zero() || s0.is_one()
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_sqrt(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = match x_.sqrt() {
        Some(x) => x,
        None => Fp::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_det_sqrt(x: *const Fq) -> *mut Fq {
    let x_ = unsafe { &(*x) };
    let ret = match x_.det_sqrt() {
        Some(x) => x,
        None => Fq::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_det_sqrt_witness(x: *const Fq) -> DetSqrtWitness<Fq> {
    let x_ = unsafe { &(*x) };
    match x_.det_sqrt() {
        Some(y) => {
            let (c, d) = decompose(&y);
            DetSqrtWitness {
                c:Box::into_raw(Box::new(c)),
                d,
                square_root: Box::into_raw(Box::new(y)),
                success: true
            }
        },
        None =>
            DetSqrtWitness {
                c:Box::into_raw(Box::new(Fq::zero())),
                d:0,
                square_root: Box::into_raw(Box::new(Fq::zero())),
                success: false
            }
    }
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_two_adic_root_of_unity() -> *mut Fp {
    Box::into_raw(Box::new(FftField::two_adic_root_of_unity()))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_random() -> *mut Fp {
    let ret: Fp = UniformRand::rand(&mut rand::thread_rng());
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_of_int(i: u64) -> *mut Fp {
    let ret = Fp::from(i);
    return Box::into_raw(Box::new(ret));
}

// TODO: Leaky
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_to_string(x: *const Fp) -> *const u8 {
    let x = unsafe { *x };
    let s: String = format!("{}", x);
    s.as_ptr()
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_inv(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = match x_.inverse() {
        Some(x) => x,
        None => Fp::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_square(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = x_.square();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_add(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_negate(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_mul(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ * y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_div(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ / y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_sub(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_mut_add(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ += y_;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_mut_mul(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ *= y_;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_mut_square(x: *mut Fp) {
    let x_ = unsafe { &mut (*x) };
    x_.square_in_place();
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_mut_sub(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ -= y_;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_copy(x: *mut Fp, y: *const Fp) {
    unsafe { (*x) = *y };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_rng(i: i32) -> *mut Fp {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    let ret: Fp = UniformRand::rand(&mut rng);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_delete(x: *mut Fp) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_print(x: *const Fp) {
    let x_ = unsafe { &(*x) };
    println!("{}", *x_);
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_equal(x: *const Fp, y: *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    return *x_ == *y_;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_to_bigint(x: *const Fp) -> *mut BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_of_bigint(x: *const BigInteger384) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fp::from_repr(*x_)));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_to_bigint_raw(x: *const Fp) -> *const BigInteger384 {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.0));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_to_bigint_raw_noalloc(x: *const Fp) -> *const BigInteger384 {
    let x_ = unsafe { &(*x) };
    &x_.0 as *const BigInteger384
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_of_bigint_raw(x: *const BigInteger384) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fp::new(*x_)));
}

// Fp vector stubs

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_create() -> *mut Vec<Fp> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_length(v: *const Vec<Fp>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_emplace_back(v: *mut Vec<Fp>, x: *const Fp) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_get(v: *mut Vec<Fp>, i: u32) -> *mut Fp {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_delete(v: *mut Vec<Fp>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp constraint-matrix stubs

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_constraint_matrix_create() -> *mut Vec<(Vec<usize>, Vec<Fp>)> {
    return Box::into_raw(Box::new(vec![]));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_constraint_matrix_append_row(
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
pub extern "C" fn zexe_bn382_fp_constraint_matrix_delete(x: *mut Vec<(Vec<usize>, Vec<Fp>)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

// Fp triple
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_triple_0(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_triple_1(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_triple_2(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[2].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_triple_0(evals: *const [Vec<Fp>; 3]) -> *const Vec<Fp> {
    let x = (unsafe { &(*evals) })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_triple_1(evals: *const [Vec<Fp>; 3]) -> *const Vec<Fp> {
    let x = (unsafe { &(*evals) })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_triple_2(evals: *const [Vec<Fp>; 3]) -> *const Vec<Fp> {
    let x = (unsafe { &(*evals) })[2].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_vector_triple_delete(x: *mut [Fp; 3]) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_batch_pairing_check(
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

    let u: Vec<Vec<G1Affine>> = (0..n)
        .map(|i| (0..k).map(|j| u[k * i + j]).collect())
        .collect();

    // Optimization: Parallelize
    // Optimization:
    //   Experiment with scalar multiplying the affine point by b^i before adding
    // into the   accumulator.
    for ((p_i, (s_i, t_i)), u_i) in p.iter().zip(s.iter().zip(t)).zip(u) {
        acc_beta_h *= b;
        acc_beta_h.add_assign_mixed(p_i);

        acc_h *= b;
        acc_h.add_assign_mixed(s_i);
        acc_h += &t_i.mul(a);

        for (j, u_ij) in u_i.iter().enumerate() {
            acc_d[j] *= b;
            acc_d[j].add_assign_mixed(u_ij);
        }
    }
    acc_beta_h *= -a;
    for acc_j in acc_d.iter_mut() {
        *acc_j = -(*acc_j);
    }

    let mut table = vec![
        (
            acc_h.into_affine().into(),
            G2Affine::prime_subgroup_generator().into(),
        ),
        (acc_beta_h.into_affine().into(), urs.hx.into()),
    ];
    for (acc_j, j) in acc_d.iter().zip(d) {
        table.push((acc_j.into_affine().into(), urs.hn[&(urs.depth - j)].into()));
    }

    Bn_382::final_exponentiation(&Bn_382::miller_loop(&table)).unwrap()
        == <Bn_382 as PairingEngine>::Fqk::one()
}

// Fp proof
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_create(
    index: *const Index<Bn_382>,
    primary_input: *const Vec<Fp>,
    auxiliary_input: *const Vec<Fp>,
) -> *const ProverProof<Bn_382> {
    let index = unsafe { &(*index) };
    let primary_input = unsafe { &(*primary_input) };
    let auxiliary_input = unsafe { &(*auxiliary_input) };

    let witness = prepare_witness(index.domains, primary_input, auxiliary_input);

    let proof = ProverProof::create::<
        DefaultFqSponge<Bn_382G1Parameters, SC>,
        DefaultFrSponge<Fp, SC>,
    >(&witness, &index)
    .unwrap();

    return Box::into_raw(Box::new(proof));
}

// TODO: Batch verify across different indexes
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_batch_verify(
    index: *const VerifierIndex<Bn_382>,
    proofs: *const Vec<ProverProof<Bn_382>>,
) -> bool {
    let index = unsafe { &(*index) };
    let proofs = unsafe { &(*proofs) };

    match ProverProof::<Bn_382>::verify::<
        DefaultFqSponge<Bn_382G1Parameters, SC>,
        DefaultFrSponge<Fp, SC>,
    >(proofs, index, &mut rand_core::OsRng)
    {
        Ok(_) => true,
        Err(_) => false,
    }
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_verify(
    index: *const VerifierIndex<Bn_382>,
    proof: *const ProverProof<Bn_382>,
) -> bool {
    let index = unsafe { &(*index) };
    let proof = unsafe { (*proof).clone() };

    match ProverProof::verify::<DefaultFqSponge<Bn_382G1Parameters, SC>, DefaultFrSponge<Fp, SC>>(
        &[proof].to_vec(),
        &index,
        &mut rand_core::OsRng,
    ) {
        Ok(status) => status,
        _ => false,
    }
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_make(
    primary_input: *const Vec<Fp>,

    w_comm: *const G1Affine,
    za_comm: *const G1Affine,
    zb_comm: *const G1Affine,
    h1_comm: *const G1Affine,
    g1_comm_0: *const G1Affine,
    g1_comm_1: *const G1Affine,
    h2_comm: *const G1Affine,
    g2_comm_0: *const G1Affine,
    g2_comm_1: *const G1Affine,
    h3_comm: *const G1Affine,
    g3_comm_0: *const G1Affine,
    g3_comm_1: *const G1Affine,
    proof1: *const G1Affine,
    proof2: *const G1Affine,
    proof3: *const G1Affine,

    sigma2: *const Fp,
    sigma3: *const Fp,

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
        za_comm: (unsafe { *za_comm }).clone(),
        zb_comm: (unsafe { *zb_comm }).clone(),
        h1_comm: (unsafe { *h1_comm }).clone(),
        g1_comm: (
            (unsafe { *g1_comm_0 }).clone(),
            (unsafe { *g1_comm_1 }).clone(),
        ),
        h2_comm: (unsafe { *h2_comm }).clone(),
        g2_comm: (
            (unsafe { *g2_comm_0 }).clone(),
            (unsafe { *g2_comm_1 }).clone(),
        ),
        h3_comm: (unsafe { *h3_comm }).clone(),
        g3_comm: (
            (unsafe { *g3_comm_0 }).clone(),
            (unsafe { *g3_comm_1 }).clone(),
        ),
        proof1: (unsafe { *proof1 }).clone(),
        proof2: (unsafe { *proof2 }).clone(),
        proof3: (unsafe { *proof3 }).clone(),
        public,
        sigma2: (unsafe { *sigma2 }).clone(),
        sigma3: (unsafe { *sigma3 }).clone(),
        evals: ProofEvaluations {
            w: (unsafe { *w }).clone(),
            za: (unsafe { *za }).clone(),
            zb: (unsafe { *zb }).clone(),
            h1: (unsafe { *h1 }).clone(),
            g1: (unsafe { *g1 }).clone(),
            h2: (unsafe { *h2 }).clone(),
            g2: (unsafe { *g2 }).clone(),
            h3: (unsafe { *h3 }).clone(),
            g3: (unsafe { *g3 }).clone(),
            row: [
                (unsafe { *row_0 }).clone(),
                (unsafe { *row_1 }).clone(),
                (unsafe { *row_2 }).clone(),
            ],
            col: [
                (unsafe { *col_0 }).clone(),
                (unsafe { *col_1 }).clone(),
                (unsafe { *col_2 }).clone(),
            ],
            val: [
                (unsafe { *val_0 }).clone(),
                (unsafe { *val_1 }).clone(),
                (unsafe { *val_2 }).clone(),
            ],
            rc: [
                (unsafe { *rc_0 }).clone(),
                (unsafe { *rc_1 }).clone(),
                (unsafe { *rc_2 }).clone(),
            ],
        },
    };

    return Box::into_raw(Box::new(proof));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_delete(x: *mut ProverProof<Bn_382>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_w_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).w_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_za_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).za_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_zb_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).zb_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_h1_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h1_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_g1_comm_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const (G1Affine, G1Affine) {
    let x = unsafe { (*p).g1_comm };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_h2_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h2_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_g2_comm_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const (G1Affine, G1Affine) {
    let x = unsafe { (*p).g2_comm };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_h3_comm(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).h3_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_g3_comm_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const (G1Affine, G1Affine) {
    let x = unsafe { (*p).g3_comm };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_commitment_with_degree_bound_0(
    p: *const (G1Affine, G1Affine),
) -> *const G1Affine {
    let (x0, _) = unsafe { *p };
    return Box::into_raw(Box::new(x0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_commitment_with_degree_bound_1(
    p: *const (G1Affine, G1Affine),
) -> *const G1Affine {
    let (_, x1) = unsafe { *p };
    return Box::into_raw(Box::new(x1.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_commitment_with_degree_bound_delete(x: *mut G1Affine) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_proof1(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).proof1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_proof2(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).proof2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_proof3(p: *mut ProverProof<Bn_382>) -> *const G1Affine {
    let x = (unsafe { (*p).proof3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_sigma2(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).sigma2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_sigma3(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).sigma3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_w_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.w }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_za_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.za }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_zb_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.zb }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_h1_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.h1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_g1_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.g1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_h2_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.h2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_g2_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.g2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_h3_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.h3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_g3_eval(p: *mut ProverProof<Bn_382>) -> *const Fp {
    let x = (unsafe { (*p).evals.g3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_row_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.row };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_col_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.col };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_val_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.val };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_rc_evals_nocopy(
    p: *mut ProverProof<Bn_382>,
) -> *const [Fp; 3] {
    let x = unsafe { (*p).evals.rc };
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_evals_0(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_evals_1(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_evals_2(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[2].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_evals_delete(x: *mut [Fp; 3]) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fp proof vector

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_vector_create() -> *mut Vec<ProverProof<Bn_382>> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_vector_length(v: *const Vec<ProverProof<Bn_382>>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_vector_emplace_back(
    v: *mut Vec<ProverProof<Bn_382>>,
    x: *const ProverProof<Bn_382>,
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(x_.clone());
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_vector_get(
    v: *mut Vec<ProverProof<Bn_382>>,
    i: u32,
) -> *mut ProverProof<Bn_382> {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new(v_[i as usize].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_proof_vector_delete(v: *mut Vec<ProverProof<Bn_382>>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp oracles
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_create(
    index: *const VerifierIndex<Bn_382>,
    proof: *const ProverProof<Bn_382>,
) -> *const RandomOracles<Fp> {
    let index = unsafe { &(*index) };
    let proof = unsafe { &(*proof) };

    let x_hat = evals_from_coeffs(proof.public.clone(), index.domains.x).interpolate();
    let x_hat_comm = index.urs.commit(&x_hat).unwrap();

    let oracles = proof
        .oracles::<DefaultFqSponge<Bn_382G1Parameters, SC>, DefaultFrSponge<Fp, SC>>(
            index, x_hat_comm, &x_hat,
        )
        .unwrap();
    return Box::into_raw(Box::new(oracles));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_alpha(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).alpha.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_eta_a(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).eta_a.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_eta_b(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).eta_b.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_eta_c(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).eta_c.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_beta1(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).beta[0].0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_beta2(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).beta[1].0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_beta3(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).beta[2].0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_r_k(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).r_k.0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_batch(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).batch.0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_r(oracles: *const RandomOracles<Fp>) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).r.0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_x_hat_beta1(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).x_hat_beta1.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_digest_before_evaluations(
    oracles: *const RandomOracles<Fp>,
) -> *const Fp {
    return Box::into_raw(Box::new(
        (unsafe { &(*oracles) }).digest_before_evaluations.clone(),
    ));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_oracles_delete(x: *mut RandomOracles<Fp>) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fp verifier index stubs
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_create(
    index: *const Index<Bn_382>,
) -> *const VerifierIndex<Bn_382> {
    Box::into_raw(Box::new(unsafe { &(*index) }.verifier_index()))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_urs(
    index: *const VerifierIndex<Bn_382>,
) -> *const URS<Bn_382> {
    let index = unsafe { &*index };
    let urs = index.urs.clone();
    Box::into_raw(Box::new(urs))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_make(
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
    let urs: URS<Bn_382> = (unsafe { &*urs }).clone();
    let (endo_q, endo_r) = marlin_protocol_pairing::index::endos::<Bn_382>();
    let index = VerifierIndex {
        domains: EvaluationDomains::create(variables, constraints, public_inputs, nonzero_entries)
            .unwrap(),
        matrix_commitments: [
            MatrixValues {
                row: (unsafe { *row_a }).clone(),
                col: (unsafe { *col_a }).clone(),
                val: (unsafe { *val_a }).clone(),
                rc: (unsafe { *rc_a }).clone(),
            },
            MatrixValues {
                row: (unsafe { *row_b }).clone(),
                col: (unsafe { *col_b }).clone(),
                val: (unsafe { *val_b }).clone(),
                rc: (unsafe { *rc_b }).clone(),
            },
            MatrixValues {
                row: (unsafe { *row_c }).clone(),
                col: (unsafe { *col_c }).clone(),
                val: (unsafe { *val_c }).clone(),
                rc: (unsafe { *rc_c }).clone(),
            },
        ],
        fq_sponge_params: oracle::bn_382::fq::params(),
        fr_sponge_params: oracle::bn_382::fp::params(),
        max_degree,
        public_inputs,
        urs,
        endo_q,
        endo_r,
    };
    Box::into_raw(Box::new(index))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_delete(x: *mut VerifierIndex<Bn_382>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_write<'a>(
    index: *const VerifierIndex<Bn_382>,
    path: *const c_char,
) {
    let index = unsafe { &*index };

    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let mut w = BufWriter::new(File::create(path).unwrap());

    let t: IoResult<()> = (|| {
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
pub extern "C" fn zexe_bn382_fp_verifier_index_read<'a>(
    path: *const c_char,
) -> *const VerifierIndex<Bn_382> {
    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let mut r = BufReader::new(File::open(path).unwrap());

    let t: IoResult<_> = (|| {
        let m0 = read_matrix_values(&mut r)?;
        let m1 = read_matrix_values(&mut r)?;
        let m2 = read_matrix_values(&mut r)?;
        let domains = read_evaluation_domains(&mut r)?;
        let public_inputs = u64::read(&mut r)? as usize;
        let max_degree = u64::read(&mut r)? as usize;
        let urs = URS::<Bn_382>::read(&mut r)?;
        let (endo_q, endo_r) = marlin_protocol_pairing::index::endos::<Bn_382>();
        Ok(VerifierIndex {
            matrix_commitments: [m0, m1, m2],
            domains,
            public_inputs,
            max_degree,
            urs,
            endo_q,
            endo_r,
            fr_sponge_params: oracle::bn_382::fp::params(),
            fq_sponge_params: oracle::bn_382::fq::params(),
        })
    })();
    Box::into_raw(Box::new(t.unwrap()))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_a_row_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[0].row }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_a_col_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[0].col }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_a_val_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[0].val }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_a_rc_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[0].rc }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_b_row_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[1].row }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_b_col_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[1].col }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_b_val_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[1].val }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_b_rc_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[1].rc }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_c_row_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[2].row }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_c_col_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[2].col }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_c_val_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[2].val }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_verifier_index_c_rc_comm(
    index: *const VerifierIndex<Bn_382>,
) -> *const G1Affine {
    Box::into_raw(Box::new(
        (unsafe { (*index).matrix_commitments[2].rc }).clone(),
    ))
}

// Fp URS stubs
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_create(depth: usize) -> *const URS<Bn_382> {
    Box::into_raw(Box::new(URS::create(
        depth,
        (0..depth).collect(),
        &mut rand_core::OsRng,
    )))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_delete(x: *mut URS<Bn_382>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_write(urs: *mut URS<Bn_382>, path: *mut c_char) {
    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let file = BufWriter::new(File::create(path).unwrap());
    let urs = unsafe { &*urs };
    let _ = urs.write(file);
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_read(path: *mut c_char) -> *const URS<Bn_382> {
    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let file = BufReader::new(File::open(path).unwrap());
    let res = URS::<Bn_382>::read(file).unwrap();
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_lagrange_commitment(
    urs: *const URS<Bn_382>,
    domain_size: usize,
    i: usize,
) -> *const G1Affine {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = (0..domain_size)
        .map(|j| if i == j { Fp::one() } else { Fp::zero() })
        .collect();
    let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
    let res = urs.commit(&p).unwrap();

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_commit_evaluations(
    urs: *const URS<Bn_382>,
    domain_size: usize,
    evals: *const Vec<Fp>,
) -> *const G1Affine {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = unsafe { &*evals };
    let p = Evaluations::<Fp>::from_vec_and_domain(evals.clone(), x_domain).interpolate();
    let res = urs.commit(&p).unwrap();

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_dummy_degree_bound_checks(
    urs: *const URS<Bn_382>,
    bounds: *const Vec<usize>,
) -> *const Vec<G1Affine> {
    let urs = unsafe { &*urs };
    let bounds = unsafe { &*bounds };
    let comms: Vec<_> = bounds
        .iter()
        .map(|b| {
            let p = DensePolynomial::<Fp>::from_coefficients_vec(
                (0..*b)
                    .map(|i| if i == 0 { Fp::one() } else { Fp::zero() })
                    .collect(),
            );
            urs.commit_with_degree_bound(&p, *b).unwrap()
        })
        .collect();

    let cs = comms.iter().map(|(_, c)| *c);
    let ss = comms.iter().map(|(s, _)| *s);

    let rs: Vec<Fp> = bounds
        .iter()
        .enumerate()
        .map(|(_, i)| ((i + 2) as u64).into())
        .collect();

    let shifted: G1Affine = ss
        .zip(rs.iter())
        .map(|(s, r)| s.mul(*r))
        .fold(G1Projective::zero(), |acc, x| acc + &x)
        .into_affine();

    let mut res = vec![shifted];
    res.extend(cs.zip(rs.iter()).map(|(c, r)| c.mul(*r).into_affine()));

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_urs_dummy_opening_check(
    urs: *const URS<Bn_382>,
) -> *const (G1Affine, G1Affine) {
    // (f - [v] + z pi, pi)
    //
    // for the accumulator for the check
    //
    // e(f - [v] + z pi, H) = e(pi, beta*H)
    let urs = unsafe { &*urs };

    let z = Fp::one();
    let p = DensePolynomial::<Fp>::from_coefficients_vec(vec![Fp::one(), Fp::one()]);
    let f = urs.commit(&p).unwrap();
    let v = p.evaluate(z);
    let pi = urs.open(vec![&p], Fp::one(), z).unwrap();

    let res = (
        (f.into_projective() - &(G1Affine::prime_subgroup_generator().mul(v)) + &pi.mul(z))
            .into_affine(),
        pi,
    );

    Box::into_raw(Box::new(res))
}

// Fp index stubs
#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_domain_h_size<'a>(i: *const Index<'a, Bn_382>) -> usize {
    (unsafe { &*i }).domains.h.size()
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_domain_k_size<'a>(i: *const Index<'a, Bn_382>) -> usize {
    (unsafe { &*i }).domains.k.size()
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_create<'a>(
    a: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    b: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    c: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    vars: usize,
    public_inputs: usize,
    urs: *mut URS<Bn_382>,
) -> *mut Index<'a, Bn_382> {
    assert!(public_inputs > 0);

    let urs = unsafe { &*urs };
    let a = unsafe { &*a };
    let b = unsafe { &*b };
    let c = unsafe { &*c };

    let num_constraints = a.len();

    let m = if num_constraints > vars {
        num_constraints
    } else {
        vars
    };

    let h_group_size = Domain::<Fp>::compute_size_of_domain(m).unwrap();
    let h_to_x_ratio = {
        let x_group_size = Domain::<Fp>::compute_size_of_domain(public_inputs).unwrap();
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
pub extern "C" fn zexe_bn382_fp_index_delete(x: *mut Index<Bn_382>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_nonzero_entries(index: *const Index<Bn_382>) -> usize {
    let index = unsafe { &*index };
    index
        .compiled
        .iter()
        .map(|x| x.constraints.nnz())
        .max()
        .unwrap()
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_max_degree(index: *const Index<Bn_382>) -> usize {
    let index = unsafe { &*index };
    index.urs.get_ref().max_degree()
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_num_variables(index: *const Index<Bn_382>) -> usize {
    let index = unsafe { &*index };
    index.compiled[0].constraints.shape().0
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_public_inputs(index: *const Index<Bn_382>) -> usize {
    let index = unsafe { &*index };
    index.public_inputs
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fp_index_write<'a>(
    index: *const Index<'a, Bn_382>,
    path: *const c_char,
) {
    fn write_compiled<W: Write>(
        c: &marlin_protocol_pairing::compiled::Compiled<Bn_382>,
        mut w: W,
    ) -> IoResult<()> {
        c.col_comm.write(&mut w)?;
        c.row_comm.write(&mut w)?;
        c.val_comm.write(&mut w)?;
        c.rc_comm.write(&mut w)?;
        write_dense_polynomial(&c.rc, &mut w)?;
        write_dense_polynomial(&c.row, &mut w)?;
        write_dense_polynomial(&c.col, &mut w)?;
        write_dense_polynomial(&c.val, &mut w)?;
        write_evaluations(&c.row_eval_k, &mut w)?;
        write_evaluations(&c.col_eval_k, &mut w)?;
        write_evaluations(&c.val_eval_k, &mut w)?;
        write_evaluations(&c.row_eval_b, &mut w)?;
        write_evaluations(&c.col_eval_b, &mut w)?;
        write_evaluations(&c.val_eval_b, &mut w)?;
        write_evaluations(&c.rc_eval_b, &mut w)?;
        Ok(())
    }

    let index = unsafe { &*index };

    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let mut w = BufWriter::new(File::create(path).unwrap());

    let t: IoResult<()> = (|| {
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
pub extern "C" fn zexe_bn382_fp_index_read<'a>(
    srs: *const URS<Bn_382>,
    a: *const Vec<(Vec<usize>, Vec<Fp>)>,
    b: *const Vec<(Vec<usize>, Vec<Fp>)>,
    c: *const Vec<(Vec<usize>, Vec<Fp>)>,
    public_inputs: usize,
    path: *const c_char,
) -> *const Index<'a, Bn_382> {
    fn read_compiled<R: Read>(
        public_inputs: usize,
        ds: EvaluationDomains<Fp>,
        m: *const Vec<(Vec<usize>, Vec<Fp>)>,
        mut r: R,
    ) -> IoResult<marlin_protocol_pairing::compiled::Compiled<Bn_382>> {
        let constraints = rows_to_csmat(
            public_inputs,
            ds.h.size(),
            ds.h.size() / ds.x.size(),
            unsafe { &*m },
        );

        let col_comm = G1Affine::read(&mut r)?;
        let row_comm = G1Affine::read(&mut r)?;
        let val_comm = G1Affine::read(&mut r)?;
        let rc_comm = G1Affine::read(&mut r)?;
        let rc = read_dense_polynomial(&mut r)?;
        let row = read_dense_polynomial(&mut r)?;
        let col = read_dense_polynomial(&mut r)?;
        let val = read_dense_polynomial(&mut r)?;
        let row_eval_k = read_evaluations(&mut r)?;
        let col_eval_k = read_evaluations(&mut r)?;
        let val_eval_k = read_evaluations(&mut r)?;
        let row_eval_b = read_evaluations(&mut r)?;
        let col_eval_b = read_evaluations(&mut r)?;
        let val_eval_b = read_evaluations(&mut r)?;
        let rc_eval_b = read_evaluations(&mut r)?;

        Ok(marlin_protocol_pairing::compiled::Compiled {
            constraints,
            col_comm,
            row_comm,
            val_comm,
            rc_comm,
            rc,
            row,
            col,
            val,
            row_eval_k,
            col_eval_k,
            val_eval_k,
            row_eval_b,
            col_eval_b,
            val_eval_b,
            rc_eval_b,
        })
    }

    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let mut r = BufReader::new(File::open(path).unwrap());

    let srs = unsafe { &*srs };

    let t: IoResult<_> = (|| {
        let domains = read_evaluation_domains(&mut r)?;

        let c0 = read_compiled(public_inputs, domains, a, &mut r)?;
        let c1 = read_compiled(public_inputs, domains, b, &mut r)?;
        let c2 = read_compiled(public_inputs, domains, c, &mut r)?;

        let public_inputs = u64::read(&mut r)? as usize;
        let (endo_q, endo_r) = marlin_protocol_pairing::index::endos::<Bn_382>();
        Ok(Index::<Bn_382> {
            compiled: [c0, c1, c2],
            domains,
            public_inputs,
            urs: marlin_protocol_pairing::index::URSValue::Ref(srs),
            fr_sponge_params: oracle::bn_382::fp::params(),
            fq_sponge_params: oracle::bn_382::fq::params(),
            endo_q,
            endo_r,
        })
    })();
    Box::into_raw(Box::new(t.unwrap()))
}

// G1 / Fq stubs
#[no_mangle]
pub extern "C" fn zexe_bn382_g1_random() -> *const G1Projective {
    let rng = &mut rand_core::OsRng;
    Box::into_raw(Box::new(G1Projective::rand(rng)))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_delete(x: *mut G1Projective) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_one() -> *const G1Projective {
    let ret = G1Projective::prime_subgroup_generator();
    Box::into_raw(Box::new(ret))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_add(
    x: *const G1Projective,
    y: *const G1Projective,
) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_double(x: *const G1Projective) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let ret = x_.double();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_scale(x: *const G1Projective, s: *const Fp) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let s_ = unsafe { &(*s) };
    let ret = (*x_).mul(*s_);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_sub(
    x: *const G1Projective,
    y: *const G1Projective,
) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_negate(x: *const G1Projective) -> *const G1Projective {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_to_affine(p: *const G1Projective) -> *const G1Affine {
    let p = unsafe { *p };
    let q = p.clone().into_affine();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_of_affine(p: *const G1Affine) -> *const G1Projective {
    let p = unsafe { *p };
    let q = p.clone().into_projective();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_of_affine_coordinates(
    x: *const Fq,
    y: *const Fq,
) -> *const G1Projective {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    return Box::into_raw(Box::new(G1Projective::new(x, y, Fq::one())));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_create(x: *const Fq, y: *const Fq) -> *const G1Affine {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    Box::into_raw(Box::new(G1Affine::new(x, y, false)))
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_x(p: *const G1Affine) -> *const Fq {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.x.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_y(p: *const G1Affine) -> *const Fq {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.y.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_is_zero(p: *const G1Affine) -> bool {
    let p = unsafe { &*p };
    return p.is_zero();
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_delete(x: *mut G1Affine) {
    let _box = unsafe { Box::from_raw(x) };
}

// G1 vector stubs

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_vector_create() -> *mut Vec<G1Affine> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_vector_length(v: *const Vec<G1Affine>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_vector_emplace_back(
    v: *mut Vec<G1Affine>,
    x: *const G1Affine,
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_vector_get(v: *mut Vec<G1Affine>, i: u32) -> *mut G1Affine {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_vector_delete(v: *mut Vec<G1Affine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fq sponge stubs

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_sponge_params_create() -> *mut poseidon::ArithmeticSpongeParams<Fq>
{
    let ret = oracle::bn_382::fq::params();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_sponge_params_delete(x: *mut poseidon::ArithmeticSpongeParams<Fq>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_sponge_create() -> *mut poseidon::ArithmeticSponge<Fq, SC> {
    let ret = oracle::poseidon::ArithmeticSponge::<Fq, SC>::new();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_sponge_delete(x: *mut poseidon::ArithmeticSponge<Fp, SC>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_sponge_absorb(
    sponge: *mut poseidon::ArithmeticSponge<Fq, SC>,
    params: *const poseidon::ArithmeticSpongeParams<Fq>,
    x: *const Fq,
) {
    let sponge = unsafe { &mut (*sponge) };
    let params = unsafe { &(*params) };
    let x = unsafe { *x };

    sponge.absorb(params, &[x]);
}

#[no_mangle]
pub extern "C" fn zexe_bn382_fq_sponge_squeeze(
    sponge: *mut poseidon::ArithmeticSponge<Fq, SC>,
    params: *const poseidon::ArithmeticSpongeParams<Fq>,
) -> *mut Fq {
    let sponge = unsafe { &mut (*sponge) };
    let params = unsafe { &(*params) };

    let ret = sponge.squeeze(params);
    Box::into_raw(Box::new(ret))
}

// G1 affine pair#[no_mangle]
#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_0(p: *const (G1Affine, G1Affine)) -> *const G1Affine {
    let (x0, _) = unsafe { *p };
    return Box::into_raw(Box::new(x0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_1(p: *const (G1Affine, G1Affine)) -> *const G1Affine {
    let (_, x1) = unsafe { *p };
    return Box::into_raw(Box::new(x1.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_make(
    x0: *const G1Affine,
    x1: *const G1Affine,
) -> *const (G1Affine, G1Affine) {
    let res = ((unsafe { *x0 }), (unsafe { *x1 }));
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_delete(x: *mut (G1Affine, G1Affine)) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_vector_create() -> *mut Vec<(G1Affine, G1Affine)> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_vector_length(
    v: *const Vec<(G1Affine, G1Affine)>,
) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_vector_emplace_back(
    v: *mut Vec<(G1Affine, G1Affine)>,
    x: *const (G1Affine, G1Affine),
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_vector_get(
    v: *mut Vec<(G1Affine, G1Affine)>,
    i: u32,
) -> *mut (G1Affine, G1Affine) {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn zexe_bn382_g1_affine_pair_vector_delete(v: *mut Vec<(G1Affine, G1Affine)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}
