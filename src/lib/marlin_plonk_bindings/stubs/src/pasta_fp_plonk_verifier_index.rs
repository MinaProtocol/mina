use crate::index_serialization;
use crate::pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr;
use crate::pasta_fp_urs::CamlPastaFpUrs;
use crate::plonk_verifier_index::{
    CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerificationShifts,
    CamlPlonkVerifierIndex,
};
use crate::{
    arkworks::{CamlFp, CamlGVesta},
    caml_pointer,
};
use ark_ec::AffineCurve;
use ark_ff::One;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use commitment_dlog::commitment::caml::CamlPolyComm;
use commitment_dlog::{
    commitment::PolyComm,
    srs::{SRSValue, SRS},
};
use mina_curves::pasta::{fp::Fp, pallas::Affine as GAffineOther, vesta::Affine as GAffine};
use plonk_circuits::constraints::{zk_polynomial, zk_w, ConstraintSystem};
use plonk_protocol_dlog::index::VerifierIndex as DlogVerifierIndex;
use std::rc::Rc;
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};


pub type CamlPastaFpPlonkVerifierIndex =
    CamlPlonkVerifierIndex<Fp, CamlPastaFpUrs, PolyComm<GAffine>>;

pub fn to_ocaml<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: DlogVerifierIndex<'a, GAffine>,
) -> CamlPastaFpPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2] = vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2] = vi.rcm_comm;
    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as isize,
            group_gen: vi.domain.group_gen,
        },
        max_poly_size: vi.max_poly_size as isize,
        max_quot_size: vi.max_quot_size as isize,
        urs: caml_pointer::create(Rc::clone(urs)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm0: sigma_comm0,
            sigma_comm1: sigma_comm1,
            sigma_comm2: sigma_comm2,
            ql_comm: vi.ql_comm,
            qr_comm: vi.qr_comm,
            qo_comm: vi.qo_comm,
            qm_comm: vi.qm_comm,
            qc_comm: vi.qc_comm,
            rcm_comm0: rcm_comm0,
            rcm_comm1: rcm_comm1,
            rcm_comm2: rcm_comm2,
            psm_comm: vi.psm_comm,
            add_comm: vi.add_comm,
            mul1_comm: vi.mul1_comm,
            mul2_comm: vi.mul2_comm,
            emul1_comm: vi.emul1_comm,
            emul2_comm: vi.emul2_comm,
            emul3_comm: vi.emul3_comm,
        },
        shifts: CamlPlonkVerificationShifts { r: vi.r, o: vi.o },
    }
}

pub fn to_ocaml_copy<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: &DlogVerifierIndex<'a, GAffine>,
) -> CamlPastaFpPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2] = &vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2] = &vi.rcm_comm;
    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as isize,
            group_gen: vi.domain.group_gen,
        },
        max_poly_size: vi.max_poly_size as isize,
        max_quot_size: vi.max_quot_size as isize,
        urs: caml_pointer::create(Rc::clone(urs)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm0: sigma_comm0.clone(),
            sigma_comm1: sigma_comm1.clone(),
            sigma_comm2: sigma_comm2.clone(),
            ql_comm: vi.ql_comm.clone(),
            qr_comm: vi.qr_comm.clone(),
            qo_comm: vi.qo_comm.clone(),
            qm_comm: vi.qm_comm.clone(),
            qc_comm: vi.qc_comm.clone(),
            rcm_comm0: rcm_comm0.clone(),
            rcm_comm1: rcm_comm1.clone(),
            rcm_comm2: rcm_comm2.clone(),
            psm_comm: vi.psm_comm.clone(),
            add_comm: vi.add_comm.clone(),
            mul1_comm: vi.mul1_comm.clone(),
            mul2_comm: vi.mul2_comm.clone(),
            emul1_comm: vi.emul1_comm.clone(),
            emul2_comm: vi.emul2_comm.clone(),
            emul3_comm: vi.emul3_comm.clone(),
        },
        shifts: CamlPlonkVerificationShifts { r: vi.r, o: vi.o },
    }
}

pub fn of_ocaml<'a>(
    max_poly_size: ocaml::Int,
    max_quot_size: ocaml::Int,
    log_size_of_group: ocaml::Int,
    urs: CamlPastaFpUrs,
    evals: CamlPlonkVerificationEvals<PolyComm<GAffine>>,
    shifts: CamlPlonkVerificationShifts<Fp>,
) -> (DlogVerifierIndex<'a, GAffine>, Rc<SRS<GAffine>>) {
    let urs_copy = Rc::clone(&*urs);
    let urs_copy_outer = Rc::clone(&*urs);
    let srs = {
        // We know that the underlying value is still alive, because we never convert any of our
        // Rc<_>s into weak pointers.
        SRSValue::Ref(unsafe { &*Rc::into_raw(urs_copy) })
    };
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
    let domain = Domain::<Fp>::new(1 << log_size_of_group).unwrap();
    let index = DlogVerifierIndex::<GAffine> {
        domain,
        w: zk_w(domain),
        zkpm: zk_polynomial(domain),
        max_poly_size: max_poly_size as usize,
        max_quot_size: max_quot_size as usize,
        srs,
        sigma_comm: [evals.sigma_comm0, evals.sigma_comm1, evals.sigma_comm2],
        ql_comm: evals.ql_comm,
        qr_comm: evals.qr_comm,
        qo_comm: evals.qo_comm,
        qm_comm: evals.qm_comm,
        qc_comm: evals.qc_comm,
        rcm_comm: [evals.rcm_comm0, evals.rcm_comm1, evals.rcm_comm2],
        psm_comm: evals.psm_comm,
        add_comm: evals.add_comm,
        mul1_comm: evals.mul1_comm,
        mul2_comm: evals.mul2_comm,
        emul1_comm: evals.emul1_comm,
        emul2_comm: evals.emul2_comm,
        emul3_comm: evals.emul3_comm,
        r: shifts.r,
        o: shifts.o,
        fr_sponge_params: oracle::pasta::fp::params(),
        fq_sponge_params: oracle::pasta::fq::params(),
        endo: endo_q,
    };
    (index, urs_copy_outer)
}

impl From<CamlPastaFpPlonkVerifierIndex> for DlogVerifierIndex<'_, GAffine> {
    fn from(index: CamlPastaFpPlonkVerifierIndex) -> Self {
        of_ocaml(
            index.max_poly_size,
            index.max_quot_size,
            index.domain.log_size_of_group,
            index.urs,
            index.evals,
            index.shifts,
        )
        .0
    }
}

pub fn read_raw<'a>(
    offset: Option<ocaml::Int>,
    urs: CamlPastaFpUrs,
    path: String,
) -> Result<(DlogVerifierIndex<'a, GAffine>, Rc<SRS<GAffine>>), ocaml::Error> {
    match File::open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument(
            "caml_pasta_fp_plonk_verifier_index_raw_read",
        )
        .err()
        .unwrap()),
        Ok(file) => {
            let mut r = BufReader::new(file);
            match offset {
                Some(offset) => {
                    r.seek(Start(offset as u64))?;
                }
                None => (),
            };
            let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
            let urs_copy = Rc::clone(&*urs);
            let urs_copy2 = Rc::clone(&urs_copy);
            let t = index_serialization::read_plonk_verifier_index(
                oracle::pasta::fp::params(),
                oracle::pasta::fq::params(),
                endo_q,
                Rc::into_raw(urs_copy2),
                &mut r,
            )?;
            Ok((t, Rc::clone(&urs_copy)))
        }
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    urs: CamlPastaFpUrs,
    path: String,
) -> Result<CamlPastaFpPlonkVerifierIndex, ocaml::Error> {
    let (vi, urs) = read_raw(offset, urs, path)?;
    Ok(to_ocaml(&urs, vi))
}

pub fn write_raw(
    append: Option<bool>,
    index: &DlogVerifierIndex<GAffine>,
    path: String,
) -> Result<(), ocaml::Error> {
    match OpenOptions::new().append(append.unwrap_or(true)).open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument(
            "caml_pasta_fp_plonk_verifier_index_raw_read",
        )
        .err()
        .unwrap()),
        Ok(file) => {
            let mut w = BufWriter::new(file);

            Ok(index_serialization::write_plonk_verifier_index(
                index, &mut w,
            )?)
        }
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_write(
    append: Option<bool>,
    index: CamlPastaFpPlonkVerifierIndex,
    path: String,
) -> Result<(), ocaml::Error> {
    write_raw(append, &index.into(), path)
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_create(
    index: CamlPastaFpPlonkIndexPtr,
) -> CamlPastaFpPlonkVerifierIndex {
    let index = index.as_ref();
    to_ocaml(&index.1, index.0.verifier_index())
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_shifts(
    log2_size: ocaml::Int,
) -> CamlPlonkVerificationShifts<Fp> {
    let (a, b) = ConstraintSystem::sample_shifts(&Domain::new(1 << log2_size).unwrap());
    CamlPlonkVerificationShifts { r: a, o: b }
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_dummy() -> CamlPastaFpPlonkVerifierIndex {
    let g = || GAffine::prime_subgroup_generator();
    let comm = || PolyComm {
        shifted: Some(g()),
        unshifted: vec![g(), g(), g()],
    };
    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: 1,
            group_gen: Fp::one(),
        },
        max_poly_size: 0,
        max_quot_size: 0,
        urs: caml_pointer::create(Rc::new(SRS::create(0))),
        evals: CamlPlonkVerificationEvals {
            sigma_comm0: comm(),
            sigma_comm1: comm(),
            sigma_comm2: comm(),
            ql_comm: comm(),
            qr_comm: comm(),
            qo_comm: comm(),
            qm_comm: comm(),
            qc_comm: comm(),
            rcm_comm0: comm(),
            rcm_comm1: comm(),
            rcm_comm2: comm(),
            psm_comm: comm(),
            add_comm: comm(),
            mul1_comm: comm(),
            mul2_comm: comm(),
            emul1_comm: comm(),
            emul2_comm: comm(),
            emul3_comm: comm(),
        },
        shifts: CamlPlonkVerificationShifts {
            r: Fp::one(),
            o: Fp::one(),
        },
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_verifier_index_deep_copy(
    x: CamlPastaFpPlonkVerifierIndex,
) -> CamlPastaFpPlonkVerifierIndex {
    x
}
