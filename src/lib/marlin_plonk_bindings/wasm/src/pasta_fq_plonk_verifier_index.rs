use wasm_bindgen::prelude::*;
use wasm_bindgen::JsValue;
use crate::index_serialization;
use crate::pasta_fq::WasmPastaFq;
use crate::pasta_fq_plonk_index::WasmPastaFqPlonkIndex;
use crate::pasta_fq_urs::WasmPastaFqUrs;
use crate::pasta_pallas_poly_comm::WasmPastaPallasPolyComm;
use mina_curves::pasta::{vesta::Affine as GAffineOther, pallas::Affine as GAffine, fq::Fq};
use algebra::{
    curves::AffineCurve,
    One,
};

use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};

use commitment_dlog::{commitment::PolyComm, srs::{SRS, SRSValue}};
use plonk_circuits::constraints::{zk_polynomial, zk_w, ConstraintSystem};
use plonk_protocol_dlog::index::{VerifierIndex as DlogVerifierIndex};

use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

use std::rc::Rc;

#[wasm_bindgen]
#[derive(Clone, Copy)]
pub struct WasmPastaFqPlonkDomain {
    pub log_size_of_group: i32,
    pub group_gen: WasmPastaFq,
}

#[wasm_bindgen]
impl WasmPastaFqPlonkDomain {
    #[wasm_bindgen(constructor)]
    pub fn new(log_size_of_group: i32, group_gen: WasmPastaFq) -> Self {
        WasmPastaFqPlonkDomain {log_size_of_group, group_gen}
    }
}

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaFqPlonkVerificationEvals {
    #[wasm_bindgen(skip)]
    pub sigma_comm0: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub sigma_comm1: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub sigma_comm2: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub ql_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub qr_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub qo_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub qm_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub qc_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub rcm_comm0: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub rcm_comm1: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub rcm_comm2: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub psm_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub add_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub mul1_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub mul2_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub emul1_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub emul2_comm: WasmPastaPallasPolyComm,
    #[wasm_bindgen(skip)]
    pub emul3_comm: WasmPastaPallasPolyComm,
}

#[wasm_bindgen]
impl WasmPastaFqPlonkVerificationEvals {
    #[wasm_bindgen(getter)]
    pub fn sigma_comm0(&self) -> WasmPastaPallasPolyComm {
        self.sigma_comm0.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sigma_comm1(&self) -> WasmPastaPallasPolyComm {
        self.sigma_comm1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn sigma_comm2(&self) -> WasmPastaPallasPolyComm {
        self.sigma_comm2.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn ql_comm(&self) -> WasmPastaPallasPolyComm {
        self.ql_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn qr_comm(&self) -> WasmPastaPallasPolyComm {
        self.qr_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn qo_comm(&self) -> WasmPastaPallasPolyComm {
        self.qo_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn qm_comm(&self) -> WasmPastaPallasPolyComm {
        self.qm_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn qc_comm(&self) -> WasmPastaPallasPolyComm {
        self.qc_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn rcm_comm0(&self) -> WasmPastaPallasPolyComm {
        self.rcm_comm0.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn rcm_comm1(&self) -> WasmPastaPallasPolyComm {
        self.rcm_comm1.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn rcm_comm2(&self) -> WasmPastaPallasPolyComm {
        self.rcm_comm2.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn psm_comm(&self) -> WasmPastaPallasPolyComm {
        self.psm_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn add_comm(&self) -> WasmPastaPallasPolyComm {
        self.add_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn mul1_comm(&self) -> WasmPastaPallasPolyComm {
        self.mul1_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn mul2_comm(&self) -> WasmPastaPallasPolyComm {
        self.mul2_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn emul1_comm(&self) -> WasmPastaPallasPolyComm {
        self.emul1_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn emul2_comm(&self) -> WasmPastaPallasPolyComm {
        self.emul2_comm.clone()
    }
    #[wasm_bindgen(getter)]
    pub fn emul3_comm(&self) -> WasmPastaPallasPolyComm {
        self.emul3_comm.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_sigma_comm0(&mut self, x: WasmPastaPallasPolyComm) {
        self.sigma_comm0 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_sigma_comm1(&mut self, x: WasmPastaPallasPolyComm) {
        self.sigma_comm1 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_sigma_comm2(&mut self, x: WasmPastaPallasPolyComm) {
        self.sigma_comm2 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_ql_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.ql_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_qr_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.qr_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_qo_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.qo_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_qm_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.qm_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_qc_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.qc_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_rcm_comm0(&mut self, x: WasmPastaPallasPolyComm) {
        self.rcm_comm0 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_rcm_comm1(&mut self, x: WasmPastaPallasPolyComm) {
        self.rcm_comm1 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_rcm_comm2(&mut self, x: WasmPastaPallasPolyComm) {
        self.rcm_comm2 = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_psm_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.psm_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_add_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.add_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_mul1_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.mul1_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_mul2_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.mul2_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_emul1_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.emul1_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_emul2_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.emul2_comm = x
    }
    #[wasm_bindgen(setter)]
    pub fn set_emul3_comm(&mut self, x: WasmPastaPallasPolyComm) {
        self.emul3_comm = x
    }

    #[wasm_bindgen(constructor)]
    pub fn new(
    sigma_comm0: &WasmPastaPallasPolyComm,
    sigma_comm1: &WasmPastaPallasPolyComm,
    sigma_comm2: &WasmPastaPallasPolyComm,
    ql_comm: &WasmPastaPallasPolyComm,
    qr_comm: &WasmPastaPallasPolyComm,
    qo_comm: &WasmPastaPallasPolyComm,
    qm_comm: &WasmPastaPallasPolyComm,
    qc_comm: &WasmPastaPallasPolyComm,
    rcm_comm0: &WasmPastaPallasPolyComm,
    rcm_comm1: &WasmPastaPallasPolyComm,
    rcm_comm2: &WasmPastaPallasPolyComm,
    psm_comm: &WasmPastaPallasPolyComm,
    add_comm: &WasmPastaPallasPolyComm,
    mul1_comm: &WasmPastaPallasPolyComm,
    mul2_comm: &WasmPastaPallasPolyComm,
    emul1_comm: &WasmPastaPallasPolyComm,
    emul2_comm: &WasmPastaPallasPolyComm,
    emul3_comm: &WasmPastaPallasPolyComm) -> Self {
        WasmPastaFqPlonkVerificationEvals {
            sigma_comm0: sigma_comm0.clone(),
            sigma_comm1: sigma_comm1.clone(),
            sigma_comm2: sigma_comm2.clone(),
            ql_comm: ql_comm.clone(),
            qr_comm: qr_comm.clone(),
            qo_comm: qo_comm.clone(),
            qm_comm: qm_comm.clone(),
            qc_comm: qc_comm.clone(),
            rcm_comm0: rcm_comm0.clone(),
            rcm_comm1: rcm_comm1.clone(),
            rcm_comm2: rcm_comm2.clone(),
            psm_comm: psm_comm.clone(),
            add_comm: add_comm.clone(),
            mul1_comm: mul1_comm.clone(),
            mul2_comm: mul2_comm.clone(),
            emul1_comm: emul1_comm.clone(),
            emul2_comm: emul2_comm.clone(),
            emul3_comm: emul3_comm.clone(),
        }
    }
}

#[wasm_bindgen]
#[derive(Clone, Copy)]
pub struct WasmPastaFqPlonkVerificationShifts {
    pub r: WasmPastaFq,
    pub o: WasmPastaFq,
}

#[wasm_bindgen]
impl WasmPastaFqPlonkVerificationShifts {
    #[wasm_bindgen(constructor)]
    pub fn new(r: WasmPastaFq, o: WasmPastaFq) -> Self {
        WasmPastaFqPlonkVerificationShifts {r, o}
    }
}

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaFqPlonkVerifierIndex {
    pub domain: WasmPastaFqPlonkDomain,
    pub max_poly_size: i32,
    pub max_quot_size: i32,
    #[wasm_bindgen(skip)]
    pub urs: WasmPastaFqUrs,
    #[wasm_bindgen(skip)]
    pub evals: WasmPastaFqPlonkVerificationEvals,
    pub shifts: WasmPastaFqPlonkVerificationShifts,
}

#[wasm_bindgen]
impl WasmPastaFqPlonkVerifierIndex {
    #[wasm_bindgen(constructor)]
    pub fn new(
        domain: &WasmPastaFqPlonkDomain,
        max_poly_size: i32,
        max_quot_size: i32,
        urs: &WasmPastaFqUrs,
        evals: &WasmPastaFqPlonkVerificationEvals,
        shifts: &WasmPastaFqPlonkVerificationShifts,
    ) -> Self {
        WasmPastaFqPlonkVerifierIndex {
            domain: domain.clone(),
            max_poly_size,
            max_quot_size,
            urs: urs.clone(),
            evals: evals.clone(),
            shifts: shifts.clone(),
        }
    }

    #[wasm_bindgen(getter)]
    pub fn urs(&self) -> WasmPastaFqUrs {
        self.urs.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_urs(&mut self, x: WasmPastaFqUrs) {
        self.urs = x
    }

    #[wasm_bindgen(getter)]
    pub fn evals(&self) -> WasmPastaFqPlonkVerificationEvals {
        self.evals.clone()
    }

    #[wasm_bindgen(setter)]
    pub fn set_evals(&mut self, x: WasmPastaFqPlonkVerificationEvals) {
        self.evals = x
    }
}

pub fn to_wasm<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: DlogVerifierIndex<'a, GAffine>,
) -> WasmPastaFqPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2] = vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2] = vi.rcm_comm;
    WasmPastaFqPlonkVerifierIndex {
        domain: WasmPastaFqPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as i32,
            group_gen: WasmPastaFq(vi.domain.group_gen),
        },
        max_poly_size: vi.max_poly_size as i32,
        max_quot_size: vi.max_quot_size as i32,
        urs: Rc::clone(urs).into(),
        evals: WasmPastaFqPlonkVerificationEvals {
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
        shifts: WasmPastaFqPlonkVerificationShifts { r: WasmPastaFq(vi.r), o: WasmPastaFq(vi.o) },
    }
}

pub fn to_wasm_copy<'a>(
    urs: &Rc<SRS<GAffine>>,
    vi: &DlogVerifierIndex<'a, GAffine>,
) -> WasmPastaFqPlonkVerifierIndex {
    let [sigma_comm0, sigma_comm1, sigma_comm2] = &vi.sigma_comm;
    let [rcm_comm0, rcm_comm1, rcm_comm2] = &vi.rcm_comm;
    WasmPastaFqPlonkVerifierIndex {
        domain: WasmPastaFqPlonkDomain {
            log_size_of_group: vi.domain.log_size_of_group as i32,
            group_gen: WasmPastaFq(vi.domain.group_gen),
        },
        max_poly_size: vi.max_poly_size as i32,
        max_quot_size: vi.max_quot_size as i32,
        urs: Rc::clone(urs).into(),
        evals: WasmPastaFqPlonkVerificationEvals {
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
        shifts: WasmPastaFqPlonkVerificationShifts { r: WasmPastaFq(vi.r), o: WasmPastaFq(vi.o) },
    }
}

pub fn of_wasm<'a>(
    max_poly_size: i32,
    max_quot_size: i32,
    log_size_of_group: i32,
    urs: &WasmPastaFqUrs,
    evals: &WasmPastaFqPlonkVerificationEvals,
    shifts: &WasmPastaFqPlonkVerificationShifts,
) -> (DlogVerifierIndex<'a, GAffine>, Rc<SRS<GAffine>>) {
    let urs_copy = Rc::clone(&*urs);
    let urs_copy_outer = Rc::clone(&*urs);
    let srs = {
        // We know that the underlying value is still alive, because we never convert any of our
        // Rc<_>s into weak pointers.
        SRSValue::Ref(unsafe { &*Rc::into_raw(urs_copy) })
    };
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
    let domain = Domain::<Fq>::new(1 << log_size_of_group).unwrap();
    let index = DlogVerifierIndex::<GAffine> {
        domain,
        w: zk_w(domain).unwrap(),
        zkpm: zk_polynomial(domain).unwrap(),
        max_poly_size: max_poly_size as usize,
        max_quot_size: max_quot_size as usize,
        srs,
        sigma_comm: [evals.sigma_comm0.clone().into(), evals.sigma_comm1.clone().into(), evals.sigma_comm2.clone().into()],
        ql_comm: evals.ql_comm.clone().into(),
        qr_comm: evals.qr_comm.clone().into(),
        qo_comm: evals.qo_comm.clone().into(),
        qm_comm: evals.qm_comm.clone().into(),
        qc_comm: evals.qc_comm.clone().into(),
        rcm_comm: [evals.rcm_comm0.clone().into(), evals.rcm_comm1.clone().into(), evals.rcm_comm2.clone().into()],
        psm_comm: evals.psm_comm.clone().into(),
        add_comm: evals.add_comm.clone().into(),
        mul1_comm: evals.mul1_comm.clone().into(),
        mul2_comm: evals.mul2_comm.clone().into(),
        emul1_comm: evals.emul1_comm.clone().into(),
        emul2_comm: evals.emul2_comm.clone().into(),
        emul3_comm: evals.emul3_comm.clone().into(),
        r: shifts.r.0,
        o: shifts.o.0,
        fr_sponge_params: oracle::pasta::fq::params(),
        fq_sponge_params: oracle::pasta::fp::params(),
        endo: endo_q,
    };
    (index, urs_copy_outer)
}

impl From<WasmPastaFqPlonkVerifierIndex> for DlogVerifierIndex<'_, GAffine> {
    fn from(index: WasmPastaFqPlonkVerifierIndex) -> Self {
        of_wasm(
            index.max_poly_size,
            index.max_quot_size,
            index.domain.log_size_of_group,
            &index.urs,
            &index.evals,
            &index.shifts,
        )
        .0
    }
}

pub fn read_raw<'a>(
    offset: Option<i32>,
    urs: &WasmPastaFqUrs,
    path: String,
) -> Result<(DlogVerifierIndex<'a, GAffine>, Rc<SRS<GAffine>>), std::io::Error> {
    match File::open(path) {
        Err(err) => Err(err),
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
                oracle::pasta::fq::params(),
                oracle::pasta::fp::params(),
                endo_q,
                Rc::into_raw(urs_copy2),
                &mut r,
            )?;
            Ok((t, Rc::clone(&urs_copy)))
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_verifier_index_read(
    offset: Option<i32>,
    urs: &WasmPastaFqUrs,
    path: String,
) -> Result<WasmPastaFqPlonkVerifierIndex, JsValue> {
    let (vi, urs) = read_raw(offset, urs, path).map_err(|err| {
    JsValue::from_str(format!("caml_pasta_fq_plonk_verifier_index_read: {}", err).as_str()) })?;
    Ok(to_wasm(&urs, vi))
}

pub fn write_raw(
    append: Option<bool>,
    index: &DlogVerifierIndex<GAffine>,
    path: String,
) -> Result<(), std::io::Error> {
    match OpenOptions::new().append(append.unwrap_or(true)).open(path) {
        Err(err) => Err(err),
        Ok(file) => {
            let mut w = BufWriter::new(file);

            Ok(index_serialization::write_plonk_verifier_index(
                index, &mut w,
            )?)
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_verifier_index_write(
    append: Option<bool>,
    index: &WasmPastaFqPlonkVerifierIndex,
    path: String,
) -> Result<(), JsValue> {
    write_raw(append, &index.clone().into(), path).map_err(|err| {
    JsValue::from_str(format!("caml_pasta_fq_plonk_verifier_index_write: {}", err).as_str()) })
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_verifier_index_create(
    index: &WasmPastaFqPlonkIndex,
) -> WasmPastaFqPlonkVerifierIndex {
    to_wasm(&index.1, index.0.verifier_index())
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_verifier_index_shifts(
    log2_size: i32,
) -> WasmPastaFqPlonkVerificationShifts {
    let (a, b) = ConstraintSystem::sample_shifts(&Domain::new(1 << log2_size).unwrap());
    WasmPastaFqPlonkVerificationShifts { r: WasmPastaFq(a), o: WasmPastaFq(b) }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_verifier_index_dummy() -> WasmPastaFqPlonkVerifierIndex {
    let g = || GAffine::prime_subgroup_generator();
    let comm = || Into::<WasmPastaPallasPolyComm>::into(PolyComm {
        shifted: Some(g()),
        unshifted: vec![g(), g(), g()],
    });
    WasmPastaFqPlonkVerifierIndex {
        domain: WasmPastaFqPlonkDomain {
            log_size_of_group: 1,
            group_gen: WasmPastaFq(Fq::one()),
        },
        max_poly_size: 0,
        max_quot_size: 0,
        urs: Rc::new(SRS::create(0)).into(),
        evals: WasmPastaFqPlonkVerificationEvals {
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
        shifts: WasmPastaFqPlonkVerificationShifts {
            r: WasmPastaFq(Fq::one()),
            o: WasmPastaFq(Fq::one()),
        },
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_verifier_index_deep_copy(
    x: &WasmPastaFqPlonkVerifierIndex,
) -> WasmPastaFqPlonkVerifierIndex {
    (*x).clone()
}
