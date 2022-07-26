use ark_poly::UVPolynomial;
use ark_poly::{univariate::DensePolynomial, EvaluationDomain, Evaluations};
use commitment_dlog::{
    commitment::{b_poly_coefficients, caml::CamlPolyComm},
    srs::{endos, SRS},
};
use paste::paste;
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

macro_rules! impl_srs {
    ($name: ident, $CamlF: ty, $CamlG: ty, $F: ty, $G: ty) => {

        impl_shared_reference!($name => SRS<$G>);

        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _create>](depth: ocaml::Int) -> $name {
                $name::new(SRS::create(depth as usize))
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _write>](
                append: Option<bool>,
                srs: $name,
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

                srs.0.serialize(&mut rmp_serde::Serializer::new(file))
                .map_err(|e| e.into())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _read>](
                offset: Option<ocaml::Int>,
                path: String,
            ) -> Result<Option<$name>, ocaml::Error> {
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
                let mut srs = match SRS::<$G>::deserialize(&mut rmp_serde::Deserializer::new(reader)) {
                    Ok(srs) => srs,
                    Err(_) => return Ok(None),
                };

                let (endo_q, endo_r) = endos::<$G>();
                srs.endo_q = endo_q;
                srs.endo_r = endo_r;

                Ok(Some($name::new(srs)))
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _lagrange_commitment>](
                srs: $name,
                domain_size: ocaml::Int,
                i: ocaml::Int,
            ) -> Result<CamlPolyComm<$CamlG>, ocaml::Error> {
                let x_domain = EvaluationDomain::<$F>::new(domain_size as usize).ok_or_else(|| {
                    ocaml::Error::invalid_argument("CamlSRS::lagrange_commitment")
                        .err()
                        .unwrap()
                })?;

                let evals = (0..domain_size)
                    .map(|j| if i == j { <$F as ark_ff::One>::one() } else { <$F as ark_ff::Zero>::zero() })
                    .collect();
                let p = Evaluations::<$F>::from_vec_and_domain(evals, x_domain).interpolate();
                Ok(srs.commit_non_hiding(&p, None).into())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _add_lagrange_basis>](
                srs: $name,
                log2_size: ocaml::Int,
            ) {
                let ptr: &mut commitment_dlog::srs::SRS<GAffine> =
                    unsafe { &mut *(std::sync::Arc::as_ptr(&srs) as *mut _) };
                let domain = EvaluationDomain::<$F>::new(1 << (log2_size as usize)).expect("invalid domain size");
                ptr.add_lagrange_basis(domain);
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _commit_evaluations>](
                srs: $name,
                domain_size: ocaml::Int,
                evals: Vec<$CamlF>,
            ) -> Result<CamlPolyComm<$CamlG>, ocaml::Error> {
                    let x_domain = EvaluationDomain::<$F>::new(domain_size as usize).ok_or_else(|| {
                        ocaml::Error::invalid_argument("CamlSRS::evaluations")
                            .err()
                            .unwrap()
                    })?;

                let evals = evals.into_iter().map(Into::into).collect();
                let p = Evaluations::<$F>::from_vec_and_domain(evals, x_domain).interpolate();

                Ok(srs.commit_non_hiding(&p, None).into())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _b_poly_commitment>](
                srs: $name,
                chals: Vec<$CamlF>,
            ) -> Result<CamlPolyComm<$CamlG>, ocaml::Error> {
                let chals: Vec<$F> = chals.into_iter().map(Into::into).collect();
                let coeffs = b_poly_coefficients(&chals);
                let p = DensePolynomial::<$F>::from_coefficients_vec(coeffs);

                Ok(srs.commit_non_hiding(&p, None).into())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _batch_accumulator_check>](
                srs: $name,
                comms: Vec<$CamlG>,
                chals: Vec<$CamlF>,
            ) -> bool {
                let comms: Vec<_> = comms.into_iter().map(Into::into).collect();
                let chals: Vec<_> = chals.into_iter().map(Into::into).collect();
                crate::urs_utils::batch_dlog_accumulator_check(&srs, &comms, &chals)
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _batch_accumulator_generate>](
                srs: $name,
                comms: ocaml::Int,
                chals: Vec<$CamlF>,
            ) -> Vec<$CamlG> {
                crate::urs_utils::batch_dlog_accumulator_generate::<$G>(
                    &srs,
                    comms as usize,
                    &chals.into_iter().map(From::from).collect(),
                ).into_iter().map(Into::into).collect()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _h>](srs: $name) -> $CamlG {
                srs.h.into()
            }
        }
    }
}

//
// Fp
//

pub mod fp {
    use super::*;
    use crate::arkworks::{CamlFp, CamlGVesta};
    use mina_curves::pasta::{fp::Fp, vesta::Affine as GAffine};

    impl_srs!(CamlFpSrs, CamlFp, CamlGVesta, Fp, GAffine);
}

pub mod fq {
    use super::*;
    use crate::arkworks::{CamlFq, CamlGPallas};
    use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine};

    impl_srs!(CamlFqSrs, CamlFq, CamlGPallas, Fq, GAffine);
}
