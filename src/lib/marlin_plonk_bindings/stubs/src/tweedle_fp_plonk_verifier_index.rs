use crate::index_serialization;
use crate::plonk_verifier_index::{
    CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerificationShifts,
    CamlPlonkVerifierIndex,
};
use crate::tweedle_dee::CamlTweedleDeePolyComm;
use crate::tweedle_fp_plonk_index::CamlTweedleFpPlonkIndexPtr;
use crate::tweedle_fp_urs::CamlTweedleFpUrs;
use algebra::{One, tweedle::{dee::Affine as GAffine, dum::Affine as GAffineOther, fp::Fp, fq::Fq}};

use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};

use commitment_dlog::srs::SRS;
use plonk_circuits::constraints::{zk_polynomial, zk_w, ConstraintSystem};
use plonk_protocol_dlog::index::{SRSValue, VerifierIndex as DlogVerifierIndex};

use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

use std::rc::Rc;

pub struct CamlTweedleFpPlonkVerifierIndexRaw<'a>(
    pub DlogVerifierIndex<'a, GAffine>,
    pub Rc<SRS<GAffine>>,
);

pub type CamlTweedleFpPlonkVerifierIndexRawPtr<'a> =
    ocaml::Pointer<CamlTweedleFpPlonkVerifierIndexRaw<'a>>;

extern "C" fn caml_tweedle_fp_plonk_verifier_index_raw_finalize(v: ocaml::Value) {
    let v: ocaml::Pointer<CamlTweedleFpPlonkVerifierIndexRaw> = ocaml::FromValue::from_value(v);
    unsafe { v.drop_in_place() };
}

ocaml::custom!(CamlTweedleFpPlonkVerifierIndexRaw<'a> {
    finalize: caml_tweedle_fp_plonk_verifier_index_raw_finalize,
});

pub type CamlTweedleFpPlonkVerifierIndex =
    CamlPlonkVerifierIndex<Fp, CamlTweedleFpUrs, CamlTweedleDeePolyComm<Fq>>;

pub fn to_ocaml<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: DlogVerifierIndex<'a, GAffine>,
) -> CamlTweedleFpPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2, sigma_comm3, sigma_comm4] = vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2, rcm_comm3, rcm_comm4] = vi.rcm_comm;
    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as isize,
            group_gen: vi.domain.group_gen,
        },
        max_poly_size: vi.max_poly_size as isize,
        max_quot_size: vi.max_quot_size as isize,
        urs: CamlTweedleFpUrs(Rc::clone(urs)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm0: sigma_comm0.into(),
            sigma_comm1: sigma_comm1.into(),
            sigma_comm2: sigma_comm2.into(),
            sigma_comm3: sigma_comm3.into(),
            sigma_comm4: sigma_comm4.into(),
            ql_comm: vi.qw_comm[0].clone().into(),
            qr_comm: vi.qw_comm[1].clone().into(),
            qo_comm: vi.qw_comm[2].clone().into(),
            qq_comm: vi.qw_comm[3].clone().into(),
            qp_comm: vi.qw_comm[4].clone().into(),
            qm_comm: vi.qm_comm.into(),
            qc_comm: vi.qc_comm.into(),
            rcm_comm0: rcm_comm0.into(),
            rcm_comm1: rcm_comm1.into(),
            rcm_comm2: rcm_comm2.into(),
            rcm_comm3: rcm_comm3.into(),
            rcm_comm4: rcm_comm4.into(),
            psm_comm: vi.psm_comm.into(),
            add_comm: vi.add_comm.into(),
            double_comm: vi.double_comm.into(),
            mul1_comm: vi.mul1_comm.into(),
            mul2_comm: vi.mul2_comm.into(),
            emul_comm: vi.emul_comm.into(),
            pack_comm: vi.pack_comm.into(),
        },
        shifts: CamlPlonkVerificationShifts {
            s0: vi.shift[0],
            s1: vi.shift[1],
            s2: vi.shift[2],
            s3: vi.shift[3],
            s4: vi.shift[4],
        },
    }
}

pub fn to_ocaml_copy<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: &DlogVerifierIndex<'a, GAffine>,
) -> CamlTweedleFpPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2, sigma_comm3, sigma_comm4] = &vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2, rcm_comm3, rcm_comm4] = &vi.rcm_comm;
    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as isize,
            group_gen: vi.domain.group_gen,
        },
        max_poly_size: vi.max_poly_size as isize,
        max_quot_size: vi.max_quot_size as isize,
        urs: CamlTweedleFpUrs(Rc::clone(urs)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm0: sigma_comm0.clone().into(),
            sigma_comm1: sigma_comm1.clone().into(),
            sigma_comm2: sigma_comm2.clone().into(),
            sigma_comm3: sigma_comm3.clone().into(),
            sigma_comm4: sigma_comm4.clone().into(),
            ql_comm: vi.qw_comm[0].clone().into(),
            qr_comm: vi.qw_comm[1].clone().into(),
            qo_comm: vi.qw_comm[2].clone().into(),
            qq_comm: vi.qw_comm[3].clone().into(),
            qp_comm: vi.qw_comm[4].clone().into(),
            qm_comm: vi.qm_comm.clone().into(),
            qc_comm: vi.qc_comm.clone().into(),
            rcm_comm0: rcm_comm0.clone().into(),
            rcm_comm1: rcm_comm1.clone().into(),
            rcm_comm2: rcm_comm2.clone().into(),
            rcm_comm3: rcm_comm3.clone().into(),
            rcm_comm4: rcm_comm4.clone().into(),
            psm_comm: vi.psm_comm.clone().into(),
            add_comm: vi.add_comm.clone().into(),
            double_comm: vi.double_comm.clone().into(),
            mul1_comm: vi.mul1_comm.clone().into(),
            mul2_comm: vi.mul2_comm.clone().into(),
            emul_comm: vi.emul_comm.clone().into(),
            pack_comm: vi.pack_comm.clone().into(),
        },
        shifts: CamlPlonkVerificationShifts {
            s0: vi.shift[0],
            s1: vi.shift[1],
            s2: vi.shift[2],
            s3: vi.shift[3],
            s4: vi.shift[4],
        },
    }
}

pub fn of_ocaml<'a>(
    max_poly_size: ocaml::Int,
    max_quot_size: ocaml::Int,
    log_size_of_group: ocaml::Int,
    urs: CamlTweedleFpUrs,
    evals: CamlPlonkVerificationEvals<CamlTweedleDeePolyComm<Fq>>,
    shifts: CamlPlonkVerificationShifts<Fp>,
) -> CamlTweedleFpPlonkVerifierIndexRaw<'a> {
    let urs_copy = Rc::clone(&urs.0);
    let urs_copy_outer = Rc::clone(&urs.0);
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
        sigma_comm: [
            evals.sigma_comm0.into(),
            evals.sigma_comm1.into(),
            evals.sigma_comm2.into(),
            evals.sigma_comm3.into(),
            evals.sigma_comm4.into(),
        ],
        qw_comm: [
            evals.ql_comm.into(),
            evals.qr_comm.into(),
            evals.qo_comm.into(),
            evals.qq_comm.into(),
            evals.qp_comm.into(),
        ],
        qm_comm: evals.qm_comm.into(),
        qc_comm: evals.qc_comm.into(),
        rcm_comm: [
            evals.rcm_comm0.into(),
            evals.rcm_comm1.into(),
            evals.rcm_comm2.into(),
            evals.rcm_comm3.into(),
            evals.rcm_comm4.into(),
        ],
        psm_comm: evals.psm_comm.into(),
        add_comm: evals.add_comm.into(),
        double_comm: evals.double_comm.into(),
        mul1_comm: evals.mul1_comm.into(),
        mul2_comm: evals.mul2_comm.into(),
        emul_comm: evals.emul_comm.into(),
        pack_comm: evals.pack_comm.into(),
        shift: [shifts.s0, shifts.s1, shifts.s2, shifts.s3, shifts.s4],
        fr_sponge_params: oracle::tweedle::fp5::params(),
        fq_sponge_params: oracle::tweedle::fq5::params(),
        endo: endo_q,
    };
    CamlTweedleFpPlonkVerifierIndexRaw(index, urs_copy_outer)
}

impl From<CamlTweedleFpPlonkVerifierIndex> for CamlTweedleFpPlonkVerifierIndexRaw<'_> {
    fn from(index: CamlTweedleFpPlonkVerifierIndex) -> Self {
        of_ocaml(
            index.max_poly_size,
            index.max_quot_size,
            index.domain.log_size_of_group,
            index.urs,
            index.evals,
            index.shifts,
        )
    }
}

impl From<CamlTweedleFpPlonkVerifierIndex> for DlogVerifierIndex<'_, GAffine> {
    fn from(index: CamlTweedleFpPlonkVerifierIndex) -> Self {
        CamlTweedleFpPlonkVerifierIndexRaw::from(index).0
    }
}

pub fn read_raw<'a>(
    offset: Option<ocaml::Int>,
    urs: CamlTweedleFpUrs,
    path: String,
) -> Result<CamlTweedleFpPlonkVerifierIndexRaw<'a>, ocaml::Error> {
    match File::open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument(
            "caml_tweedle_fp_plonk_verifier_index_raw_read",
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
            let urs_copy = Rc::clone(&urs.0);
            let t = index_serialization::read_plonk_verifier_index(
                oracle::tweedle::fp::params(),
                oracle::tweedle::fq::params(),
                endo_q,
                Rc::into_raw(urs.0),
                &mut r,
            )?;
            Ok(CamlTweedleFpPlonkVerifierIndexRaw(t, Rc::clone(&urs_copy)))
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_raw_read(
    offset: Option<ocaml::Int>,
    urs: CamlTweedleFpUrs,
    path: String,
) -> Result<CamlTweedleFpPlonkVerifierIndexRaw<'static>, ocaml::Error> {
    read_raw(offset, urs, path)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_read(
    offset: Option<ocaml::Int>,
    urs: CamlTweedleFpUrs,
    path: String,
) -> Result<CamlTweedleFpPlonkVerifierIndex, ocaml::Error> {
    let t = read_raw(offset, urs, path)?;
    Ok(to_ocaml(&t.1, t.0))
}

pub fn write_raw(
    append: Option<bool>,
    index: &DlogVerifierIndex<GAffine>,
    path: String,
) -> Result<(), ocaml::Error> {
    match OpenOptions::new().append(append.unwrap_or(true)).open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument(
            "caml_tweedle_fp_plonk_verifier_index_raw_read",
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
pub fn caml_tweedle_fp_plonk_verifier_index_raw_write(
    append: Option<bool>,
    index: CamlTweedleFpPlonkVerifierIndexRawPtr,
    path: String,
) -> Result<(), ocaml::Error> {
    write_raw(append, &index.as_ref().0, path)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_write(
    append: Option<bool>,
    index: CamlTweedleFpPlonkVerifierIndex,
    path: String,
) -> Result<(), ocaml::Error> {
    write_raw(
        append,
        &CamlTweedleFpPlonkVerifierIndexRaw::from(index).0,
        path,
    )
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_raw_of_parts(
    max_poly_size: ocaml::Int,
    max_quot_size: ocaml::Int,
    log_size_of_group: ocaml::Int,
    urs: CamlTweedleFpUrs,
    evals: CamlPlonkVerificationEvals<CamlTweedleDeePolyComm<Fq>>,
    shifts: CamlPlonkVerificationShifts<Fp>,
) -> CamlTweedleFpPlonkVerifierIndexRaw<'static> {
    of_ocaml(
        max_poly_size,
        max_quot_size,
        log_size_of_group,
        urs,
        evals,
        shifts,
    )
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_raw_of_ocaml(
    index: CamlTweedleFpPlonkVerifierIndex,
) -> CamlTweedleFpPlonkVerifierIndexRaw<'static> {
    index.into()
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_ocaml_of_raw(
    index: CamlTweedleFpPlonkVerifierIndexRawPtr,
) -> CamlTweedleFpPlonkVerifierIndex {
    let index = index.as_ref();
    // We make a copy here because we can't move values out of the raw version.
    to_ocaml_copy(&index.1, &index.0)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_raw_create(
    index: CamlTweedleFpPlonkIndexPtr<'static>,
) -> CamlTweedleFpPlonkVerifierIndexRaw<'static> {
    let urs = Rc::clone(&index.as_ref().1);
    let verifier_index: DlogVerifierIndex<'static, GAffine> =
        // The underlying urs reference forces a lifetime borrow of `index`, but really
        // * we only need to borrow the urs
        // * we know statically that the urs will be live for the whole duration because of the
        //   refcounted references.
        // We prefer this to a pointer round-trip because we don't want to allocate memory when the
        // optimizer will otherwise see to place this straight in the OCaml heap.
        unsafe { std::mem::transmute(index.as_ref().0.verifier_index()) };
    CamlTweedleFpPlonkVerifierIndexRaw(verifier_index, urs)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_create(
    index: CamlTweedleFpPlonkIndexPtr,
) -> CamlTweedleFpPlonkVerifierIndex {
    let index = index.as_ref();
    to_ocaml(&index.1, index.0.verifier_index())
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_verifier_index_shifts(
    log2_size: ocaml::Int,
) -> CamlPlonkVerificationShifts<Fp> {
    let sh = ConstraintSystem::sample_shifts(&Domain::new(1 << log2_size).unwrap(), 4);
    CamlPlonkVerificationShifts {
        s0: Fp::one(),
        s1: sh[0],
        s2: sh[1],
        s3: sh[2],
        s4: sh[3],
    }
}
