use crate::arkworks::{CamlFp, CamlGVesta};
use crate::caml_pointer::CamlPointer;
use crate::pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr;
use crate::plonk_verifier_index::{
    CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerifierIndex,
};
use crate::srs::fp::CamlFpSRS;
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use commitment_dlog::commitment::caml::CamlPolyComm;
use commitment_dlog::{commitment::PolyComm, srs::SRS};
use mina_curves::pasta::{fp::Fp, pallas::Affine as GAffineOther, vesta::Affine as GAffine};
use ocaml_gen::ocaml_gen;
use oracle::poseidon::PlonkSpongeConstants15W;
use oracle::poseidon::SpongeConstants;
use plonk_15_wires_circuits::gates::poseidon::ROUNDS_PER_ROW;
use plonk_15_wires_circuits::nolookup::constraints::{zk_polynomial, zk_w3, ConstraintSystem};
use plonk_15_wires_circuits::wires::{GENERICS, PERMUTS};
use plonk_15_wires_protocol_dlog::index::VerifierIndex;
use std::convert::TryInto;
use std::path::Path;

//
// CamlPastaFpPlonkVerifierIndex
//

pub type CamlPastaFpPlonkVerifierIndex =
    CamlPlonkVerifierIndex<CamlFp, CamlFpSRS, CamlPolyComm<CamlGVesta>>;

//
// Handy conversion functions
//

impl CamlPastaFpPlonkVerifierIndex {
    pub fn from_verifier_index(vi: VerifierIndex<GAffine>) -> Self {
        let sigma_comm = vi.sigma_comm.to_vec().iter().map(Into::into).collect();
        let qw_comm = vi.qw_comm.to_vec().iter().map(Into::into).collect();
        let rcm_comm: Vec<Vec<_>> = vi
            .rcm_comm
            .to_vec()
            .iter()
            .map(|x| x.to_vec().iter().map(Into::into).collect())
            .collect();
        let shifts = vi.shift.to_vec().iter().map(Into::into).collect();

        Self {
            domain: CamlPlonkDomain {
                log_size_of_group: vi.domain.log_size_of_group as isize,
                group_gen: CamlFp(vi.domain.group_gen),
            },
            max_poly_size: vi.max_poly_size as isize,
            max_quot_size: vi.max_quot_size as isize,
            srs: CamlPointer(vi.srs),
            evals: CamlPlonkVerificationEvals {
                sigma_comm,
                qw_comm,
                qm_comm: vi.qm_comm.into(),
                qc_comm: vi.qc_comm.into(),
                rcm_comm,
                psm_comm: vi.psm_comm.into(),
                add_comm: vi.add_comm.into(),
                double_comm: vi.double_comm.into(),
                mul_comm: vi.mul_comm.into(),
                emul_comm: vi.emul_comm.into(),
            },
            shifts,
        }
    }
}

impl From<CamlPastaFpPlonkVerifierIndex> for VerifierIndex<GAffine> {
    fn from(index: CamlPastaFpPlonkVerifierIndex) -> Self {
        let evals = index.evals;
        let shifts = index.shifts;

        let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
        let domain = Domain::<Fp>::new(1 << index.domain.log_size_of_group).expect("wrong size");

        let qw_comm: Vec<PolyComm<GAffine>> = evals.qw_comm.iter().map(Into::into).collect();
        let qw_comm: [_; GENERICS] = qw_comm.try_into().expect("wrong size");

        let sigma_comm: Vec<PolyComm<GAffine>> = evals.sigma_comm.iter().map(Into::into).collect();
        let sigma_comm: [_; PERMUTS] = sigma_comm
            .try_into()
            .expect("vector of sigma comm is of wrong size");

        let rcm_comm: Vec<[PolyComm<GAffine>; PlonkSpongeConstants15W::SPONGE_WIDTH]> = evals
            .rcm_comm
            .iter()
            .map(|x| {
                x.iter()
                    .map(Into::into)
                    .collect::<Vec<PolyComm<GAffine>>>()
                    .try_into()
                    .expect("wrong")
            })
            .collect();
        let rcm_comm: [_; ROUNDS_PER_ROW] = rcm_comm.try_into().expect("wrong size");

        let shifts: Vec<Fp> = shifts.iter().map(Into::into).collect();
        let shift: [Fp; PERMUTS] = shifts.try_into().expect("wrong size");

        let index = VerifierIndex::<GAffine> {
            domain,
            w: zk_w3(domain),
            zkpm: zk_polynomial(domain),
            max_poly_size: index.max_poly_size as usize,
            max_quot_size: index.max_quot_size as usize,
            srs: index.srs.0,
            sigma_comm,
            qw_comm,
            qm_comm: evals.qm_comm.into(),
            qc_comm: evals.qc_comm.into(),
            rcm_comm,
            psm_comm: evals.psm_comm.into(),
            add_comm: evals.add_comm.into(),
            double_comm: evals.double_comm.into(),
            mul_comm: evals.mul_comm.into(),
            emul_comm: evals.emul_comm.into(),
            shift,
            fr_sponge_params: oracle::pasta::fp::params(),
            fq_sponge_params: oracle::pasta::fq::params(),
            endo: endo_q,
        };
        index
    }
}

//
// Serialization helpers
//

pub fn read_raw<'a>(
    offset: Option<ocaml::Int>,
    srs: CamlFpSRS,
    path: String,
) -> Result<VerifierIndex<GAffine>, ocaml::Error> {
    let path = Path::new(&path);
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
    let fq_sponge_params = oracle::pasta::fq::params();
    let fr_sponge_params = oracle::pasta::fp::params();
    VerifierIndex::<GAffine>::from_file(
        srs.0,
        &path,
        offset.map(|x| x as u64),
        endo_q,
        fq_sponge_params,
        fr_sponge_params,
    )
    .map_err(|e| {
        println!("{}", e);
        ocaml::Error::invalid_argument("caml_pasta_fp_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
}

//
// Methods
//

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFpSRS,
    path: String,
) -> Result<CamlPastaFpPlonkVerifierIndex, ocaml::Error> {
    let vi = read_raw(offset, srs, path)?;
    Ok(CamlPastaFpPlonkVerifierIndex::from_verifier_index(vi))
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_write(
    append: Option<bool>,
    index: CamlPastaFpPlonkVerifierIndex,
    path: String,
) -> Result<(), ocaml::Error> {
    let index: VerifierIndex<GAffine> = index.into();
    let path = Path::new(&path);
    index.to_file(path, append).map_err(|e| {
        println!("{}", e);
        ocaml::Error::invalid_argument("caml_pasta_fp_plonk_verifier_index_raw_read")
            .err()
            .unwrap()
    })
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_create(
    index: CamlPastaFpPlonkIndexPtr,
) -> CamlPastaFpPlonkVerifierIndex {
    let verifier_index = index.as_ref().0.verifier_index();
    CamlPastaFpPlonkVerifierIndex::from_verifier_index(verifier_index)
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_shifts(log2_size: ocaml::Int) -> Vec<CamlFp> {
    let domain = Domain::<Fp>::new(1 << log2_size).unwrap();
    let shifts = ConstraintSystem::sample_shifts(&domain, PERMUTS - 1);
    shifts.iter().map(Into::into).collect()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_dummy() -> CamlPastaFpPlonkVerifierIndex {
    fn comm() -> CamlPolyComm<CamlGVesta> {
        let g: CamlGVesta = GAffine::prime_subgroup_generator().into();
        CamlPolyComm {
            shifted: Some(g.clone()),
            unshifted: vec![g.clone(), g.clone(), g],
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
        max_quot_size: 0,
        srs: CamlPointer::new(SRS::create(0)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm: vec_comm(PERMUTS),
            qw_comm: vec_comm(GENERICS),
            qm_comm: comm(),
            qc_comm: comm(),
            rcm_comm: (0..ROUNDS_PER_ROW)
                .map(|_| vec_comm(PlonkSpongeConstants15W::SPONGE_WIDTH))
                .collect(),
            psm_comm: comm(),
            add_comm: comm(),
            double_comm: comm(),
            mul_comm: comm(),
            emul_comm: comm(),
        },
        shifts: (0..PERMUTS - 1).map(|_| Fp::one().into()).collect(),
    }
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_deep_copy(
    x: CamlPastaFpPlonkVerifierIndex,
) -> CamlPastaFpPlonkVerifierIndex {
    x
}
