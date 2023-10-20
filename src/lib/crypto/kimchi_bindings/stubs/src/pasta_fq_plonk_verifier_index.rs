use crate::{
    arkworks::{CamlFq, CamlGPallas},
    pasta_fq_plonk_index::CamlPastaFqPlonkIndexPtr,
    plonk_verifier_index::{CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex},
    srs::fq::CamlFqSrs,
};
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use kimchi::circuits::constraints::FeatureFlags;
use kimchi::circuits::lookup::lookups::{LookupFeatures, LookupPatterns};
use kimchi::circuits::polynomials::permutation::Shifts;
use kimchi::circuits::polynomials::permutation::{permutation_vanishing_polynomial, zk_w};
use kimchi::circuits::wires::{COLUMNS, PERMUTS};
use kimchi::{linearization::expr_linearization, verifier_index::VerifierIndex};
use mina_curves::pasta::{Fq, Pallas, Vesta};
use poly_commitment::{commitment::caml::CamlPolyComm, evaluation_proof::OpeningProof};
use poly_commitment::{commitment::PolyComm, srs::SRS};
use std::convert::TryInto;
use std::path::Path;
use std::sync::Arc;

pub type CamlPastaFqPlonkVerifierIndex =
    CamlPlonkVerifierIndex<CamlFq, CamlFqSrs, CamlPolyComm<CamlGPallas>>;

impl From<VerifierIndex<Pallas, OpeningProof<Pallas>>> for CamlPastaFqPlonkVerifierIndex {
    fn from(vi: VerifierIndex<Pallas, OpeningProof<Pallas>>) -> Self {
        Self {
            domain: CamlPlonkDomain {
                log_size_of_group: vi.domain.log_size_of_group as isize,
                group_gen: CamlFq(vi.domain.group_gen),
            },
            max_poly_size: vi.max_poly_size as isize,
            public: vi.public as isize,
            prev_challenges: vi.prev_challenges as isize,
            srs: CamlFqSrs(vi.srs.clone()),
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

                xor_comm: vi.xor_comm.map(Into::into),
                range_check0_comm: vi.range_check0_comm.map(Into::into),
                range_check1_comm: vi.range_check1_comm.map(Into::into),
                foreign_field_add_comm: vi.foreign_field_add_comm.map(Into::into),
                foreign_field_mul_comm: vi.foreign_field_mul_comm.map(Into::into),
                rot_comm: vi.rot_comm.map(Into::into),
            },
            shifts: vi.shift.to_vec().iter().map(Into::into).collect(),
            lookup_index: vi.lookup_index.map(Into::into),
            zk_rows: vi.zk_rows as isize,
            override_ffadd: vi.override_ffadd.map(|x| x.into_iter().map(|x| x.map(Into::into)).collect::<Vec<_>>()),
        }
    }
}

// TODO: This should really be a TryFrom or TryInto
impl From<CamlPastaFqPlonkVerifierIndex> for VerifierIndex<Pallas, OpeningProof<Pallas>> {
    fn from(index: CamlPastaFqPlonkVerifierIndex) -> Self {
        let evals = index.evals;
        let shifts = index.shifts;

        let (endo_q, _endo_r) = poly_commitment::srs::endos::<Vesta>();
        let domain = Domain::<Fq>::new(1 << index.domain.log_size_of_group).expect("wrong size");

        let coefficients_comm: Vec<PolyComm<Pallas>> =
            evals.coefficients_comm.iter().map(Into::into).collect();
        let coefficients_comm: [_; COLUMNS] = coefficients_comm.try_into().expect("wrong size");

        let sigma_comm: Vec<PolyComm<Pallas>> = evals.sigma_comm.iter().map(Into::into).collect();
        let sigma_comm: [_; PERMUTS] = sigma_comm
            .try_into()
            .expect("vector of sigma comm is of wrong size");

        let shifts: Vec<Fq> = shifts.iter().map(Into::into).collect();
        let shift: [Fq; PERMUTS] = shifts.try_into().expect("wrong size");

        let feature_flags = FeatureFlags {
            range_check0: evals.range_check0_comm.is_some(),
            range_check1: evals.range_check1_comm.is_some(),
            foreign_field_add: evals.foreign_field_add_comm.is_some(),
            foreign_field_mul: evals.foreign_field_mul_comm.is_some(),
            rot: evals.rot_comm.is_some(),
            xor: evals.xor_comm.is_some(),
            lookup_features: {
                if let Some(li) = index.lookup_index.as_ref() {
                    li.lookup_info.features
                } else {
                    LookupFeatures {
                        patterns: LookupPatterns {
                            xor: false,
                            lookup: false,
                            range_check: false,
                            foreign_field_mul: false,
                        },
                        joint_lookup_used: false,
                        uses_runtime_tables: false,
                    }
                }
            },
        };

        // TODO dummy_lookup_value ?
        let (linearization, powers_of_alpha) =
            expr_linearization(Some(&feature_flags), true, index.override_ffadd.is_some());

        VerifierIndex::<Pallas, OpeningProof<Pallas>> {
            domain,
            max_poly_size: index.max_poly_size as usize,
            public: index.public as usize,
            prev_challenges: index.prev_challenges as usize,
            powers_of_alpha,
            srs: { Arc::clone(&index.srs.0) },

            zk_rows: index.zk_rows as u64,
            override_ffadd: index.override_ffadd.map(|x| x.into_iter().map(|x| x.map(Into::into)).collect::<Vec<_>>()),

            sigma_comm,
            coefficients_comm,
            generic_comm: evals.generic_comm.into(),

            psm_comm: evals.psm_comm.into(),

            complete_add_comm: evals.complete_add_comm.into(),
            mul_comm: evals.mul_comm.into(),
            emul_comm: evals.emul_comm.into(),
            endomul_scalar_comm: evals.endomul_scalar_comm.into(),

            xor_comm: evals.xor_comm.map(Into::into),
            range_check0_comm: evals.range_check0_comm.map(Into::into),
            range_check1_comm: evals.range_check1_comm.map(Into::into),
            foreign_field_add_comm: evals.foreign_field_add_comm.map(Into::into),
            foreign_field_mul_comm: evals.foreign_field_mul_comm.map(Into::into),
            rot_comm: evals.rot_comm.map(Into::into),

            shift,
            permutation_vanishing_polynomial_m: {
                let res = once_cell::sync::OnceCell::new();
                res.set(permutation_vanishing_polynomial(
                    domain,
                    index.zk_rows as u64,
                ))
                .unwrap();
                res
            },
            w: {
                let res = once_cell::sync::OnceCell::new();
                res.set(zk_w(domain, index.zk_rows as u64)).unwrap();
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
) -> Result<VerifierIndex<Pallas, OpeningProof<Pallas>>, ocaml::Error> {
    let path = Path::new(&path);
    let (endo_q, _endo_r) = poly_commitment::srs::endos::<Vesta>();
    VerifierIndex::<Pallas, OpeningProof<Pallas>>::from_file(
        srs.0,
        path,
        offset.map(|x| x as u64),
        endo_q,
    )
    .map_err(|_e| {
        ocaml::Error::invalid_argument("caml_pasta_fq_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
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
    let index: VerifierIndex<Pallas, OpeningProof<Pallas>> = index.into();
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
        let ptr: &mut poly_commitment::srs::SRS<Pallas> =
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
            xor_comm: None,
            range_check0_comm: None,
            range_check1_comm: None,
            foreign_field_add_comm: None,
            foreign_field_mul_comm: None,
            rot_comm: None,
        },
        shifts: (0..PERMUTS - 1).map(|_| Fq::one().into()).collect(),
        lookup_index: None,
        zk_rows: 3,
        override_ffadd: None,
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_deep_copy(
    x: CamlPastaFqPlonkVerifierIndex,
) -> CamlPastaFqPlonkVerifierIndex {
    x
}
