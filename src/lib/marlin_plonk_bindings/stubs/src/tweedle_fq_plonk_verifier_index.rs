use crate::index_serialization;
use crate::plonk_verifier_index::{
    CamlPlonkDomain, CamlPlonkVerificationEvals, CamlPlonkVerificationShifts,
    CamlPlonkVerifierIndex,
};
use crate::tweedle_dum::CamlTweedleDumPolyComm;
use crate::tweedle_fp::{CamlTweedleFp, CamlTweedleFpPtr};
use crate::tweedle_fq::{CamlTweedleFq, CamlTweedleFqPtr};
use crate::tweedle_fq_plonk_index::CamlTweedleFqPlonkIndexPtr;
use crate::tweedle_fq_urs::CamlTweedleFqUrs;
use algebra::tweedle::{dee::Affine as GAffineOther, dum::Affine as GAffine, fq::Fq};

use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};

use commitment_dlog::srs::SRS;
use plonk_protocol_dlog::index::{SRSValue, VerifierIndex as DlogVerifierIndex};

use std::{
    fs::File,
    io::{BufReader, BufWriter},
};

use std::rc::Rc;

pub struct CamlTweedleFqPlonkVerifierIndexRaw<'a>(
    pub DlogVerifierIndex<'a, GAffine>,
    pub Rc<SRS<GAffine>>,
);

pub type CamlTweedleFqPlonkVerifierIndexRawPtr<'a> =
    ocaml::Pointer<CamlTweedleFqPlonkVerifierIndexRaw<'a>>;

extern "C" fn caml_tweedle_fq_plonk_verifier_index_raw_finalize(v: ocaml::Value) {
    let v: ocaml::Pointer<CamlTweedleFqPlonkVerifierIndexRaw> = ocaml::FromValue::from_value(v);
    unsafe { v.drop_in_place() };
}

ocaml::custom!(CamlTweedleFqPlonkVerifierIndexRaw<'a> {
    finalize: caml_tweedle_fq_plonk_verifier_index_raw_finalize,
});

pub type CamlTweedleFqPlonkVerifierIndex =
    CamlPlonkVerifierIndex<CamlTweedleFq, CamlTweedleFqUrs, CamlTweedleDumPolyComm<CamlTweedleFp>>;
pub type CamlTweedleFqPlonkVerifierIndexPtr = CamlPlonkVerifierIndex<
    CamlTweedleFqPtr,
    CamlTweedleFqUrs,
    CamlTweedleDumPolyComm<CamlTweedleFpPtr>,
>;

pub fn to_ocaml<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: DlogVerifierIndex<'a, GAffine>,
) -> CamlTweedleFqPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2] = vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2] = vi.rcm_comm;
    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as isize,
            group_gen: CamlTweedleFq(vi.domain.group_gen),
        },
        max_poly_size: vi.max_poly_size as isize,
        max_quot_size: vi.max_quot_size as isize,
        urs: CamlTweedleFqUrs(Rc::clone(urs)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm0: sigma_comm0.into(),
            sigma_comm1: sigma_comm1.into(),
            sigma_comm2: sigma_comm2.into(),
            ql_comm: vi.ql_comm.into(),
            qr_comm: vi.qr_comm.into(),
            qo_comm: vi.qo_comm.into(),
            qm_comm: vi.qm_comm.into(),
            qc_comm: vi.qc_comm.into(),
            rcm_comm0: rcm_comm0.into(),
            rcm_comm1: rcm_comm1.into(),
            rcm_comm2: rcm_comm2.into(),
            psm_comm: vi.psm_comm.into(),
            add_comm: vi.add_comm.into(),
            mul1_comm: vi.mul1_comm.into(),
            mul2_comm: vi.mul2_comm.into(),
            emul1_comm: vi.emul1_comm.into(),
            emul2_comm: vi.emul2_comm.into(),
            emul3_comm: vi.emul3_comm.into(),
        },
        shifts: CamlPlonkVerificationShifts {
            r: CamlTweedleFq(vi.r),
            o: CamlTweedleFq(vi.o),
        },
    }
}

pub fn to_ocaml_copy<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: &DlogVerifierIndex<'a, GAffine>,
) -> CamlTweedleFqPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2] = &vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2] = &vi.rcm_comm;
    CamlPlonkVerifierIndex {
        domain: CamlPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as isize,
            group_gen: CamlTweedleFq(vi.domain.group_gen),
        },
        max_poly_size: vi.max_poly_size as isize,
        max_quot_size: vi.max_quot_size as isize,
        urs: CamlTweedleFqUrs(Rc::clone(urs)),
        evals: CamlPlonkVerificationEvals {
            sigma_comm0: sigma_comm0.clone().into(),
            sigma_comm1: sigma_comm1.clone().into(),
            sigma_comm2: sigma_comm2.clone().into(),
            ql_comm: vi.ql_comm.clone().into(),
            qr_comm: vi.qr_comm.clone().into(),
            qo_comm: vi.qo_comm.clone().into(),
            qm_comm: vi.qm_comm.clone().into(),
            qc_comm: vi.qc_comm.clone().into(),
            rcm_comm0: rcm_comm0.clone().into(),
            rcm_comm1: rcm_comm1.clone().into(),
            rcm_comm2: rcm_comm2.clone().into(),
            psm_comm: vi.psm_comm.clone().into(),
            add_comm: vi.add_comm.clone().into(),
            mul1_comm: vi.mul1_comm.clone().into(),
            mul2_comm: vi.mul2_comm.clone().into(),
            emul1_comm: vi.emul1_comm.clone().into(),
            emul2_comm: vi.emul2_comm.clone().into(),
            emul3_comm: vi.emul3_comm.clone().into(),
        },
        shifts: CamlPlonkVerificationShifts {
            r: CamlTweedleFq(vi.r),
            o: CamlTweedleFq(vi.o),
        },
    }
}

pub fn of_ocaml<'a>(
    max_poly_size: ocaml::Int,
    max_quot_size: ocaml::Int,
    urs: CamlTweedleFqUrs,
    evals: CamlPlonkVerificationEvals<CamlTweedleDumPolyComm<CamlTweedleFpPtr>>,
    shifts: CamlPlonkVerificationShifts<CamlTweedleFqPtr>,
) -> CamlTweedleFqPlonkVerifierIndexRaw<'a> {
    let urs_copy = Rc::clone(&urs.0);
    let urs_copy_outer = Rc::clone(&urs.0);
    let srs = {
        // We know that the underlying value is still alive, because we never convert any of our
        // Rc<_>s into weak pointers.
        SRSValue::Ref(unsafe { &*Rc::into_raw(urs_copy) })
    };
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
    let index = DlogVerifierIndex::<GAffine> {
        domain: Domain::<Fq>::new(max_poly_size as usize).unwrap(),
        max_poly_size: max_poly_size as usize,
        max_quot_size: max_quot_size as usize,
        srs,
        sigma_comm: [
            evals.sigma_comm0.into(),
            evals.sigma_comm1.into(),
            evals.sigma_comm2.into(),
        ],
        ql_comm: evals.ql_comm.into(),
        qr_comm: evals.qr_comm.into(),
        qo_comm: evals.qo_comm.into(),
        qm_comm: evals.qm_comm.into(),
        qc_comm: evals.qc_comm.into(),
        rcm_comm: [
            evals.rcm_comm0.into(),
            evals.rcm_comm1.into(),
            evals.rcm_comm2.into(),
        ],
        psm_comm: evals.psm_comm.into(),
        add_comm: evals.add_comm.into(),
        mul1_comm: evals.mul1_comm.into(),
        mul2_comm: evals.mul2_comm.into(),
        emul1_comm: evals.emul1_comm.into(),
        emul2_comm: evals.emul2_comm.into(),
        emul3_comm: evals.emul3_comm.into(),
        r: shifts.r.as_ref().0,
        o: shifts.o.as_ref().0,
        fr_sponge_params: oracle::tweedle::fq::params(),
        fq_sponge_params: oracle::tweedle::fp::params(),
        endo: endo_q,
    };
    CamlTweedleFqPlonkVerifierIndexRaw(index, urs_copy_outer)
}

impl From<CamlTweedleFqPlonkVerifierIndexPtr> for CamlTweedleFqPlonkVerifierIndexRaw<'_> {
    fn from(index: CamlTweedleFqPlonkVerifierIndexPtr) -> Self {
        of_ocaml(
            index.max_poly_size,
            index.max_quot_size,
            index.urs,
            index.evals,
            index.shifts,
        )
    }
}

impl From<CamlTweedleFqPlonkVerifierIndexPtr> for DlogVerifierIndex<'_, GAffine> {
    fn from(index: CamlTweedleFqPlonkVerifierIndexPtr) -> Self {
        CamlTweedleFqPlonkVerifierIndexRaw::from(index).0
    }
}

pub fn read_raw<'a>(
    urs: CamlTweedleFqUrs,
    path: String,
) -> Result<CamlTweedleFqPlonkVerifierIndexRaw<'a>, ocaml::Error> {
    match File::open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument(
            "caml_tweedle_fq_plonk_verifier_index_raw_read",
        )
        .err()
        .unwrap()),
        Ok(file) => {
            let mut r = BufReader::new(file);
            let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
            let urs_copy = Rc::clone(&urs.0);
            let t = index_serialization::read_plonk_verifier_index(
                oracle::tweedle::fq::params(),
                oracle::tweedle::fp::params(),
                endo_q,
                Rc::into_raw(urs.0),
                &mut r,
            )?;
            Ok(CamlTweedleFqPlonkVerifierIndexRaw(t, Rc::clone(&urs_copy)))
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_raw_read(
    urs: CamlTweedleFqUrs,
    path: String,
) -> Result<CamlTweedleFqPlonkVerifierIndexRaw<'static>, ocaml::Error> {
    read_raw(urs, path)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_read(
    urs: CamlTweedleFqUrs,
    path: String,
) -> Result<CamlTweedleFqPlonkVerifierIndex, ocaml::Error> {
    let t = read_raw(urs, path)?;
    Ok(to_ocaml(&t.1, t.0))
}

pub fn write_raw(index: &DlogVerifierIndex<GAffine>, path: String) -> Result<(), ocaml::Error> {
    match File::create(path) {
        Err(_) => Err(ocaml::Error::invalid_argument(
            "caml_tweedle_fq_plonk_verifier_index_raw_read",
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
pub fn caml_tweedle_fq_plonk_verifier_index_raw_write(
    index: CamlTweedleFqPlonkVerifierIndexRawPtr,
    path: String,
) -> Result<(), ocaml::Error> {
    write_raw(&index.as_ref().0, path)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_write(
    index: CamlTweedleFqPlonkVerifierIndexPtr,
    path: String,
) -> Result<(), ocaml::Error> {
    write_raw(&CamlTweedleFqPlonkVerifierIndexRaw::from(index).0, path)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_raw_of_parts(
    max_poly_size: ocaml::Int,
    max_quot_size: ocaml::Int,
    urs: CamlTweedleFqUrs,
    evals: CamlPlonkVerificationEvals<CamlTweedleDumPolyComm<CamlTweedleFpPtr>>,
    shifts: CamlPlonkVerificationShifts<CamlTweedleFqPtr>,
) -> CamlTweedleFqPlonkVerifierIndexRaw<'static> {
    of_ocaml(max_poly_size, max_quot_size, urs, evals, shifts)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_raw_of_ocaml(
    index: CamlTweedleFqPlonkVerifierIndexPtr,
) -> CamlTweedleFqPlonkVerifierIndexRaw<'static> {
    index.into()
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_ocaml_of_raw(
    index: CamlTweedleFqPlonkVerifierIndexRawPtr,
) -> CamlTweedleFqPlonkVerifierIndex {
    let index = index.as_ref();
    // We make a copy here because we can't move values out of the raw version.
    to_ocaml_copy(&index.1, &index.0)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_raw_create(
    mut index: CamlTweedleFqPlonkIndexPtr<'static>,
) -> CamlTweedleFqPlonkVerifierIndexRaw<'static> {
    let urs = Rc::clone(&index.as_ref().1);
    let verifier_index: DlogVerifierIndex<'static, GAffine> =
        // The underlying urs reference forces a lifetime borrow of `index`, but really
        // * we only need to borrow the urs
        // * we know statically that the urs will be live for the whole duration because of the
        //   refcounted references.
        // We prefer this to a pointer round-trip because we don't want to allocate memory when the
        // optimizer will otherwise see to place this straight in the OCaml heap.
        unsafe { std::mem::transmute(index.as_ref().0.verifier_index()) };
    CamlTweedleFqPlonkVerifierIndexRaw(verifier_index, urs)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_verifier_index_create(
    index: CamlTweedleFqPlonkIndexPtr<'static>,
) -> CamlTweedleFqPlonkVerifierIndex {
    let index = index.as_ref();
    to_ocaml(&index.1, index.0.verifier_index())
}
