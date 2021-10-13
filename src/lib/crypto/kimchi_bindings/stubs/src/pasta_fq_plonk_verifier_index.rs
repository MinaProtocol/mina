use crate::arkworks::{CamlFq, CamlGPallas};
use crate::caml_pointer::CamlPointer;
use crate::pasta_fq_plonk_index::CamlPastaFqPlonkIndexPtr;
use crate::plonk_verifier_index::{
    CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex,
};
use crate::srs::fq::CamlFqSRS;
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use commitment_dlog::commitment::caml::CamlPolyComm;
use commitment_dlog::{commitment::PolyComm, srs::SRS};
use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine, vesta::Affine as GAffineOther};
use ocaml_gen::ocaml_gen;
use oracle::poseidon::PlonkSpongeConstants15W;
use oracle::poseidon::SpongeConstants;
use plonk_15_wires_circuits::gates::poseidon::ROUNDS_PER_ROW;
use plonk_15_wires_circuits::nolookup::constraints::{zk_polynomial, zk_w3, ConstraintSystem};
use plonk_15_wires_circuits::wires::{COLUMNS, PERMUTS};
use plonk_15_wires_protocol_dlog::index::VerifierIndex;
use std::convert::TryInto;
use std::path::Path;

//
// CamlPastaFqPlonkVerifierIndex
//

pub type CamlPastaFqPlonkVerifierIndex =
    CamlPlonkVerifierIndex<CamlFq, CamlFqSRS, CamlPolyComm<CamlGPallas>>;

//
// Handy conversion functions
//

impl From<VerifierIndex<GAffine>> for CamlPastaFqPlonkVerifierIndex {
    fn from(vi: VerifierIndex<GAffine>) -> Self {
        Self {
            domain: CamlPlonkDomain {
                log_size_of_group: vi.domain.log_size_of_group as isize,
                group_gen: CamlFq(vi.domain.group_gen),
            },
            max_poly_size: vi.max_poly_size as isize,
            max_quot_size: vi.max_quot_size as isize,
            srs: CamlPointer(vi.srs),
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
                add_comm: vi.add_comm.into(),
                double_comm: vi.double_comm.into(),
                mul_comm: vi.mul_comm.into(),
                emul_comm: vi.emul_comm.into(),
            },
            shifts: vi.shift.to_vec().iter().map(Into::into).collect(),
        }
    }
}

impl From<CamlPastaFqPlonkVerifierIndex> for VerifierIndex<GAffine> {
    fn from(index: CamlPastaFqPlonkVerifierIndex) -> Self {
        let evals = index.evals;
        let shifts = index.shifts;

        let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
        let domain = Domain::<Fq>::new(1 << index.domain.log_size_of_group).expect("wrong size");

        let coefficients_comm: Vec<PolyComm<GAffine>> =
            evals.coefficients_comm.iter().map(Into::into).collect();
        let coefficients_comm: [_; COLUMNS] = coefficients_comm.try_into().expect("wrong size");

        let sigma_comm: Vec<PolyComm<GAffine>> = evals.sigma_comm.iter().map(Into::into).collect();
        let sigma_comm: [_; PERMUTS] = sigma_comm
            .try_into()
            .expect("vector of sigma comm is of wrong size");

        let shifts: Vec<Fq> = shifts.iter().map(Into::into).collect();
        let shift: [Fq; PERMUTS] = shifts.try_into().expect("wrong size");

        VerifierIndex::<GAffine> {
            domain,
            w: zk_w3(domain),
            zkpm: zk_polynomial(domain),
            max_poly_size: index.max_poly_size as usize,
            max_quot_size: index.max_quot_size as usize,
            srs: index.srs.0,
            sigma_comm,
            coefficients_comm,
            generic_comm: evals.generic_comm.into(),
            psm_comm: evals.psm_comm.into(),
            add_comm: evals.add_comm.into(),
            double_comm: evals.double_comm.into(),
            mul_comm: evals.mul_comm.into(),
            emul_comm: evals.emul_comm.into(),
            shift,
            fr_sponge_params: oracle::pasta::fq::params(),
            fq_sponge_params: oracle::pasta::fp::params(),
            endo: endo_q,
        }
    }
}

//
// Serialization helpers
//

pub fn read_raw(
    offset: Option<ocaml::Int>,
    srs: CamlFqSRS,
    path: String,
) -> Result<VerifierIndex<GAffine>, ocaml::Error> {
    let path = Path::new(&path);
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
    let fq_sponge_params = oracle::pasta::fp::params();
    let fr_sponge_params = oracle::pasta::fq::params();
    VerifierIndex::<GAffine>::from_file(
        srs.0,
        path,
        offset.map(|x| x as u64),
        endo_q,
        fq_sponge_params,
        fr_sponge_params,
    )
    .map_err(|e| {
        println!("{}", e);
        ocaml::Error::invalid_argument("caml_pasta_fq_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
}

//
// Methods
//

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFqSRS,
    path: String,
) -> Result<CamlPastaFqPlonkVerifierIndex, ocaml::Error> {
    let vi = read_raw(offset, srs, path)?;
    Ok(vi.into())
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_write(
    append: Option<bool>,
    index: CamlPastaFqPlonkVerifierIndex,
    path: String,
) -> Result<(), ocaml::Error> {
    let index: VerifierIndex<GAffine> = index.into();
    let path = Path::new(&path);
    index.to_file(path, append).map_err(|e| {
        println!("{}", e);
        ocaml::Error::invalid_argument("caml_pasta_fq_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_create(
    index: CamlPastaFqPlonkIndexPtr,
) -> CamlPastaFqPlonkVerifierIndex {
    let verifier_index = index.as_ref().0.verifier_index();
    verifier_index.into()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_shifts(log2_size: ocaml::Int) -> Vec<CamlFq> {
    let domain = Domain::<Fq>::new(1 << log2_size).unwrap();
    let shifts = ConstraintSystem::sample_shifts(&domain, PERMUTS - 1);
    shifts.iter().map(Into::into).collect()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_dummy() -> CamlPastaFqPlonkVerifierIndex {
    fn comm() -> CamlPolyComm<CamlGPallas> {
        let g: CamlGPallas = GAffine::prime_subgroup_generator().into();
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
        srs: CamlPointer::new(SRS::create(0)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm: vec_comm(PERMUTS),
            coefficients_comm: vec_comm(COLUMNS),
            generic_comm: comm(),
            psm_comm: comm(),
            add_comm: comm(),
            double_comm: comm(),
            mul_comm: comm(),
            emul_comm: comm(),
        },
        shifts: (0..PERMUTS - 1).map(|_| Fq::one().into()).collect(),
    }
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_verifier_index_deep_copy(
    x: CamlPastaFqPlonkVerifierIndex,
) -> CamlPastaFqPlonkVerifierIndex {
    x
}
