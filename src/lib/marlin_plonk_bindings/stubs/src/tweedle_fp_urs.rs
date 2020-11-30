use crate::tweedle_dee::{CamlTweedleDeeAffine, CamlTweedleDeePolyComm};
use algebra::{
    tweedle::{dee::Affine as GAffine, fp::Fp, fq::Fq},
    One, Zero,
};
use ff_fft::{DensePolynomial, EvaluationDomain, Evaluations};

use commitment_dlog::{commitment::b_poly_coefficients, srs::SRS};

use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
    rc::Rc,
};

pub struct CamlTweedleFpUrs(pub Rc<SRS<GAffine>>);

/* Note: The SRS is stored in the rust heap, OCaml only holds the refcounted reference to it.  */

extern "C" fn caml_tweedle_fp_urs_finalize(v: ocaml::Value) {
    let v: ocaml::Pointer<CamlTweedleFpUrs> = ocaml::FromValue::from_value(v);
    unsafe { v.drop_in_place() };
}

extern "C" fn caml_tweedle_fp_urs_compare(_v1: ocaml::Value, _v2: ocaml::Value) -> i32 {
    // This shouldn't be used, and has no value anyway since urs is opaque to ocaml, but we want it
    // for the OCaml <-> Rust transport consistency tests.
    return 0
}

ocaml::custom!(CamlTweedleFpUrs {
    compare: caml_tweedle_fp_urs_compare,
    finalize: caml_tweedle_fp_urs_finalize,
});

unsafe impl ocaml::FromValue for CamlTweedleFpUrs {
    fn from_value(value: ocaml::Value) -> CamlTweedleFpUrs {
        let ptr: ocaml::Pointer<CamlTweedleFpUrs> = ocaml::FromValue::from_value(value);
        // Create a new clone of the reference-counted pointer, to ensure that the boxed SRS will
        // live at least as long as both the OCaml value *and* this current copy of the value.
        CamlTweedleFpUrs(Rc::clone(&ptr.as_ref().0))
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_create(depth: ocaml::Int) -> CamlTweedleFpUrs {
    CamlTweedleFpUrs(Rc::new(SRS::create(depth as usize)))
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_write(
    append: Option<bool>,
    urs: CamlTweedleFpUrs,
    path: String,
) -> Result<(), ocaml::Error> {
    match OpenOptions::new().append(append.unwrap_or(true)).open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_tweedle_fp_urs_write")
            .err()
            .unwrap()),
        Ok(file) => {
            let file = BufWriter::new(file);
            let urs: &SRS<GAffine> = &urs.0;
            let _ = (*urs).write(file);
            Ok(())
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_read(
    offset: Option<ocaml::Int>,
    path: String,
) -> Result<Option<CamlTweedleFpUrs>, ocaml::Error> {
    match File::open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_tweedle_fp_urs_read")
            .err()
            .unwrap()),
        Ok(file) => {
            let mut file = BufReader::new(file);
            match offset {
                Some(offset) => {
                    file.seek(Start(offset as u64))?;
                }
                None => (),
            };
            match SRS::<GAffine>::read(file) {
                Err(_) => Ok(None),
                Ok(urs) => Ok(Some(CamlTweedleFpUrs(Rc::new(urs)))),
            }
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_lagrange_commitment(
    urs: CamlTweedleFpUrs,
    domain_size: ocaml::Int,
    i: ocaml::Int,
) -> Result<CamlTweedleDeePolyComm<Fq>, ocaml::Error> {
    match EvaluationDomain::<Fp>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fp_urs_lagrange_commitment")
                .err()
                .unwrap(),
        ),
        Some(x_domain) => {
            let evals = (0..domain_size)
                .map(|j| if i == j { Fp::one() } else { Fp::zero() })
                .collect();
            let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
            Ok(urs.0.commit_non_hiding(&p, None).into())
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_commit_evaluations(
    urs: CamlTweedleFpUrs,
    domain_size: ocaml::Int,
    evals: Vec<Fp>,
) -> Result<CamlTweedleDeePolyComm<Fq>, ocaml::Error> {
    match EvaluationDomain::<Fp>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fp_urs_commit_evaluations")
                .err()
                .unwrap(),
        ),
        Some(x_domain) => {
            let evals = evals.into_iter().map(From::from).collect();
            let p = Evaluations::<Fp>::from_vec_and_domain(evals, x_domain).interpolate();
            Ok(urs.0.commit_non_hiding(&p, None).into())
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_b_poly_commitment(
    urs: CamlTweedleFpUrs,
    chals: Vec<Fp>,
) -> Result<CamlTweedleDeePolyComm<Fq>, ocaml::Error> {
    let chals: Vec<Fp> = chals.into_iter().map(From::from).collect();
    let coeffs = b_poly_coefficients(&chals);
    let p = DensePolynomial::<Fp>::from_coefficients_vec(coeffs);
    Ok(urs.0.commit_non_hiding(&p, None).into())
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_batch_accumulator_check(
    urs: CamlTweedleFpUrs,
    comms: Vec<CamlTweedleDeeAffine<Fq>>,
    chals: Vec<Fp>,
) -> bool {
    crate::urs_utils::batch_dlog_accumulator_check(
        &urs.0,
        &comms.into_iter().map(From::from).collect(),
        &chals.into_iter().map(From::from).collect(),
    )
}

#[ocaml::func]
pub fn caml_tweedle_fp_urs_h(urs: CamlTweedleFpUrs) -> CamlTweedleDeeAffine<Fq> {
    urs.0.h.into()
}
