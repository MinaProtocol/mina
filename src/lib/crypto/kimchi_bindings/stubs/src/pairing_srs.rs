use ark_bn254::Parameters;
use ark_ec::bn::Bn;
use ark_ff::UniformRand;
use ark_poly::UVPolynomial;
use ark_poly::{univariate::DensePolynomial, EvaluationDomain, Evaluations};
use paste::paste;
use poly_commitment::SRS as _;
use poly_commitment::{
    commitment::{b_poly_coefficients, caml::CamlPolyComm},
    pairing_proof::PairingSRS,
    srs::SRS,
};
use rand::{rngs::StdRng, SeedableRng};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

macro_rules! impl_srs {
    ($name: ident, $CamlF: ty, $CamlG: ty, $F: ty, $G: ty) => {

        impl_shared_reference!($name => PairingSRS<Bn<Parameters>>);

        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _create>](depth: ocaml::Int) -> $name {
                let rng = &mut StdRng::from_seed([0u8; 32]);
                let x = $F::rand(rng);

                $name::new(PairingSRS::create(x, depth as usize))
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
                let srs = match PairingSRS::<Bn<Parameters>>::deserialize(&mut rmp_serde::Deserializer::new(reader)) {
                    Ok(srs) => srs,
                    Err(_) => return Ok(None),
                };

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

                {
                    // We're single-threaded, so it's safe to grab this pointer as mutable.
                    // Do not try this at home.
                    let full_srs = unsafe { &mut *((&srs.0.full_srs as *const SRS<$G>) as *mut SRS<$G>) as &mut SRS<$G> };
                    full_srs.add_lagrange_basis(x_domain);
                }

                Ok(srs.0.full_srs.lagrange_bases[&x_domain.size()][i as usize].clone().into())
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _add_lagrange_basis>](
                srs: $name,
                log2_size: ocaml::Int,
            ) {
                let ptr: &mut poly_commitment::srs::SRS<$G> =
                    unsafe { &mut *((&srs.0.full_srs as *const SRS<$G>) as *mut _) };
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

                Ok(srs.0.full_srs.commit_non_hiding(&p, 1, None).into())
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

                Ok(srs.0.full_srs.commit_non_hiding(&p, 1, None).into())
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
                crate::urs_utils::batch_dlog_accumulator_check(&srs.0.full_srs, &comms, &chals)
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _batch_accumulator_generate>](
                srs: $name,
                comms: ocaml::Int,
                chals: Vec<$CamlF>,
            ) -> Vec<$CamlG> {
                crate::urs_utils::batch_dlog_accumulator_generate::<$G>(
                    &srs.0.full_srs,
                    comms as usize,
                    &chals.into_iter().map(From::from).collect(),
                ).into_iter().map(Into::into).collect()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$name:snake _h>](srs: $name) -> $CamlG {
                srs.0.full_srs.h.into()
            }
        }
    }
}

//
// Bn254Fp
//

pub mod bn254_fp {
    use super::*;
    use crate::arkworks::{CamlBn254Fp, CamlGBn254};
    use mina_curves::bn254::{Bn254, Fp};

    impl_srs!(CamlBn254FpSrs, CamlBn254Fp, CamlGBn254, Fp, Bn254);
}
