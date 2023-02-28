use crate::arkworks::{CamlFp, CamlGVesta};
use crate::pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr;
use crate::plonk_verifier_index::{
    CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex,
};
use crate::srs::fp::CamlFpSrs;
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use kimchi::circuits::constraints::FeatureFlags;
use kimchi::circuits::lookup::lookups::{LookupFeatures, LookupPatterns};
use kimchi::circuits::polynomials::permutation::Shifts;
use kimchi::circuits::polynomials::permutation::{zk_polynomial, zk_w3};
use kimchi::circuits::wires::{COLUMNS, PERMUTS};
use kimchi::{linearization::expr_linearization, verifier_index::VerifierIndex};
use mina_curves::pasta::{Fp, Pallas, Vesta};
use poly_commitment::commitment::caml::CamlPolyComm;
use poly_commitment::{commitment::PolyComm, srs::SRS};
use std::convert::TryInto;
use std::path::Path;

pub type CamlPastaFpPlonkVerifierIndex =
    CamlPlonkVerifierIndex<CamlFp, CamlFpSrs, CamlPolyComm<CamlGVesta>>;

impl From<VerifierIndex<Vesta>> for CamlPastaFpPlonkVerifierIndex {
    fn from(vi: VerifierIndex<Vesta>) -> Self {
        Self {
            domain: CamlPlonkDomain {
                log_size_of_group: vi.domain.log_size_of_group as isize,
                group_gen: CamlFp(vi.domain.group_gen),
            },
            max_poly_size: vi.max_poly_size as isize,
            public: vi.public as isize,
            prev_challenges: vi.prev_challenges as isize,
            srs: CamlFpSrs(vi.srs.get().expect("have an srs").clone()),
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
            },
            shifts: vi.shift.to_vec().iter().map(Into::into).collect(),
            lookup_index: vi.lookup_index.map(Into::into),
        }
    }
}

// TODO: This should really be a TryFrom or TryInto
impl From<CamlPastaFpPlonkVerifierIndex> for VerifierIndex<Vesta> {
    fn from(index: CamlPastaFpPlonkVerifierIndex) -> Self {
        let evals = index.evals;
        let shifts = index.shifts;

        let (endo_q, _endo_r) = poly_commitment::srs::endos::<Pallas>();
        let domain = Domain::<Fp>::new(1 << index.domain.log_size_of_group).expect("wrong size");

        let coefficients_comm: Vec<PolyComm<Vesta>> =
            evals.coefficients_comm.iter().map(Into::into).collect();
        let coefficients_comm: [_; COLUMNS] = coefficients_comm.try_into().expect("wrong size");

        let sigma_comm: Vec<PolyComm<Vesta>> = evals.sigma_comm.iter().map(Into::into).collect();
        let sigma_comm: [_; PERMUTS] = sigma_comm
            .try_into()
            .expect("vector of sigma comm is of wrong size");

        let shifts: Vec<Fp> = shifts.iter().map(Into::into).collect();
        let shift: [Fp; PERMUTS] = shifts.try_into().expect("wrong size");

        let feature_flags = FeatureFlags {
            range_check0: false,
            range_check1: false,
            foreign_field_add: false,
            foreign_field_mul: false,
            rot: false,
            xor: false,
            lookup_features: LookupFeatures {
                patterns: LookupPatterns {
                    xor: false,
                    lookup: false,
                    range_check: false,
                    foreign_field_mul: false,
                },
                joint_lookup_used: false,
                uses_runtime_tables: false,
            },
        };

        // TODO dummy_lookup_value ?
        let (linearization, powers_of_alpha) = expr_linearization(Some(&feature_flags), true);

        VerifierIndex::<Vesta> {
            domain,
            max_poly_size: index.max_poly_size as usize,
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

            xor_comm: None,

            range_check0_comm: None,
            range_check1_comm: None,
            foreign_field_add_comm: None,
            foreign_field_mul_comm: None,
            rot_comm: None,

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
    srs: CamlFpSrs,
    path: String,
) -> Result<VerifierIndex<Vesta>, ocaml::Error> {
    let path = Path::new(&path);
    let (endo_q, _endo_r) = poly_commitment::srs::endos::<Pallas>();
    VerifierIndex::<Vesta>::from_file(Some(srs.0), path, offset.map(|x| x as u64), endo_q).map_err(
        |_e| {
            ocaml::Error::invalid_argument("caml_pasta_fp_plonk_verifier_index_raw_read")
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
pub fn caml_pasta_fp_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFpSrs,
    path: String,
) -> Result<CamlPastaFpPlonkVerifierIndex, ocaml::Error> {
    let vi = read_raw(offset, srs, path)?;
    Ok(vi.into())
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_write(
    append: Option<bool>,
    index: CamlPastaFpPlonkVerifierIndex,
    path: String,
) -> Result<(), ocaml::Error> {
    let index: VerifierIndex<Vesta> = index.into();
    let path = Path::new(&path);
    index.to_file(path, append).map_err(|_e| {
        ocaml::Error::invalid_argument("caml_pasta_fp_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_create(
    index: CamlPastaFpPlonkIndexPtr,
) -> CamlPastaFpPlonkVerifierIndex {
    {
        let ptr: &mut poly_commitment::srs::SRS<Vesta> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&index.as_ref().0.srs) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }
    let verifier_index = index.as_ref().0.verifier_index();
    verifier_index.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_shifts(log2_size: ocaml::Int) -> Vec<CamlFp> {
    let domain = Domain::<Fp>::new(1 << log2_size).unwrap();
    let shifts = Shifts::new(&domain);
    shifts.shifts().iter().map(Into::into).collect()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_dummy() -> CamlPastaFpPlonkVerifierIndex {
    fn comm() -> CamlPolyComm<CamlGVesta> {
        let g: CamlGVesta = Vesta::prime_subgroup_generator().into();
        CamlPolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }
    fn vec_comm(num: usize) -> Vec<CamlPolyComm<CamlGVesta>> {
        (0..num).map(|_| comm()).collect()
    }

    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: 1,
            group_gen: Fp::one().into(),
        },
        max_poly_size: 0,
        public: 0,
        prev_challenges: 0,
        srs: CamlFpSrs::new(SRS::create(0)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm: vec_comm(PERMUTS),
            coefficients_comm: vec_comm(COLUMNS),
            generic_comm: comm(),
            psm_comm: comm(),
            complete_add_comm: comm(),
            mul_comm: comm(),
            emul_comm: comm(),
            endomul_scalar_comm: comm(),
        },
        shifts: (0..PERMUTS - 1).map(|_| Fp::one().into()).collect(),
        lookup_index: None,
    }
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_deep_copy(
    x: CamlPastaFpPlonkVerifierIndex,
) -> CamlPastaFpPlonkVerifierIndex {
    x
}
