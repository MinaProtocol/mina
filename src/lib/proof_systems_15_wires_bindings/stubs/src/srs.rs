use crate::caml_pointer::CamlPointer;
use ark_ec::AffineCurve;
use ark_ff::{FftField, PrimeField};
use ark_poly::UVPolynomial;
use ark_poly::{univariate::DensePolynomial, EvaluationDomain, Evaluations};
use commitment_dlog::{
    commitment::{b_poly_coefficients, caml::CamlPolyComm, CommitmentCurve},
    srs::{endos, SRS},
    CommitmentField,
};

use ocaml_gen::ocaml_gen;
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
    marker::PhantomData,
};

/// CamlSRS lists generic functions, which we instantiate later with both curves
pub struct CamlSRS<F, CamlF, G, CamlG>(
    PhantomData<F>,
    PhantomData<CamlF>,
    PhantomData<G>,
    PhantomData<CamlG>,
);

impl<F, CamlF, G, CamlG> CamlSRS<F, CamlF, G, CamlG>
where
    F: FftField + From<CamlF>,
    CamlF: From<F>,
    G: CommitmentCurve + AffineCurve<ScalarField = F> + From<CamlG>,
    G::BaseField: PrimeField,
    G::ScalarField: CommitmentField,
    CamlG: From<G>,
{
    pub fn create(depth: ocaml::Int) -> CamlPointer<SRS<G>> {
        CamlPointer::new(SRS::<G>::create(depth as usize))
    }

    pub fn write(
        append: Option<bool>,
        srs: CamlPointer<SRS<G>>,
        path: String,
    ) -> Result<(), ocaml::Error> {
        let file = OpenOptions::new()
            .append(append.unwrap_or(true))
            .open(path)
            .map_err(|_| {
                ocaml::Error::invalid_argument("CamlSRS::write")
                    .err()
                    .unwrap()
            })?;
        let file = BufWriter::new(file);

        bincode::serialize_into(file, &*srs.0).map_err(|e| e.into())
    }

    pub fn read(
        offset: Option<ocaml::Int>,
        path: String,
    ) -> Result<Option<CamlPointer<SRS<G>>>, ocaml::Error> {
        let file = File::open(path).map_err(|_| {
            ocaml::Error::invalid_argument("CamlSRS::read")
                .err()
                .unwrap()
        })?;
        let mut reader = BufReader::new(file);

        if let Some(offset) = offset {
            reader.seek(Start(offset as u64))?;
        }

        // TODO: shouldn't we just error instead of returning None?
        let mut srs: SRS<G> = match bincode::deserialize_from(reader) {
            Ok(srs) => srs,
            Err(_) => return Ok(None),
        };
        let (endo_q, endo_r) = endos::<G>();
        srs.endo_q = endo_q;
        srs.endo_r = endo_r;

        Ok(Some(CamlPointer::new(srs)))
    }

    pub fn lagrange_commitment(
        srs: CamlPointer<SRS<G>>,
        domain_size: ocaml::Int,
        i: ocaml::Int,
    ) -> Result<CamlPolyComm<CamlG>, ocaml::Error> {
        let x_domain = EvaluationDomain::<F>::new(domain_size as usize).ok_or_else(|| {
            ocaml::Error::invalid_argument("CamlSRS::lagrange_commitment")
                .err()
                .unwrap()
        })?;

        let evals = (0..domain_size)
            .map(|j| if i == j { F::one() } else { F::zero() })
            .collect();
        let p = Evaluations::<F>::from_vec_and_domain(evals, x_domain).interpolate();
        Ok((*srs).commit_non_hiding(&p, None).into())
    }

    pub fn commit_evaluations(
        srs: CamlPointer<SRS<G>>,
        domain_size: ocaml::Int,
        evals: Vec<CamlF>,
    ) -> Result<CamlPolyComm<CamlG>, ocaml::Error> {
        let x_domain = EvaluationDomain::<F>::new(domain_size as usize).ok_or_else(|| {
            ocaml::Error::invalid_argument("CamlSRS::evaluations")
                .err()
                .unwrap()
        })?;

        let evals = evals.into_iter().map(Into::into).collect();
        let p = Evaluations::<F>::from_vec_and_domain(evals, x_domain).interpolate();
        Ok((*srs).commit_non_hiding(&p, None).into())
    }

    pub fn b_poly_commitment(
        srs: CamlPointer<SRS<G>>,
        chals: Vec<CamlF>,
    ) -> Result<CamlPolyComm<CamlG>, ocaml::Error> {
        let chals: Vec<F> = chals.into_iter().map(Into::into).collect();
        let coeffs = b_poly_coefficients(&chals);
        let p = DensePolynomial::<F>::from_coefficients_vec(coeffs);
        Ok((*srs).commit_non_hiding(&p, None).into())
    }

    pub fn batch_accumulator_check(
        srs: CamlPointer<SRS<G>>,
        comms: Vec<CamlG>,
        chals: Vec<CamlF>,
    ) -> bool {
        crate::urs_utils::batch_dlog_accumulator_check(
            &*srs,
            &comms.into_iter().map(Into::into).collect(),
            &chals.into_iter().map(Into::into).collect(),
        )
    }

    pub fn urs_h(srs: CamlPointer<SRS<G>>) -> CamlG {
        (*srs).h.into()
    }
}

//
// Fp
//

pub mod fp {
    use super::*;

    use crate::arkworks::{CamlFp, CamlGVesta};
    use mina_curves::pasta::{fp::Fp, vesta::Affine as GAffine};

    pub type CamlFpSRS = CamlPointer<SRS<GAffine>>;

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_create(depth: ocaml::Int) -> CamlFpSRS {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::create(depth)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_write(
        append: Option<bool>,
        srs: CamlFpSRS,
        path: String,
    ) -> Result<(), ocaml::Error> {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::write(append, srs, path)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_read(
        offset: Option<ocaml::Int>,
        path: String,
    ) -> Result<Option<CamlFpSRS>, ocaml::Error> {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::read(offset, path)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_lagrange_commitment(
        srs: CamlFpSRS,
        domain_size: ocaml::Int,
        i: ocaml::Int,
    ) -> Result<CamlPolyComm<CamlGVesta>, ocaml::Error> {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::lagrange_commitment(srs, domain_size, i)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_commit_evaluations(
        srs: CamlFpSRS,
        domain_size: ocaml::Int,
        evals: Vec<CamlFp>,
    ) -> Result<CamlPolyComm<CamlGVesta>, ocaml::Error> {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::commit_evaluations(srs, domain_size, evals)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_b_poly_commitment(
        srs: CamlFpSRS,
        chals: Vec<CamlFp>,
    ) -> Result<CamlPolyComm<CamlGVesta>, ocaml::Error> {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::b_poly_commitment(srs, chals)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_batch_accumulator_check(
        srs: CamlFpSRS,
        comms: Vec<CamlGVesta>,
        chals: Vec<CamlFp>,
    ) -> bool {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::batch_accumulator_check(srs, comms, chals)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fp_urs_h(srs: CamlFpSRS) -> CamlGVesta {
        CamlSRS::<Fp, CamlFp, GAffine, CamlGVesta>::urs_h(srs)
    }
}

pub mod fq {
    use super::*;

    use crate::arkworks::{CamlFq, CamlGPallas};
    use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine};

    //
    // CamlFqSRS
    //

    pub type CamlFqSRS = CamlPointer<SRS<GAffine>>;

    //
    // CamlFqSRS implementations
    //

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_create(depth: ocaml::Int) -> CamlFqSRS {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::create(depth)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_write(
        append: Option<bool>,
        srs: CamlFqSRS,
        path: String,
    ) -> Result<(), ocaml::Error> {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::write(append, srs, path)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_read(
        offset: Option<ocaml::Int>,
        path: String,
    ) -> Result<Option<CamlFqSRS>, ocaml::Error> {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::read(offset, path)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_lagrange_commitment(
        srs: CamlFqSRS,
        domain_size: ocaml::Int,
        i: ocaml::Int,
    ) -> Result<CamlPolyComm<CamlGPallas>, ocaml::Error> {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::lagrange_commitment(srs, domain_size, i)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_commit_evaluations(
        srs: CamlFqSRS,
        domain_size: ocaml::Int,
        evals: Vec<CamlFq>,
    ) -> Result<CamlPolyComm<CamlGPallas>, ocaml::Error> {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::commit_evaluations(srs, domain_size, evals)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_b_poly_commitment(
        srs: CamlFqSRS,
        chals: Vec<CamlFq>,
    ) -> Result<CamlPolyComm<CamlGPallas>, ocaml::Error> {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::b_poly_commitment(srs, chals)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_batch_accumulator_check(
        srs: CamlFqSRS,
        comms: Vec<CamlGPallas>,
        chals: Vec<CamlFq>,
    ) -> bool {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::batch_accumulator_check(srs, comms, chals)
    }

    #[ocaml_gen]
    #[ocaml::func]
    pub fn caml_pasta_fq_urs_h(srs: CamlFqSRS) -> CamlGPallas {
        CamlSRS::<Fq, CamlFq, GAffine, CamlGPallas>::urs_h(srs)
    }
}
