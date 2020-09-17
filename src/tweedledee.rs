use crate::common::*;
use algebra::{
    biginteger::BigInteger256 as BigInteger,
    curves::{AffineCurve, ProjectiveCurve},
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    tweedle::{
        dee::{Affine as GAffine, Projective as GProjective, TweedledeeParameters},
        fp::{Fp, FpParameters as Fp_params},
        fq::Fq,
    },
    FromBytes, One, ToBytes, UniformRand, Zero,
};

use marlin_circuits::domains::EvaluationDomains;

use ff_fft::{DensePolynomial, EvaluationDomain, Evaluations, Radix2EvaluationDomain as Domain};

use oracle::{
    self,
    poseidon::MarlinSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge, ScalarChallenge},
};

use rand::rngs::StdRng;
use rand_core;

use groupmap::GroupMap;
use std::{
    ffi::CStr,
    fs::File,
    io::{BufReader, BufWriter, Read, Result as IoResult, Write},
    os::raw::c_char,
};

use commitment_dlog::{
    commitment::{b_poly_coefficients, product, CommitmentCurve, OpeningProof, PolyComm},
    srs::SRS,
};
use marlin_protocol_dlog::index::{
    Index as DlogIndex, SRSSpec, SRSValue, VerifierIndex as DlogVerifierIndex,
};
use marlin_protocol_dlog::prover::{
    ProofEvaluations as DlogProofEvaluations, ProverProof as DlogProof,
};

// Fp URS stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_create(
    depth: usize,
    public: usize,
    size: usize,
) -> *const SRS<GAffine> {
    Box::into_raw(Box::new(SRS::create(depth, public, size)))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_delete(x: *mut SRS<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_write(urs: *mut SRS<GAffine>, path: *mut c_char) {
    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let file = BufWriter::new(File::create(path).unwrap());
    let urs = unsafe { &*urs };
    let _ = urs.write(file);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_read(path: *mut c_char) -> *const SRS<GAffine> {
    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let file = BufReader::new(File::open(path).unwrap());
    let res = SRS::<GAffine>::read(file).unwrap();
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_lagrange_commitment(
    urs: *const SRS<GAffine>,
    domain_size: usize,
    i: usize,
) -> *const PolyComm<GAffine> {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = (0..domain_size)
        .map(|j| if i == j { Fp::one() } else { Fp::zero() })
        .collect();
    let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
    let res = urs.commit(&p, None);

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_commit_evaluations(
    urs: *const SRS<GAffine>,
    domain_size: usize,
    evals: *const Vec<Fp>,
) -> *const PolyComm<GAffine> {
    let urs = unsafe { &*urs };
    let x_domain = EvaluationDomain::<Fp>::new(domain_size).unwrap();

    let evals = unsafe { &*evals };
    let p = Evaluations::<Fp>::from_vec_and_domain(evals.clone(), x_domain).interpolate();
    let res = urs.commit(&p, None);

    Box::into_raw(Box::new(res))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_b_poly_commitment(
    urs: *const SRS<GAffine>,
    chals: *const Vec<Fp>,
) -> *const PolyComm<GAffine> {
    let chals = unsafe { &*chals };
    let urs = unsafe { &*urs };

    let s0 = product(chals.iter().map(|x| *x)).inverse().unwrap();
    let chal_squareds: Vec<Fp> = chals.iter().map(|x| x.square()).collect();
    let coeffs = b_poly_coefficients(s0, &chal_squareds);
    let p = DensePolynomial::<Fp>::from_coefficients_vec(coeffs);
    let g = urs.commit(&p, None);

    Box::into_raw(Box::new(g))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_batch_accumulator_check(
    urs: *const SRS<GAffine>,
    comms: *const Vec<GAffine>,
    chals: *const Vec<Fp>,
) -> bool {
    let urs = unsafe { &*urs };
    let comms = unsafe { &*comms };
    let chals = unsafe { &*chals };
    batch_dlog_accumulator_check(urs, comms, chals)
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_urs_h(urs: *const SRS<GAffine>) -> *const GAffine {
    let urs = unsafe { &*urs };
    let res = urs.h;
    Box::into_raw(Box::new(res))
}

// Fp index stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_domain_h_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).domains.h.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_domain_k_size<'a>(
    i: *const DlogIndex<'a, GAffine>,
) -> usize {
    (unsafe { &*i }).domains.k.size()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_create<'a>(
    a: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    b: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    c: *mut Vec<(Vec<usize>, Vec<Fp>)>,
    vars: usize,
    public_inputs: usize,
    srs: *mut SRS<GAffine>,
) -> *mut DlogIndex<'a, GAffine> {
    assert!(public_inputs > 0);

    let srs = unsafe { &*srs };
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
        DlogIndex::<GAffine>::create(
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, a),
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, b),
            rows_to_csmat(public_inputs, h_group_size, h_to_x_ratio, c),
            public_inputs,
            srs.max_degree(),
            oracle::tweedle::fp::params(),
            oracle::tweedle::fq::params(),
            SRSSpec::Use(srs),
        )
        .unwrap(),
    ));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_delete(x: *mut DlogIndex<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_nonzero_entries(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index
        .compiled
        .iter()
        .map(|x| x.constraints.nnz())
        .max()
        .unwrap()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_max_degree(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index.srs.get_ref().max_degree()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_num_variables(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index.compiled[0].constraints.shape().0
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_public_inputs(index: *const DlogIndex<GAffine>) -> usize {
    let index = unsafe { &*index };
    index.public_inputs
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_index_write<'a>(
    index: *const DlogIndex<'a, GAffine>,
    path: *const c_char,
) {
    fn write_compiled<W: Write>(
        c: &marlin_protocol_dlog::compiled::Compiled<GAffine>,
        mut w: W,
    ) -> IoResult<()> {
        write_poly_comm(&c.col_comm, &mut w)?;
        write_poly_comm(&c.row_comm, &mut w)?;
        write_poly_comm(&c.val_comm, &mut w)?;
        write_poly_comm(&c.rc_comm, &mut w)?;
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
pub extern "C" fn zexe_tweedle_fp_index_read<'a>(
    srs: *const SRS<GAffine>,
    a: *const Vec<(Vec<usize>, Vec<Fp>)>,
    b: *const Vec<(Vec<usize>, Vec<Fp>)>,
    c: *const Vec<(Vec<usize>, Vec<Fp>)>,
    public_inputs: usize,
    path: *const c_char,
) -> *const DlogIndex<'a, GAffine> {
    fn read_compiled<R: Read>(
        public_inputs: usize,
        ds: EvaluationDomains<Fp>,
        m: *const Vec<(Vec<usize>, Vec<Fp>)>,
        mut r: R,
    ) -> IoResult<marlin_protocol_dlog::compiled::Compiled<GAffine>> {
        let constraints = rows_to_csmat(
            public_inputs,
            ds.h.size(),
            ds.h.size() / ds.x.size(),
            unsafe { &*m },
        );

        let col_comm = read_poly_comm(&mut r)?;
        let row_comm = read_poly_comm(&mut r)?;
        let val_comm = read_poly_comm(&mut r)?;
        let rc_comm = read_poly_comm(&mut r)?;
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

        Ok(marlin_protocol_dlog::compiled::Compiled {
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

        Ok(DlogIndex::<GAffine> {
            compiled: [c0, c1, c2],
            domains,
            public_inputs,
            max_poly_size: srs.max_degree(),
            srs: SRSValue::Ref(srs),
            fr_sponge_params: oracle::tweedle::fp::params(),
            fq_sponge_params: oracle::tweedle::fq::params(),
        })
    })();
    let res = Box::into_raw(Box::new(t.unwrap()));
    res
}

// Fp verifier index stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_create(
    index: *const DlogIndex<GAffine>,
) -> *const DlogVerifierIndex<GAffine> {
    Box::into_raw(Box::new(unsafe { &(*index) }.verifier_index()))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_urs<'a>(
    index: *const DlogVerifierIndex<'a, GAffine>,
) -> *const SRS<GAffine> {
    let index = unsafe { &*index };
    let urs = index.srs.get_ref().clone();
    Box::into_raw(Box::new(urs))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_make<'a>(
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
    let srs: SRS<GAffine> = (unsafe { &*urs }).clone();
    let index = DlogVerifierIndex::<GAffine> {
        domains: EvaluationDomains::create(variables, constraints, public_inputs, nonzero_entries)
            .unwrap(),
        matrix_commitments: [
            marlin_protocol_dlog::index::MatrixValues {
                row: (unsafe { &*row_a }).clone(),
                col: (unsafe { &*col_a }).clone(),
                val: (unsafe { &*val_a }).clone(),
                rc: (unsafe { &*rc_a }).clone(),
            },
            marlin_protocol_dlog::index::MatrixValues {
                row: (unsafe { &*row_b }).clone(),
                col: (unsafe { &*col_b }).clone(),
                val: (unsafe { &*val_b }).clone(),
                rc: (unsafe { &*rc_b }).clone(),
            },
            marlin_protocol_dlog::index::MatrixValues {
                row: (unsafe { &*row_c }).clone(),
                col: (unsafe { &*col_c }).clone(),
                val: (unsafe { &*val_c }).clone(),
                rc: (unsafe { &*rc_c }).clone(),
            },
        ],
        fq_sponge_params: oracle::tweedle::fq::params(),
        fr_sponge_params: oracle::tweedle::fp::params(),
        max_poly_size,
        public_inputs,
        srs: SRSValue::Value(srs),
    };
    Box::into_raw(Box::new(index))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_delete(x: *mut DlogVerifierIndex<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_write<'a>(
    index: *const DlogVerifierIndex<GAffine>,
    path: *const c_char,
) {
    let index = unsafe { &*index };

    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let mut w = BufWriter::new(File::create(path).unwrap());

    let t: IoResult<()> = (|| {
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
pub extern "C" fn zexe_tweedle_fp_verifier_index_read<'a>(
    srs: *const SRS<GAffine>,
    path: *const c_char,
) -> *const DlogVerifierIndex<'a, GAffine> {
    let srs = unsafe { &*srs };

    let path = (unsafe { CStr::from_ptr(path) })
        .to_string_lossy()
        .into_owned();
    let mut r = BufReader::new(File::open(path).unwrap());

    let t: IoResult<_> = (|| {
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
            fr_sponge_params: oracle::tweedle::fp::params(),
            fq_sponge_params: oracle::tweedle::fq::params(),
        })
    })();
    Box::into_raw(Box::new(t.unwrap()))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_a_row_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[0].row }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_a_col_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[0].col }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_a_val_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[0].val }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_a_rc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[0].rc }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_b_row_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[1].row }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_b_col_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[1].col }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_b_val_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[1].val }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_b_rc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[1].rc }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_c_row_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[2].row }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_c_col_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[2].col }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_c_val_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[2].val }).clone(),
    ))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_verifier_index_c_rc_comm(
    index: *const DlogVerifierIndex<GAffine>,
) -> *const PolyComm<GAffine> {
    Box::into_raw(Box::new(
        (unsafe { &(*index).matrix_commitments[2].rc }).clone(),
    ))
}

// Fp stubs

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_endo_base() -> *const Fq {
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffine>();
    return Box::into_raw(Box::new(endo_q));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_endo_scalar() -> *const Fp {
    let (_endo_q, endo_r) = commitment_dlog::srs::endos::<GAffine>();
    return Box::into_raw(Box::new(endo_r));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_size_in_bits() -> i32 {
    return Fp_params::MODULUS_BITS as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_size() -> *mut BigInteger {
    let ret = Fp_params::MODULUS;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_is_square(x: *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let s0 = x_.pow(Fp_params::MODULUS_MINUS_ONE_DIV_TWO);
    s0.is_zero() || s0.is_one()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_sqrt(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = match x_.sqrt() {
        Some(x) => x,
        None => Fp::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_random() -> *mut Fp {
    let ret: Fp = UniformRand::rand(&mut rand::thread_rng());
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_of_int(i: u64) -> *mut Fp {
    let ret = Fp::from(i);
    return Box::into_raw(Box::new(ret));
}

// TODO: Leaky
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_to_string(x: *const Fp) -> *const u8 {
    let x = unsafe { *x };
    let s: String = format!("{}", x);
    s.as_ptr()
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_inv(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = match x_.inverse() {
        Some(x) => x,
        None => Fp::zero(),
    };
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_square(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = x_.square();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_add(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_negate(x: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_mul(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ * y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_div(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ / y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_sub(x: *const Fp, y: *const Fp) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_mut_add(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ += y_;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_mut_mul(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ *= y_;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_mut_square(x: *mut Fp) {
    let x_ = unsafe { &mut (*x) };
    x_.square_in_place();
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_mut_sub(x: *mut Fp, y: *const Fp) {
    let x_ = unsafe { &mut (*x) };
    let y_ = unsafe { &(*y) };
    *x_ -= y_;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_copy(x: *mut Fp, y: *const Fp) {
    unsafe { (*x) = *y };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_rng(i: i32) -> *mut Fp {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    let ret: Fp = UniformRand::rand(&mut rng);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_delete(x: *mut Fp) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_print(x: *const Fp) {
    let x_ = unsafe { &(*x) };
    println!("{}", x_);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_equal(x: *const Fp, y: *const Fp) -> bool {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    return *x_ == *y_;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_to_bigint(x: *const Fp) -> *mut BigInteger {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.into_repr()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_of_bigint(x: *const BigInteger) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fp::from_repr(*x_)));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_to_bigint_raw(x: *const Fp) -> *mut BigInteger {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(x_.0));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_to_bigint_raw_noalloc(x: *const Fp) -> *const BigInteger {
    let x_ = unsafe { &(*x) };
    &x_.0 as *const BigInteger
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_of_bigint_raw(x: *const BigInteger) -> *mut Fp {
    let x_ = unsafe { &(*x) };
    return Box::into_raw(Box::new(Fp::new(*x_)));
}

// Fp vector stubs

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_create() -> *mut Vec<Fp> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_length(v: *const Vec<Fp>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_emplace_back(v: *mut Vec<Fp>, x: *const Fp) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_get(v: *mut Vec<Fp>, i: u32) -> *mut Fp {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_delete(v: *mut Vec<Fp>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp constraint-matrix stubs

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_constraint_matrix_create() -> *mut Vec<(Vec<usize>, Vec<Fp>)> {
    return Box::into_raw(Box::new(vec![]));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_constraint_matrix_append_row(
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
pub extern "C" fn zexe_tweedle_fp_constraint_matrix_delete(x: *mut Vec<(Vec<usize>, Vec<Fp>)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(x) };
}

// Fp triple
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_triple_0(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_triple_1(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_triple_2(evals: *const [Fp; 3]) -> *const Fp {
    let x = (unsafe { *evals })[2].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_triple_delete(x: *mut [Vec<Fp>; 3]) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_triple_0(evals: *const [Vec<Fp>; 3]) -> *const Vec<Fp> {
    let x = (unsafe { &(*evals) })[0].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_triple_1(evals: *const [Vec<Fp>; 3]) -> *const Vec<Fp> {
    let x = (unsafe { &(*evals) })[1].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_triple_2(evals: *const [Vec<Fp>; 3]) -> *const Vec<Fp> {
    let x = (unsafe { &(*evals) })[2].clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_vector_triple_delete(x: *mut [Vec<Fp>; 3]) {
    let _box = unsafe { Box::from_raw(x) };
}

// G / Fp stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_random() -> *const GProjective {
    let rng = &mut rand_core::OsRng;
    Box::into_raw(Box::new(GProjective::rand(rng)))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_delete(x: *mut GProjective) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_one() -> *const GProjective {
    let ret = GProjective::prime_subgroup_generator();
    Box::into_raw(Box::new(ret))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_add(
    x: *const GProjective,
    y: *const GProjective,
) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ + y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_double(x: *const GProjective) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let ret = x_.double();
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_scale(
    x: *const GProjective,
    s: *const Fp,
) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let s_ = unsafe { &(*s) };
    let ret = (*x_).mul(*s_);
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_sub(
    x: *const GProjective,
    y: *const GProjective,
) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let y_ = unsafe { &(*y) };
    let ret = *x_ - y_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_negate(x: *const GProjective) -> *const GProjective {
    let x_ = unsafe { &(*x) };
    let ret = -*x_;
    return Box::into_raw(Box::new(ret));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_to_affine(p: *const GProjective) -> *const GAffine {
    let p = unsafe { *p };
    let q = p.clone().into_affine();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_of_affine(p: *const GAffine) -> *const GProjective {
    let p = unsafe { *p };
    let q = p.clone().into_projective();
    return Box::into_raw(Box::new(q));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_of_affine_coordinates(
    x: *const Fq,
    y: *const Fq,
) -> *const GProjective {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    return Box::into_raw(Box::new(GProjective::new(x, y, Fq::one())));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_create(x: *const Fq, y: *const Fq) -> *const GAffine {
    let x = (unsafe { *x }).clone();
    let y = (unsafe { *y }).clone();
    Box::into_raw(Box::new(GAffine::new(x, y, false)))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_x(p: *const GAffine) -> *const Fq {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.x.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_y(p: *const GAffine) -> *const Fq {
    let p = unsafe { *p };
    return Box::into_raw(Box::new(p.y.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_is_zero(p: *const GAffine) -> bool {
    let p = unsafe { &*p };
    return p.is_zero();
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_delete(x: *mut GAffine) {
    let _box = unsafe { Box::from_raw(x) };
}

// G affine pair
#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_0(p: *const (GAffine, GAffine)) -> *const GAffine {
    let (x0, _) = unsafe { *p };
    return Box::into_raw(Box::new(x0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_1(p: *const (GAffine, GAffine)) -> *const GAffine {
    let (_, x1) = unsafe { *p };
    return Box::into_raw(Box::new(x1.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_make(
    x0: *const GAffine,
    x1: *const GAffine,
) -> *const (GAffine, GAffine) {
    let res = ((unsafe { *x0 }), (unsafe { *x1 }));
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_delete(x: *mut (GAffine, GAffine)) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_vector_create() -> *mut Vec<(GAffine, GAffine)> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_vector_length(
    v: *const Vec<(GAffine, GAffine)>,
) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_vector_emplace_back(
    v: *mut Vec<(GAffine, GAffine)>,
    x: *const (GAffine, GAffine),
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_vector_get(
    v: *mut Vec<(GAffine, GAffine)>,
    i: u32,
) -> *mut (GAffine, GAffine) {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_pair_vector_delete(v: *mut Vec<(GAffine, GAffine)>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// G vector stubs
#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_vector_create() -> *mut Vec<GAffine> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_vector_length(v: *const Vec<GAffine>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_vector_emplace_back(
    v: *mut Vec<GAffine>,
    x: *const GAffine,
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(*x_);
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_vector_get(v: *mut Vec<GAffine>, i: u32) -> *mut GAffine {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize]));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_dee_affine_vector_delete(v: *mut Vec<GAffine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp oracles
pub struct FpOracles {
    o: marlin_protocol_dlog::prover::RandomOracles<Fp>,
    opening_prechallenges: Vec<ScalarChallenge<Fp>>,
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_create(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> *const FpOracles {
    let index = unsafe { &(*index) };
    let proof = unsafe { &(*proof) };

    let x_hat = evals_from_coeffs(proof.public.clone(), index.domains.x).interpolate();
    // TODO: Should have no degree bound when we add the correct degree bound method
    let x_hat_comm = index.srs.get_ref().commit(&x_hat, None);

    let (mut sponge, o) = proof
        .oracles::<DefaultFqSponge<TweedledeeParameters, MarlinSpongeConstants>, DefaultFrSponge<Fp, MarlinSpongeConstants>>(
            index, x_hat_comm, &x_hat,
        );
    let opening_prechallenges = proof.proof.prechallenges(&mut sponge);

    return Box::into_raw(Box::new(FpOracles {
        o,
        opening_prechallenges,
    }));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_opening_prechallenges(
    oracles: *const FpOracles,
) -> *const Vec<Fp> {
    return Box::into_raw(Box::new(
        (unsafe { &(*oracles) })
            .opening_prechallenges
            .iter()
            .map(|x| x.0)
            .collect(),
    ));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_alpha(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.alpha.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_eta_a(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.eta_a.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_eta_b(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.eta_b.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_eta_c(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.eta_c.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_beta1(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.beta[0].0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_beta2(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.beta[1].0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_beta3(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.beta[2].0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_polys(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.polys.0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_evals(oracles: *const FpOracles) -> *const Fp {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.evals.0.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_x_hat_nocopy(
    oracles: *const FpOracles,
) -> *const [Vec<Fp>; 3] {
    return Box::into_raw(Box::new((unsafe { &(*oracles) }).o.x_hat.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_digest_before_evaluations(
    oracles: *const FpOracles,
) -> *const Fp {
    return Box::into_raw(Box::new(
        (unsafe { &(*oracles) }).o.digest_before_evaluations.clone(),
    ));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_oracles_delete(x: *mut FpOracles) {
    let _box = unsafe { Box::from_raw(x) };
}

// Fp proof
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_create(
    index: *const DlogIndex<GAffine>,
    primary_input: *const Vec<Fp>,
    auxiliary_input: *const Vec<Fp>,
    prev_challenges: *const Vec<Fp>,
    prev_sgs: *const Vec<GAffine>,
) -> *const DlogProof<GAffine> {
    let index = unsafe { &(*index) };
    let primary_input = unsafe { &(*primary_input) };
    let auxiliary_input = unsafe { &(*auxiliary_input) };

    let witness = prepare_witness(index.domains, primary_input, auxiliary_input);

    let prev: Vec<(Vec<Fp>, PolyComm<GAffine>)> = {
        let prev_challenges = unsafe { &*prev_challenges };
        let prev_sgs = unsafe { &*prev_sgs };
        if prev_challenges.len() == 0 {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs
                .iter()
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(|x| *x)
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg.clone()],
                            shifted: None,
                        },
                    )
                })
                .collect()
        }
    };

    let rng = &mut rand_core::OsRng;

    let map = <GAffine as CommitmentCurve>::Map::setup();
    let proof = DlogProof::create::<
        DefaultFqSponge<TweedledeeParameters, MarlinSpongeConstants>,
        DefaultFrSponge<Fp, MarlinSpongeConstants>,
    >(&map, &witness, &index, prev, rng)
    .unwrap();

    return Box::into_raw(Box::new(proof));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proof: *const DlogProof<GAffine>,
) -> bool {
    let index = unsafe { &(*index) };
    let proof = unsafe { (*proof).clone() };
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<TweedledeeParameters, MarlinSpongeConstants>,
        DefaultFrSponge<Fp, MarlinSpongeConstants>,
    >(&group_map, &[proof].to_vec(), &index, &mut rand_core::OsRng)
}

// TODO: Batch verify across different indexes
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_batch_verify(
    index: *const DlogVerifierIndex<GAffine>,
    proofs: *const Vec<DlogProof<GAffine>>,
) -> bool {
    let index = unsafe { &(*index) };
    let proofs = unsafe { &(*proofs) };
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledeeParameters, MarlinSpongeConstants>,
        DefaultFrSponge<Fp, MarlinSpongeConstants>,
    >(&group_map, proofs, index, &mut rand_core::OsRng)
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_make(
    primary_input: *const Vec<Fp>,

    w_comm: *const PolyComm<GAffine>,
    za_comm: *const PolyComm<GAffine>,
    zb_comm: *const PolyComm<GAffine>,
    h1_comm: *const PolyComm<GAffine>,
    g1_comm: *const PolyComm<GAffine>,
    h2_comm: *const PolyComm<GAffine>,
    g2_comm: *const PolyComm<GAffine>,
    h3_comm: *const PolyComm<GAffine>,
    g3_comm: *const PolyComm<GAffine>,

    sigma2: *const Fp,
    sigma3: *const Fp,

    lr: *const Vec<(GAffine, GAffine)>,
    z1: *const Fp,
    z2: *const Fp,
    delta: *const GAffine,
    sg: *const GAffine,

    evals0: *const DlogProofEvaluations<Fp>,
    evals1: *const DlogProofEvaluations<Fp>,
    evals2: *const DlogProofEvaluations<Fp>,

    prev_challenges: *const Vec<Fp>,
    prev_sgs: *const Vec<GAffine>,
) -> *const DlogProof<GAffine> {
    let public = unsafe { &(*primary_input) }.clone();
    // public.resize(ceil_pow2(public.len()), Fp::zero());

    let prev: Vec<(Vec<Fp>, PolyComm<GAffine>)> = {
        let prev_challenges = unsafe { &*prev_challenges };
        let prev_sgs = unsafe { &*prev_sgs };
        if prev_challenges.len() == 0 {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs
                .iter()
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(|x| *x)
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg.clone()],
                            shifted: None,
                        },
                    )
                })
                .collect()
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
        za_comm: (unsafe { &*za_comm }).clone(),
        zb_comm: (unsafe { &*zb_comm }).clone(),
        h1_comm: (unsafe { &*h1_comm }).clone(),
        g1_comm: (unsafe { &*g1_comm }).clone(),
        h2_comm: (unsafe { &*h2_comm }).clone(),
        g2_comm: (unsafe { &*g2_comm }).clone(),
        h3_comm: (unsafe { &*h3_comm }).clone(),
        g3_comm: (unsafe { &*g3_comm }).clone(),

        sigma2: (unsafe { *sigma2 }).clone(),
        sigma3: (unsafe { *sigma3 }).clone(),

        public,
        evals: [
            (unsafe { &*evals0 }).clone(),
            (unsafe { &*evals1 }).clone(),
            (unsafe { &*evals2 }).clone(),
        ],
    };
    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_delete(x: *mut DlogProof<GAffine>) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_w_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).w_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_za_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).za_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_zb_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).zb_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_h1_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).h1_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_g1_comm_nocopy(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).g1_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_h2_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &((*p).h2_comm) }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_g2_comm_nocopy(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).g2_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_h3_comm(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).h3_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_g3_comm_nocopy(
    p: *mut DlogProof<GAffine>,
) -> *const PolyComm<GAffine> {
    let x = (unsafe { &(*p).g3_comm }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_sigma2(p: *mut DlogProof<GAffine>) -> *const Fp {
    let x = (unsafe { (*p).sigma2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_sigma3(p: *mut DlogProof<GAffine>) -> *const Fp {
    let x = (unsafe { (*p).sigma3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_proof(
    p: *mut DlogProof<GAffine>,
) -> *const OpeningProof<GAffine> {
    let x = (unsafe { &(*p).proof }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evals_nocopy(
    p: *mut DlogProof<GAffine>,
) -> *const [DlogProofEvaluations<Fp>; 3] {
    let x = (unsafe { &(*p).evals }).clone();
    return Box::into_raw(Box::new(x));
}

// Fp proof vector

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_vector_create() -> *mut Vec<DlogProof<GAffine>> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_vector_length(v: *const Vec<DlogProof<GAffine>>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_vector_emplace_back(
    v: *mut Vec<DlogProof<GAffine>>,
    x: *const DlogProof<GAffine>,
) {
    let v_ = unsafe { &mut (*v) };
    let x_ = unsafe { &(*x) };
    v_.push(x_.clone());
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_vector_get(
    v: *mut Vec<DlogProof<GAffine>>,
    i: u32,
) -> *mut DlogProof<GAffine> {
    let v_ = unsafe { &mut (*v) };
    return Box::into_raw(Box::new((*v_)[i as usize].clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_vector_delete(v: *mut Vec<DlogProof<GAffine>>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}

// Fp opening proof
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_opening_proof_delete(p: *mut OpeningProof<GAffine>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(p) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_opening_proof_sg(
    p: *const OpeningProof<GAffine>,
) -> *const GAffine {
    let x = (unsafe { &(*p).sg }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_opening_proof_lr(
    p: *const OpeningProof<GAffine>,
) -> *const Vec<(GAffine, GAffine)> {
    let x = (unsafe { &(*p).lr }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_opening_proof_z1(p: *const OpeningProof<GAffine>) -> *const Fp {
    let x = (unsafe { &(*p).z1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_opening_proof_z2(p: *const OpeningProof<GAffine>) -> *const Fp {
    let x = (unsafe { &(*p).z2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_opening_proof_delta(
    p: *const OpeningProof<GAffine>,
) -> *const GAffine {
    let x = (unsafe { &(*p).delta }).clone();
    return Box::into_raw(Box::new(x));
}

// Fp proof evaluations

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_w(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).w }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_za(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).za }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_zb(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).zb }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_h1(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).h1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_h2(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).h2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_h3(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).h3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_g1(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).g1 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_g2(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).g2 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_g3(
    e: *const DlogProofEvaluations<Fp>,
) -> *const Vec<Fp> {
    let x = (unsafe { &(*e).g3 }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_row_nocopy(
    e: *const DlogProofEvaluations<Fp>,
) -> *const [Vec<Fp>; 3] {
    let x = (unsafe { &(*e).row }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_val_nocopy(
    e: *const DlogProofEvaluations<Fp>,
) -> *const [Vec<Fp>; 3] {
    let x = (unsafe { &(*e).val }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_col_nocopy(
    e: *const DlogProofEvaluations<Fp>,
) -> *const [Vec<Fp>; 3] {
    let x = (unsafe { &(*e).col }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_rc_nocopy(
    e: *const DlogProofEvaluations<Fp>,
) -> *const [Vec<Fp>; 3] {
    let x = (unsafe { &(*e).rc }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_triple_0(
    e: *const [DlogProofEvaluations<Fp>; 3],
) -> *const DlogProofEvaluations<Fp> {
    let x = (unsafe { &(*e)[0] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_triple_1(
    e: *const [DlogProofEvaluations<Fp>; 3],
) -> *const DlogProofEvaluations<Fp> {
    let x = (unsafe { &(*e)[1] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_triple_2(
    e: *const [DlogProofEvaluations<Fp>; 3],
) -> *const DlogProofEvaluations<Fp> {
    let x = (unsafe { &(*e)[2] }).clone();
    return Box::into_raw(Box::new(x));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_triple_delete(
    x: *mut [DlogProofEvaluations<Fp>; 3],
) {
    let _box = unsafe { Box::from_raw(x) };
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_make(
    w: *const Vec<Fp>,
    za: *const Vec<Fp>,
    zb: *const Vec<Fp>,
    h1: *const Vec<Fp>,
    g1: *const Vec<Fp>,
    h2: *const Vec<Fp>,
    g2: *const Vec<Fp>,
    h3: *const Vec<Fp>,
    g3: *const Vec<Fp>,

    row_0: *const Vec<Fp>,
    row_1: *const Vec<Fp>,
    row_2: *const Vec<Fp>,

    col_0: *const Vec<Fp>,
    col_1: *const Vec<Fp>,
    col_2: *const Vec<Fp>,

    val_0: *const Vec<Fp>,
    val_1: *const Vec<Fp>,
    val_2: *const Vec<Fp>,

    rc_0: *const Vec<Fp>,
    rc_1: *const Vec<Fp>,
    rc_2: *const Vec<Fp>,
) -> *const DlogProofEvaluations<Fp> {
    let res: DlogProofEvaluations<Fp> = DlogProofEvaluations {
        w: (unsafe { &*w }).clone(),
        za: (unsafe { &*za }).clone(),
        zb: (unsafe { &*zb }).clone(),
        g1: (unsafe { &*g1 }).clone(),
        g2: (unsafe { &*g2 }).clone(),
        g3: (unsafe { &*g3 }).clone(),
        h1: (unsafe { &*h1 }).clone(),
        h2: (unsafe { &*h2 }).clone(),
        h3: (unsafe { &*h3 }).clone(),
        row: [
            (unsafe { &*row_0 }).clone(),
            (unsafe { &*row_1 }).clone(),
            (unsafe { &*row_2 }).clone(),
        ],
        col: [
            (unsafe { &*col_0 }).clone(),
            (unsafe { &*col_1 }).clone(),
            (unsafe { &*col_2 }).clone(),
        ],
        val: [
            (unsafe { &*val_0 }).clone(),
            (unsafe { &*val_1 }).clone(),
            (unsafe { &*val_2 }).clone(),
        ],
        rc: [
            (unsafe { &*rc_0 }).clone(),
            (unsafe { &*rc_1 }).clone(),
            (unsafe { &*rc_2 }).clone(),
        ],
    };

    return Box::into_raw(Box::new(res));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_proof_evaluations_delete(x: *mut DlogProofEvaluations<Fp>) {
    let _box = unsafe { Box::from_raw(x) };
}

// fq poly comm
#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_poly_comm_unshifted(
    c: *const PolyComm<GAffine>,
) -> *const Vec<GAffine> {
    let c = unsafe { &(*c) };
    return Box::into_raw(Box::new(c.unshifted.clone()));
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_poly_comm_shifted(c: *const PolyComm<GAffine>) -> *const GAffine {
    let c = unsafe { &(*c) };
    match c.shifted {
        Some(g) => Box::into_raw(Box::new(g.clone())),
        None => std::ptr::null(),
    }
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_poly_comm_make(
    unshifted: *const Vec<GAffine>,
    shifted: *const GAffine,
) -> *const PolyComm<GAffine> {
    let unsh = unsafe { &(*unshifted) };

    let commitment = PolyComm {
        unshifted: unsh.clone(),
        shifted: if shifted == std::ptr::null() {
            None
        } else {
            Some({
                let sh = unsafe { &(*shifted) };
                *sh
            })
        },
    };

    Box::into_raw(Box::new(commitment))
}

#[no_mangle]
pub extern "C" fn zexe_tweedle_fp_poly_comm_delete(c: *mut PolyComm<GAffine>) {
    let _box = unsafe { Box::from_raw(c) };
}
