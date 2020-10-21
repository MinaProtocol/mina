use algebra::{
    curves::AffineCurve,
    fields::{FftField, Field, PrimeField},
    FromBytes, One, ToBytes, UniformRand, VariableBaseMSM, Zero,
};

use commitment_dlog::{
    commitment::{b_poly_coefficients, CommitmentCurve, PolyComm},
    srs::SRS,
};
use ff_fft::{
    DensePolynomial, EvaluationDomain, Evaluations, GeneralEvaluationDomain,
    Radix2EvaluationDomain as Domain,
};
use marlin_circuits::domains::EvaluationDomains;
use marlin_protocol_pairing::index::MatrixValues;
use rayon::prelude::*;
use sprs::{CsMat, CsVecView, CSR};
use std::io::{Read, Result as IoResult, Write};

#[repr(C)]
pub struct DetSqrtWitness<F> {
    pub c: *mut F,
    pub d: u64,
    pub square_root: *mut F,
    pub success: bool
}

pub fn batch_dlog_accumulator_check<G: CommitmentCurve>(
    urs: &SRS<G>,
    comms: &Vec<G>,
    chals: &Vec<G::ScalarField>,
) -> bool {
    let k = comms.len();

    if k == 0 {
        assert_eq!(chals.len(), 0);
        return true;
    }

    let rounds = chals.len() / k;
    assert_eq!(chals.len() % rounds, 0);

    let rs = {
        let r = G::ScalarField::rand(&mut rand_core::OsRng);
        let mut rs = vec![G::ScalarField::one(); k];
        for i in 1..k {
            rs[i] = r * &rs[i - 1];
        }
        rs
    };

    let mut points = urs.g.clone();
    let n = points.len();
    points.extend(comms);

    let mut scalars = vec![G::ScalarField::zero(); n];
    scalars.extend(&rs[..]);

    let chal_invs = {
        let mut cs = chals.clone();
        algebra::fields::batch_inversion(&mut cs);
        cs
    };

    let termss: Vec<_> = chals
        .par_iter()
        .zip(chal_invs)
        .chunks(rounds)
        .zip(rs)
        .map(|(chunk, r)| {
            let s0 = chunk
                .iter()
                .fold(G::ScalarField::one(), |x, (_, c_inv)| x * c_inv);
            let c_squareds: Vec<_> = chunk.iter().map(|(c, _)| c.square()).collect();
            let mut s = b_poly_coefficients(s0, &c_squareds);
            s.iter_mut().for_each(|c| *c *= &r);
            s
        })
        .collect();

    for terms in termss {
        assert_eq!(terms.len(), n);
        for i in 0..n {
            scalars[i] -= &terms[i];
        }
    }

    let scalars: Vec<_> = scalars.iter().map(|x| x.into_repr()).collect();
    VariableBaseMSM::multi_scalar_mul(&points, &scalars) == G::Projective::zero()
}

pub fn evals_from_coeffs<F: FftField>(
    v: Vec<F>,
    d: Domain<F>,
) -> Evaluations<F, GeneralEvaluationDomain<F>> {
    Evaluations::<F>::from_vec_and_domain(v, GeneralEvaluationDomain::Radix2(d))
}

pub fn ceil_pow2(x: usize) -> usize {
    let mut res = 1;
    while x > res {
        res *= 2;
    }
    res
}

pub fn write_vec<A: ToBytes, W: Write>(v: &Vec<A>, mut writer: W) -> IoResult<()> {
    u64::write(&(v.len() as u64), &mut writer)?;
    for x in v {
        x.write(&mut writer)?;
    }
    Ok(())
}

pub fn read_vec<A: FromBytes, R: Read>(mut reader: R) -> IoResult<Vec<A>> {
    let mut v = vec![];
    let n = u64::read(&mut reader)? as usize;
    for _ in 0..n {
        v.push(A::read(&mut reader)?);
    }
    Ok(v)
}

pub fn write_cs_mat<A: ToBytes + Clone, W: Write>(m: &CsMat<A>, mut w: W) -> IoResult<()> {
    fn v(s: &[usize]) -> Vec<u64> {
        s.iter().map(|x| *x as u64).collect()
    }

    let (a, b) = m.shape();
    u64::write(&(a as u64), &mut w)?;
    u64::write(&(b as u64), &mut w)?;

    write_vec::<u64, _>(&v(m.indptr()), &mut w)?;
    write_vec(&v(m.indices()), &mut w)?;
    write_vec(&m.data().to_vec(), &mut w)?;
    Ok(())
}

pub fn read_cs_mat<A: FromBytes + Copy, R: Read>(mut r: R) -> IoResult<CsMat<A>> {
    fn v(s: Vec<u64>) -> Vec<usize> {
        s.iter().map(|x| *x as usize).collect()
    }

    let a = u64::read(&mut r)? as usize;
    let b = u64::read(&mut r)? as usize;
    let shape = (a, b);

    let indptr = v(read_vec(&mut r)?);
    let indices = v(read_vec(&mut r)?);
    let data: Vec<A> = read_vec(&mut r)?;
    Ok(CsMat::new(shape, indptr, indices, data))
}

pub fn write_matrix_values<A: ToBytes, W: Write>(m: &MatrixValues<A>, mut w: W) -> IoResult<()> {
    A::write(&m.row, &mut w)?;
    A::write(&m.col, &mut w)?;
    A::write(&m.val, &mut w)?;
    A::write(&m.rc, &mut w)?;
    Ok(())
}

pub fn read_matrix_values<A: FromBytes, R: Read>(mut r: R) -> IoResult<MatrixValues<A>> {
    let row = A::read(&mut r)?;
    let col = A::read(&mut r)?;
    let val = A::read(&mut r)?;
    let rc = A::read(&mut r)?;
    Ok(MatrixValues { row, col, val, rc })
}

pub fn write_option<A: ToBytes, W: Write>(a: &Option<A>, mut w: W) -> IoResult<()> {
    match a {
        None => u8::write(&0, &mut w),
        Some(a) => {
            u8::write(&1, &mut w)?;
            A::write(a, &mut w)
        }
    }
}

pub fn read_option<A: FromBytes, R: Read>(mut r: R) -> IoResult<Option<A>> {
    match u8::read(&mut r)? {
        0 => Ok(None),
        1 => Ok(Some(A::read(&mut r)?)),
        _ => panic!("read_option: expected 0 or 1"),
    }
}

pub fn write_poly_comm<A: ToBytes + AffineCurve, W: Write>(
    p: &PolyComm<A>,
    mut w: W,
) -> IoResult<()> {
    write_vec(&p.unshifted, &mut w)?;
    write_option(&p.shifted, &mut w)
}

pub fn read_poly_comm<A: FromBytes + AffineCurve, R: Read>(mut r: R) -> IoResult<PolyComm<A>> {
    let unshifted = read_vec(&mut r)?;
    let shifted = read_option(&mut r)?;
    Ok(PolyComm { unshifted, shifted })
}

pub fn write_dlog_matrix_values<A: ToBytes + AffineCurve, W: Write>(
    m: &marlin_protocol_dlog::index::MatrixValues<A>,
    mut w: W,
) -> IoResult<()> {
    write_poly_comm(&m.row, &mut w)?;
    write_poly_comm(&m.col, &mut w)?;
    write_poly_comm(&m.val, &mut w)?;
    write_poly_comm(&m.rc, &mut w)?;
    Ok(())
}

pub fn read_dlog_matrix_values<A: FromBytes + AffineCurve, R: Read>(
    mut r: R,
) -> IoResult<marlin_protocol_dlog::index::MatrixValues<A>> {
    let row = read_poly_comm(&mut r)?;
    let col = read_poly_comm(&mut r)?;
    let val = read_poly_comm(&mut r)?;
    let rc = read_poly_comm(&mut r)?;
    Ok(marlin_protocol_dlog::index::MatrixValues { row, col, val, rc })
}

pub fn write_dense_polynomial<A: ToBytes + Field, W: Write>(
    p: &DensePolynomial<A>,
    w: W,
) -> IoResult<()> {
    write_vec(&p.coeffs, w)
}

pub fn read_dense_polynomial<A: ToBytes + Field, R: Read>(r: R) -> IoResult<DensePolynomial<A>> {
    let coeffs = read_vec(r)?;
    Ok(DensePolynomial { coeffs })
}

pub fn write_domain<A: ToBytes + PrimeField, W: Write>(d: &Domain<A>, mut w: W) -> IoResult<()> {
    d.size.write(&mut w)?;
    d.log_size_of_group.write(&mut w)?;
    d.size_as_field_element.write(&mut w)?;
    d.size_inv.write(&mut w)?;
    d.group_gen.write(&mut w)?;
    d.group_gen_inv.write(&mut w)?;
    d.generator_inv.write(&mut w)?;
    Ok(())
}

pub fn read_domain<A: ToBytes + PrimeField, R: Read>(mut r: R) -> IoResult<Domain<A>> {
    let size = u64::read(&mut r)?;
    let log_size_of_group = u32::read(&mut r)?;

    let size_as_field_element = A::read(&mut r)?;
    let size_inv = A::read(&mut r)?;
    let group_gen = A::read(&mut r)?;
    let group_gen_inv = A::read(&mut r)?;
    let generator_inv = A::read(&mut r)?;
    Ok(Domain {
        size,
        log_size_of_group,
        size_as_field_element,
        size_inv,
        group_gen,
        group_gen_inv,
        generator_inv,
    })
}

pub fn write_evaluations<A: ToBytes + PrimeField, W: Write>(
    e: &Evaluations<A>,
    mut w: W,
) -> IoResult<()> {
    write_vec(&e.evals, &mut w)?;
    Ok(())
}

pub fn read_evaluations<A: ToBytes + PrimeField, R: Read>(mut r: R) -> IoResult<Evaluations<A>> {
    let evals = read_vec(&mut r)?;
    let domain = Domain::new(evals.len()).unwrap();
    assert_eq!(evals.len(), domain.size());
    Ok(evals_from_coeffs(evals, domain))
}

pub fn write_evaluation_domains<A: PrimeField, W: Write>(
    d: &EvaluationDomains<A>,
    mut w: W,
) -> IoResult<()> {
    u64::write(&(d.h.size() as u64), &mut w)?;
    u64::write(&(d.k.size() as u64), &mut w)?;
    u64::write(&(d.b.size() as u64), &mut w)?;
    u64::write(&(d.x.size() as u64), &mut w)?;
    Ok(())
}

pub fn read_evaluation_domains<A: PrimeField, R: Read>(mut r: R) -> IoResult<EvaluationDomains<A>> {
    let h = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    let k = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    let b = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    let x = EvaluationDomain::new(u64::read(&mut r)? as usize).unwrap();
    Ok(EvaluationDomains { h, k, b, x })
}

pub fn witness_position_to_index(public_inputs: usize, h_to_x_ratio: usize, w: usize) -> usize {
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

pub fn index_to_witness_position(public_inputs: usize, h_to_x_ratio: usize, i: usize) -> usize {
    let res = if i < public_inputs {
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
    assert_eq!(
        witness_position_to_index(public_inputs, h_to_x_ratio, res),
        i
    );
    res
}

pub fn rows_to_csmat<F: Clone + Copy + std::fmt::Debug>(
    public_inputs: usize,
    h_group_size: usize,
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

        let shifted_indices: Vec<usize> = shifted.iter().map(|(i, _)| *i).collect();
        let shifted_coefficients: Vec<F> = shifted.iter().map(|(_, x)| *x).collect();

        match CsVecView::<F>::new_view(h_group_size, &shifted_indices, &shifted_coefficients) {
            Ok(r) => m = m.append_outer_csvec(r),
            Err(e) => panic!(
                "new_view failed {} ({:?}, {:?})",
                e, shifted_indices, shifted_coefficients
            ),
        };
    }

    for _ in 0..(h_group_size - v.len()) {
        match CsVecView::<F>::new_view(h_group_size, &vec![], &vec![]) {
            Ok(v) => m = m.append_outer_csvec(v),
            Err(e) => panic!("new_view failed {}", e),
        };
    }

    m
}

pub fn prepare_witness<F: PrimeField>(
    domains: EvaluationDomains<F>,
    primary_input: &Vec<F>,
    auxiliary_input: &Vec<F>,
) -> Vec<F> {
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

pub fn prepare_plonk_witness<F: PrimeField>(
    primary_input: &Vec<F>,
    auxiliary_input: &Vec<F>,
) -> Vec<F> {
    // TODO: Check that this is correct.
    let mut witness: Vec<F> = Vec::with_capacity(primary_input.len() + auxiliary_input.len() + 1);

    witness.push(F::one());
    witness.extend_from_slice(primary_input.as_slice());
    witness.extend_from_slice(auxiliary_input.as_slice());

    witness
}

// NOTE: We always 'box' these values as pointers, since the FFI doesn't know
// the size of the target type, and annotating them with (void *) on the other
// side of the FFI would cause only the first 64 bits to be copied.

// usize vector stubs
#[no_mangle]
pub extern "C" fn zexe_usize_vector_create() -> *mut Vec<usize> {
    return Box::into_raw(Box::new(Vec::new()));
}

#[no_mangle]
pub extern "C" fn zexe_usize_vector_length(v: *const Vec<usize>) -> i32 {
    let v_ = unsafe { &(*v) };
    return v_.len() as i32;
}

#[no_mangle]
pub extern "C" fn zexe_usize_vector_emplace_back(v: *mut Vec<usize>, x: usize) {
    let v_ = unsafe { &mut (*v) };
    v_.push(x);
}

#[no_mangle]
pub extern "C" fn zexe_usize_vector_get(v: *mut Vec<usize>, i: u32) -> usize {
    let v = unsafe { &mut (*v) };
    v[i as usize]
}

#[no_mangle]
pub extern "C" fn zexe_usize_vector_delete(v: *mut Vec<usize>) {
    // Deallocation happens automatically when a box variable goes out of
    // scope.
    let _box = unsafe { Box::from_raw(v) };
}
