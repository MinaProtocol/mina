use crate::{
    arkworks::{CamlFq, CamlGPallas},
    pasta_fq_plonk_index::CamlPastaFqPlonkIndexPtr,
    plonk_verifier_index::{CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex},
    srs::fq::CamlFqSrs,
};
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use commitment_dlog::commitment::caml::CamlPolyComm;
use commitment_dlog::{commitment::PolyComm, srs::SRS};
use kimchi::circuits::polynomials::permutation::Shifts;
use kimchi::circuits::polynomials::permutation::{zk_polynomial, zk_w3};
use kimchi::circuits::wires::{COLUMNS, PERMUTS};
use kimchi::{linearization::expr_linearization, verifier_index::VerifierIndex};
use mina_curves::pasta::{Fq, Pallas, Vesta};
use std::convert::TryInto;
use std::path::Path;

pub type CamlPastaFqPlonkVerifierIndex =
    CamlPlonkVerifierIndex<CamlFq, CamlFqSrs, CamlPolyComm<CamlGPallas>>;

impl From<VerifierIndex<Pallas>> for CamlPastaFqPlonkVerifierIndex {
    fn from(vi: VerifierIndex<Pallas>) -> Self {
        Self {
            domain: CamlPlonkDomain {
                log_size_of_group: vi.domain.log_size_of_group as isize,
                group_gen: CamlFq(vi.domain.group_gen),
            },
            max_poly_size: vi.max_poly_size as isize,
            max_quot_size: vi.max_quot_size as isize,
            public: vi.public as isize,
            prev_challenges: vi.prev_challenges as isize,
            srs: CamlFqSrs(vi.srs.get().expect("have an srs").clone()),
            evals: CamlPlonkVerificationEvals {
                sigma_comm: vi.sigma_comm.to_vec().iter().map(Into::into).collect(),
                coefficients_comm: vi
                    .coefficients_comm
                    .to_vec()
                    .iter()
                    .map(Into::into)
                    .collect(),
                generic_comm: vi.generic_comm.into(),
                psm_comm: vi.psm_comm.into(),
                complete_add_comm: vi.complete_add_comm.into(),
                mul_comm: vi.mul_comm.into(),
                emul_comm: vi.emul_comm.into(),
                endomul_scalar_comm: vi.endomul_scalar_comm.into(),
                chacha_comm: vi
                    .chacha_comm
                    .map(|x| x.to_vec().iter().map(Into::into).collect()),
            },
            shifts: vi.shift.to_vec().iter().map(Into::into).collect(),
            lookup_index: vi.lookup_index.map(Into::into),
        }
    }
}

// TODO: This should really be a TryFrom or TryInto
impl From<CamlPastaFqPlonkVerifierIndex> for VerifierIndex<Pallas> {
    fn from(index: CamlPastaFqPlonkVerifierIndex) -> Self {
        let evals = index.evals;
        let shifts = index.shifts;

        let (endo_q, _endo_r) = commitment_dlog::srs::endos::<Vesta>();
        let domain = Domain::<Fq>::new(1 << index.domain.log_size_of_group).expect("wrong size");

        let coefficients_comm: Vec<PolyComm<Pallas>> =
            evals.coefficients_comm.iter().map(Into::into).collect();
        let coefficients_comm: [_; COLUMNS] = coefficients_comm.try_into().expect("wrong size");

        let sigma_comm: Vec<PolyComm<Pallas>> = evals.sigma_comm.iter().map(Into::into).collect();
        let sigma_comm: [_; PERMUTS] = sigma_comm
            .try_into()
            .expect("vector of sigma comm is of wrong size");

        let chacha_comm: Option<Vec<PolyComm<Pallas>>> = evals
            .chacha_comm
            .map(|x| x.iter().map(Into::into).collect());
        let chacha_comm: Option<[_; 4]> =
            chacha_comm.map(|x| x.try_into().expect("vector of sigma comm is of wrong size"));

        let shifts: Vec<Fq> = shifts.iter().map(Into::into).collect();
        let shift: [Fq; PERMUTS] = shifts.try_into().expect("wrong size");

        // TODO chacha, dummy_lookup_value ?
        let (linearization, powers_of_alpha) = expr_linearization(false, false, None);

        VerifierIndex::<Pallas> {
            domain,
            max_poly_size: index.max_poly_size as usize,
            max_quot_size: index.max_quot_size as usize,
            public: index.public as usize,
            prev_challenges: index.prev_challenges as usize,
            powers_of_alpha,
            srs: {
                let res = once_cell::sync::OnceCell::new();
                res.set(index.srs.0).unwrap();
                res
            },

            sigma_comm,
            coefficients_comm,
            generic_comm: evals.generic_comm.into(),

            psm_comm: evals.psm_comm.into(),

            complete_add_comm: evals.complete_add_comm.into(),
            mul_comm: evals.mul_comm.into(),
            emul_comm: evals.emul_comm.into(),
            endomul_scalar_comm: evals.endomul_scalar_comm.into(),

            chacha_comm,

            range_check_comm: None,

            shift,
            zkpm: {
                let res = once_cell::sync::OnceCell::new();
                res.set(zk_polynomial(domain)).unwrap();
                res
            },
            w: {
                let res = once_cell::sync::OnceCell::new();
                res.set(zk_w3(domain)).unwrap();
                res
            },
            endo: endo_q,

            lookup_index: index.lookup_index.map(Into::into),
            linearization,
        }
    }
}

pub fn read_raw(
    offset: Option<ocaml::Int>,
    srs: CamlFqSrs,
    path: String,
) -> Result<VerifierIndex<Pallas>, ocaml::Error> {
    let path = Path::new(&path);
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<Vesta>();
    VerifierIndex::<Pallas>::from_file(Some(srs.0), path, offset.map(|x| x as u64), endo_q).map_err(
        |_e| {
            ocaml::Error::invalid_argument("caml_pasta_fq_plonk_verifier_index_raw_read")
                .err()
                .unwrap()
        },
    )
}

//
// OCaml methods
//

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFqSrs,
    path: String,
) -> Result<CamlPastaFqPlonkVerifierIndex, ocaml::Error> {
    let vi = read_raw(offset, srs, path)?;
    Ok(vi.into())
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_write(
    append: Option<bool>,
    index: CamlPastaFqPlonkVerifierIndex,
    path: String,
) -> Result<(), ocaml::Error> {
    let index: VerifierIndex<Pallas> = index.into();
    let path = Path::new(&path);
    index.to_file(path, append).map_err(|_e| {
        ocaml::Error::invalid_argument("caml_pasta_fq_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_create(
    index: CamlPastaFqPlonkIndexPtr,
) -> CamlPastaFqPlonkVerifierIndex {
    {
        let ptr: &mut commitment_dlog::srs::SRS<Pallas> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&index.as_ref().0.srs) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }
    let verifier_index = index.as_ref().0.verifier_index();
    verifier_index.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_shifts(log2_size: ocaml::Int) -> Vec<CamlFq> {
    let domain = Domain::<Fq>::new(1 << log2_size).unwrap();
    let shifts = Shifts::new(&domain);
    shifts.shifts().iter().map(Into::into).collect()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_dummy() -> CamlPastaFqPlonkVerifierIndex {
    fn comm() -> CamlPolyComm<CamlGPallas> {
        let g: CamlGPallas = Pallas::prime_subgroup_generator().into();
        CamlPolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }
    fn vec_comm(num: usize) -> Vec<CamlPolyComm<CamlGPallas>> {
        (0..num).map(|_| comm()).collect()
    }

    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: 1,
            group_gen: Fq::one().into(),
        },
        max_poly_size: 0,
        max_quot_size: 0,
        public: 0,
        prev_challenges: 0,
        srs: CamlFqSrs::new(SRS::create(0)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm: vec_comm(PERMUTS),
            coefficients_comm: vec_comm(COLUMNS),
            generic_comm: comm(),
            psm_comm: comm(),
            complete_add_comm: comm(),
            mul_comm: comm(),
            endomul_scalar_comm: comm(),
            emul_comm: comm(),
            chacha_comm: None,
        },
        shifts: (0..PERMUTS - 1).map(|_| Fq::one().into()).collect(),
        lookup_index: None,
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_deep_copy(
    x: CamlPastaFqPlonkVerifierIndex,
) -> CamlPastaFqPlonkVerifierIndex {
    x
}
