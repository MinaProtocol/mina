use crate::pasta_pallas::{CamlPastaPallasAffine, CamlPastaPallasPolyComm};
use crate::pasta_fp::CamlPastaFp;
use crate::pasta_fq::CamlPastaFq;
use algebra::{
    pasta::{pallas::Affine as GAffine, fq::Fq},
    One, Zero,
};
use ff_fft::{DensePolynomial, EvaluationDomain, Evaluations};

use commitment_dlog::{commitment::b_poly_coefficients, srs::SRS};

use std::{
    fs::File,
    io::{BufReader, BufWriter},
    rc::Rc,
};

pub struct CamlPastaFqUrs(pub Rc<SRS<GAffine>>);

/* Note: The SRS is stored in the rust heap, OCaml only holds the refcounted reference to it.  */

extern "C" fn caml_pasta_fq_urs_finalize(v: ocaml::Value) {
    let v: ocaml::Pointer<CamlPastaFqUrs> = ocaml::FromValue::from_value(v);
    unsafe { v.drop_in_place() };
}

ocaml::custom!(CamlPastaFqUrs {
    finalize: caml_pasta_fq_urs_finalize,
});

unsafe impl ocaml::FromValue for CamlPastaFqUrs {
    fn from_value(value: ocaml::Value) -> CamlPastaFqUrs {
        let ptr: ocaml::Pointer<CamlPastaFqUrs> = ocaml::FromValue::from_value(value);
        // Create a new clone of the reference-counted pointer, to ensure that the boxed SRS will
        // live at least as long as both the OCaml value *and* this current copy of the value.
        CamlPastaFqUrs(Rc::clone(&ptr.as_ref().0))
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_urs_create(depth: ocaml::Int) -> CamlPastaFqUrs {
    CamlPastaFqUrs(Rc::new(SRS::create(depth as usize)))
}

#[ocaml::func]
pub fn caml_pasta_fq_urs_write(urs: CamlPastaFqUrs, path: String) -> Result<(), ocaml::Error> {
    match File::create(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_pasta_fq_urs_write")
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
pub fn caml_pasta_fq_urs_read(path: String) -> Result<Option<CamlPastaFqUrs>, ocaml::Error> {
    match File::open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_pasta_fq_urs_read")
            .err()
            .unwrap()),
        Ok(file) => {
            let file = BufReader::new(file);
            match SRS::<GAffine>::read(file) {
                Err(_) => Ok(None),
                Ok(urs) => Ok(Some(CamlPastaFqUrs(Rc::new(urs)))),
            }
        }
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_urs_lagrange_commitment(
    urs: CamlPastaFqUrs,
    domain_size: ocaml::Int,
    i: ocaml::Int,
) -> Result<CamlPastaPallasPolyComm<CamlPastaFp>, ocaml::Error> {
    match EvaluationDomain::<Fq>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_pasta_fq_urs_lagrange_commitment")
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
pub fn caml_pasta_fq_urs_commit_evaluations(
    urs: CamlPastaFqUrs,
    domain_size: ocaml::Int,
    evals: Vec<CamlPastaFq>,
) -> Result<CamlPastaPallasPolyComm<CamlPastaFp>, ocaml::Error> {
    match EvaluationDomain::<Fq>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_pasta_fq_urs_commit_evaluations")
                .err()
                .unwrap(),
        ),
        Some(x_domain) => {
            let evals = evals.into_iter().map(From::from).collect();
            let p = Evaluations::<Fq>::from_vec_and_domain(evals, x_domain).interpolate();
            Ok(urs.0.commit_non_hiding(&p, None).into())
        }
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_urs_b_poly_commitment(
    urs: CamlPastaFqUrs,
    chals: Vec<CamlPastaFq>,
) -> Result<CamlPastaPallasPolyComm<CamlPastaFp>, ocaml::Error> {
    let chals: Vec<Fq> = chals.into_iter().map(From::from).collect();
    let coeffs = b_poly_coefficients(&chals);
    let p = DensePolynomial::<Fq>::from_coefficients_vec(coeffs);
    Ok(urs.0.commit_non_hiding(&p, None).into())
}

#[ocaml::func]
pub fn caml_pasta_fq_urs_batch_accumulator_check(
    urs: CamlPastaFqUrs,
    comms: Vec<CamlPastaPallasAffine<CamlPastaFp>>,
    chals: Vec<CamlPastaFq>,
) -> bool {
    crate::urs_utils::batch_dlog_accumulator_check(
        &urs.0,
        &comms.into_iter().map(From::from).collect(),
        &chals.into_iter().map(From::from).collect(),
    )
}

#[ocaml::func]
pub fn caml_pasta_fq_urs_h(urs: CamlPastaFqUrs) -> CamlPastaPallasAffine<CamlPastaFp> {
    urs.0.h.into()
}
