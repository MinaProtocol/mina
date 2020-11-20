use crate::pasta_vesta::{CamlPastaVestaAffine, CamlPastaVestaPolyComm};
use crate::pasta_fp::CamlPastaFp;
use crate::pasta_fq::CamlPastaFq;
use algebra::{
    pasta::{vesta::Affine as GAffine, fp::Fp},
    One, Zero,
};
use ff_fft::{DensePolynomial, EvaluationDomain, Evaluations};

use commitment_dlog::{commitment::b_poly_coefficients, srs::SRS};

use std::{
    fs::File,
    io::{BufReader, BufWriter},
    rc::Rc,
};

pub struct CamlPastaFpUrs(pub Rc<SRS<GAffine>>);

/* Note: The SRS is stored in the rust heap, OCaml only holds the refcounted reference to it.  */

extern "C" fn caml_pasta_fp_urs_finalize(v: ocaml::Value) {
    let v: ocaml::Pointer<CamlPastaFpUrs> = ocaml::FromValue::from_value(v);
    unsafe { v.drop_in_place() };
}

ocaml::custom!(CamlPastaFpUrs {
    finalize: caml_pasta_fp_urs_finalize,
});

unsafe impl ocaml::FromValue for CamlPastaFpUrs {
    fn from_value(value: ocaml::Value) -> CamlPastaFpUrs {
        let ptr: ocaml::Pointer<CamlPastaFpUrs> = ocaml::FromValue::from_value(value);
        // Create a new clone of the reference-counted pointer, to ensure that the boxed SRS will
        // live at least as long as both the OCaml value *and* this current copy of the value.
        CamlPastaFpUrs(Rc::clone(&ptr.as_ref().0))
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_urs_create(depth: ocaml::Int) -> CamlPastaFpUrs {
    CamlPastaFpUrs(Rc::new(SRS::create(depth as usize)))
}

#[ocaml::func]
pub fn caml_pasta_fp_urs_write(urs: CamlPastaFpUrs, path: String) -> Result<(), ocaml::Error> {
    match File::create(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_pasta_fp_urs_write")
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
pub fn caml_pasta_fp_urs_read(path: String) -> Result<Option<CamlPastaFpUrs>, ocaml::Error> {
    match File::open(path) {
        Err(_) => Err(ocaml::Error::invalid_argument("caml_pasta_fp_urs_read")
            .err()
            .unwrap()),
        Ok(file) => {
            let file = BufReader::new(file);
            match SRS::<GAffine>::read(file) {
                Err(_) => Ok(None),
                Ok(urs) => Ok(Some(CamlPastaFpUrs(Rc::new(urs)))),
            }
        }
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_urs_lagrange_commitment(
    urs: CamlPastaFpUrs,
    domain_size: ocaml::Int,
    i: ocaml::Int,
) -> Result<CamlPastaVestaPolyComm<CamlPastaFq>, ocaml::Error> {
    match EvaluationDomain::<Fp>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_pasta_fp_urs_lagrange_commitment")
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
pub fn caml_pasta_fp_urs_commit_evaluations(
    urs: CamlPastaFpUrs,
    domain_size: ocaml::Int,
    evals: Vec<CamlPastaFp>,
) -> Result<CamlPastaVestaPolyComm<CamlPastaFq>, ocaml::Error> {
    match EvaluationDomain::<Fp>::new(domain_size as usize) {
        None => Err(
            ocaml::Error::invalid_argument("caml_pasta_fp_urs_commit_evaluations")
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
pub fn caml_pasta_fp_urs_b_poly_commitment(
    urs: CamlPastaFpUrs,
    chals: Vec<CamlPastaFp>,
) -> Result<CamlPastaVestaPolyComm<CamlPastaFq>, ocaml::Error> {
    let chals: Vec<Fp> = chals.into_iter().map(From::from).collect();
    let coeffs = b_poly_coefficients(&chals);
    let p = DensePolynomial::<Fp>::from_coefficients_vec(coeffs);
    Ok(urs.0.commit_non_hiding(&p, None).into())
}

#[ocaml::func]
pub fn caml_pasta_fp_urs_batch_accumulator_check(
    urs: CamlPastaFpUrs,
    comms: Vec<CamlPastaVestaAffine<CamlPastaFq>>,
    chals: Vec<CamlPastaFp>,
) -> bool {
    crate::urs_utils::batch_dlog_accumulator_check(
        &urs.0,
        &comms.into_iter().map(From::from).collect(),
        &chals.into_iter().map(From::from).collect(),
    )
}

#[ocaml::func]
pub fn caml_pasta_fp_urs_h(urs: CamlPastaFpUrs) -> CamlPastaVestaAffine<CamlPastaFq> {
    urs.0.h.into()
}
