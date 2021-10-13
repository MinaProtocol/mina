use wasm_bindgen::prelude::*;
use wasm_bindgen::JsValue;
use mina_curves::pasta::{vesta::Affine as GAffine, fp::Fp};
use algebra::{One, Zero};
use ff_fft::{DensePolynomial, EvaluationDomain, Evaluations};

use commitment_dlog::{
    commitment::{b_poly_coefficients},
    srs::SRS,
};

use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
    rc::Rc,
};
use std::ops::Deref;
use std::convert::{Into, From};
use crate::pasta_fp::WasmPastaFp;
use crate::pasta_vesta::WasmVestaGAffine;
use crate::wasm_vector::WasmVector;
use crate::wasm_flat_vector::WasmFlatVector;
use crate::pasta_vesta_poly_comm::WasmPastaVestaPolyComm;

#[wasm_bindgen]
#[derive(Clone)]
pub struct WasmPastaFpUrs(Rc<SRS<GAffine>>);

impl Deref for WasmPastaFpUrs {
    type Target = Rc<SRS<GAffine>>;

    fn deref(&self) -> &Self::Target { &self.0 }
}

impl From<Rc<SRS<GAffine>>> for WasmPastaFpUrs {
    fn from(x: Rc<SRS<GAffine>>) -> Self {
        WasmPastaFpUrs(x)
    }
}

impl From<&Rc<SRS<GAffine>>> for WasmPastaFpUrs {
    fn from(x: &Rc<SRS<GAffine>>) -> Self {
        WasmPastaFpUrs(x.clone())
    }
}

impl From<WasmPastaFpUrs> for Rc<SRS<GAffine>> {
    fn from(x: WasmPastaFpUrs) -> Self {
        x.0
    }
}

impl From<&WasmPastaFpUrs> for Rc<SRS<GAffine>> {
    fn from(x: &WasmPastaFpUrs) -> Self {
        x.0.clone()
    }
}

impl<'a> From<&'a WasmPastaFpUrs> for &'a Rc<SRS<GAffine>> {
    fn from(x: &'a WasmPastaFpUrs) -> Self {
        &x.0
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_create(depth: i32) -> WasmPastaFpUrs {
    Rc::new(SRS::create(depth as usize)).into()
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_write(
    append: Option<bool>,
    urs: &WasmPastaFpUrs,
    path: String,
) -> Result<(), JsValue> {
    match OpenOptions::new().append(append.unwrap_or(true)).open(path) {
        Err(err) => Err(JsValue::from_str(format!("caml_pasta_fp_urs_write: {}", err).as_str())),
        Ok(file) => {
            let file = BufWriter::new(file);
            let urs: &SRS<GAffine> = &*urs;
            let _ = (*urs).write(file);
            Ok(())
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_read(
    offset: Option<i32>,
    path: String,
) -> Result<Option<WasmPastaFpUrs>, JsValue> {
    match File::open(path) {
        Err(err) => Err(JsValue::from_str(format!("caml_pasta_fp_urs_read: {}", err).as_str())),
        Ok(file) => {
            let mut file = BufReader::new(file);
            match offset {
                Some(offset) => {
                    file.seek(Start(offset as u64)).map_err(|err| JsValue::from_str(format!("caml_pasta_fp_urs_read: {}", err).as_str()))?;
                }
                None => (),
            };
            match SRS::<GAffine>::read(file) {
                Err(_) => Ok(None),
                Ok(urs) => Ok(Some(Rc::new(urs).into())),
            }
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_lagrange_commitment(
    urs: &WasmPastaFpUrs,
    domain_size: i32,
    i: i32,
) -> Result<WasmPastaVestaPolyComm, JsValue> {
    match EvaluationDomain::<Fp>::new(domain_size as usize) {
        None => Err(JsValue::from_str("caml_pasta_fp_urs_lagrange_commitment")),
        Some(x_domain) => {
            let evals = (0..domain_size)
                .map(|j| if i == j { Fp::one() } else { Fp::zero() })
                .collect();
            let log2_size = (domain_size as u32).trailing_zeros() as usize;
            let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
            Ok((*urs).trim(log2_size).commit_non_hiding(&p, None).into())
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_commit_evaluations(
    urs: &WasmPastaFpUrs,
    domain_size: i32,
    evals: WasmFlatVector<WasmPastaFp>,
) -> Result<WasmPastaVestaPolyComm, JsValue> {
    match EvaluationDomain::<Fp>::new(domain_size as usize) {
        None => Err(JsValue::from_str("caml_pasta_fp_urs_commit_evaluations")),
        Some(x_domain) => {
            let evals = Into::<Vec<WasmPastaFp>>::into(evals).into_iter().map(|x| x.0).collect();
            let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
            let log2_size = (domain_size as u32).trailing_zeros() as usize;
            Ok((*urs).trim(log2_size).commit_non_hiding(&p, None).into())
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_b_poly_commitment(
    urs: &WasmPastaFpUrs,
    chals: WasmFlatVector<WasmPastaFp>,
) -> Result<WasmPastaVestaPolyComm, JsValue> {
    let chals: Vec<Fp> = Into::<Vec<WasmPastaFp>>::into(chals).into_iter().map(|x| x.0).collect();
    let coeffs = b_poly_coefficients(&chals);
    let p = DensePolynomial::<Fp>::from_coefficients_vec(coeffs);
    let log2_size = chals.len();
    Ok((*urs).trim(log2_size).commit_non_hiding(&p, None).into())
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_batch_accumulator_check(
    urs: &WasmPastaFpUrs,
    comms: WasmVector<WasmVestaGAffine>,
    chals: WasmFlatVector<WasmPastaFp>,
) -> Result<bool, JsValue> {
    crate::urs_utils::batch_dlog_accumulator_check(
        &*urs,
        &Into::<Vec<WasmVestaGAffine>>::into(comms).into_iter().map(From::from).collect(),
        &Into::<Vec<WasmPastaFp>>::into(chals).into_iter().map(|x| x.0).collect(),
    )
}

#[wasm_bindgen]
pub fn caml_pasta_fp_urs_h(urs: &WasmPastaFpUrs) -> WasmVestaGAffine {
    (*urs).h.into()
}
