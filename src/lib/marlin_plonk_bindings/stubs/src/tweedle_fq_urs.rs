use crate::tweedle_dum::{
    CamlTweedleDumAffine, CamlTweedleDumAffineVector, CamlTweedleDumPolyComm,
};
use crate::tweedle_fp::CamlTweedleFp;
use crate::tweedle_fq::CamlTweedleFqPtr;
use algebra::{
    tweedle::{dum::Affine as GAffine, fq::Fq},
    One, Zero,
};
use ff_fft::{DensePolynomial, EvaluationDomain, Evaluations};

use commitment_dlog::{commitment::b_poly_coefficients, srs::SRS};

use std::{
    fs::File,
    io::{BufReader, BufWriter},
    rc::Rc,
};

pub struct CamlTweedleFqUrs(pub Rc<SRS<GAffine>>);

/* Note: The SRS is stored in the rust heap, OCaml only holds the refcounted reference to it.  */

extern "C" fn caml_tweedle_fq_urs_finalize(v: ocaml::Value) {
    let v: ocaml::Pointer<CamlTweedleFqUrs> = ocaml::FromValue::from_value(v);
    unsafe { v.drop_in_place() };
}

ocaml::custom!(CamlTweedleFqUrs {
    finalize: caml_tweedle_fq_urs_finalize,
});

unsafe impl ocaml::FromValue for CamlTweedleFqUrs {
    fn from_value(value: ocaml::Value) -> CamlTweedleFqUrs {
        let ptr: ocaml::Pointer<CamlTweedleFqUrs> = ocaml::FromValue::from_value(value);
        // Create a new clone of the reference-counted pointer, to ensure that the boxed SRS will
        // live at least as long as both the OCaml value *and* this current copy of the value.
        CamlTweedleFqUrs(Rc::clone(&ptr.as_ref().0))
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_urs_create(depth: ocaml::Int) -> CamlTweedleFqUrs {
    CamlTweedleFqUrs(Rc::new(SRS::create(depth as usize)))
}

#[ocaml::func]
pub fn caml_tweedle_fq_urs_write(urs: CamlTweedleFqUrs, path: String) -> Result<(), ocaml::Error> {
    match File::create(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_tweedle_fq_urs_write")
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
pub fn caml_tweedle_fq_urs_read(path: String) -> Result<Option<CamlTweedleFqUrs>, ocaml::Error> {
    match File::open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_tweedle_fq_urs_read")
            .err()
            .unwrap()),
        Ok(file) => {
            let file = BufReader::new(file);
            match SRS::<GAffine>::read(file) {
                Err(_) => Ok(None),
                Ok(urs) => Ok(Some(CamlTweedleFqUrs(Rc::new(urs)))),
            }
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_urs_lagrange_commitment(
    urs: CamlTweedleFqUrs,
    domain_size: ocaml::Int,
    i: ocaml::Int,
) -> Result<CamlTweedleDumPolyComm<CamlTweedleFp>, ocaml::Error> {
    match EvaluationDomain::<Fq>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fq_urs_lagrange_commitment")
                .err()
                .unwrap(),
        ),
        Some(x_domain) => {
            let evals = (0..domain_size)
                .map(|j| if i == j { Fq::one() } else { Fq::zero() })
                .collect();
            let p = Evaluations::<Fq>::from_vec_and_domain(evals, x_domain).interpolate();
            Ok(urs.0.commit_non_hiding(&p, None).into())
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_urs_commit_evaluations(
    urs: CamlTweedleFqUrs,
    domain_size: ocaml::Int,
    evals: ocaml::Array<CamlTweedleFqPtr>,
) -> Result<CamlTweedleDumPolyComm<CamlTweedleFp>, ocaml::Error> {
    match EvaluationDomain::<Fq>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fq_urs_commit_evaluations")
                .err()
                .unwrap(),
        ),
        Some(x_domain) => {
            let evals = {
                let len = evals.len();
                let mut v = Vec::with_capacity(len);
                for i in 0..len {
                    unsafe {
                        v.push(evals.get_unchecked(i).as_ref().0);
                    }
                }
                v
            };
            let p = Evaluations::<Fq>::from_vec_and_domain(evals, x_domain).interpolate();
            Ok(urs.0.commit_non_hiding(&p, None).into())
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_urs_b_poly_commitment(
    urs: CamlTweedleFqUrs,
    chals: ocaml::Array<CamlTweedleFqPtr>,
) -> Result<CamlTweedleDumPolyComm<CamlTweedleFp>, ocaml::Error> {
    let chals = {
        let len = chals.len();
        let mut v = Vec::with_capacity(len);
        for i in 0..len {
            unsafe {
                v.push(chals.get_unchecked(i).as_ref().0);
            }
        }
        v
    };
    let coeffs = b_poly_coefficients(&chals);
    let p = DensePolynomial::<Fq>::from_coefficients_vec(coeffs);
    Ok(urs.0.commit_non_hiding(&p, None).into())
}

#[ocaml::func]
pub fn caml_tweedle_fq_urs_batch_accumulator_check(
    urs: CamlTweedleFqUrs,
    comms: CamlTweedleDumAffineVector,
    chals: ocaml::Array<CamlTweedleFqPtr>,
) -> bool {
    let chals = {
        let len = chals.len();
        let mut v = Vec::with_capacity(len);
        for i in 0..len {
            unsafe {
                v.push(chals.get_unchecked(i).as_ref().0);
            }
        }
        v
    };
    crate::urs_utils::batch_dlog_accumulator_check(&urs.0, &comms.0, &chals)
}

#[ocaml::func]
pub fn caml_tweedle_fq_urs_h(urs: CamlTweedleFqUrs) -> CamlTweedleDumAffine<CamlTweedleFp> {
    urs.0.h.into()
}
