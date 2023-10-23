use crate::pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex;
use ark_ff::One;
use kimchi::circuits::scalars::{caml::CamlRandomOracles, RandomOracles};
use kimchi::proof::ProverProof;
use kimchi::{
    prover::caml::{CamlPastaProofWithPublic, CamlProverPastaProof},
    verifier_index::VerifierIndex,
};
use mina_poseidon::{
    self,
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};
use paste::paste;
use poly_commitment::commitment::{caml::CamlPolyComm, shift_scalar, PolyComm};
use poly_commitment::evaluation_proof::OpeningProof;
use poly_commitment::SRS;
use CamlOpeningProof;

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlOracles<F> {
    pub o: CamlRandomOracles<F>,
    pub p_eval: (F, F),
    pub opening_prechallenges: Vec<F>,
    pub digest_before_evaluations: F,
}

macro_rules! impl_oracles {
    ($CamlF: ty, $F: ty, $CamlG: ty, $G: ty, $index: ty, $curve_params: ty) => {
        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_create>](
                lgr_comm: Vec<CamlPolyComm<$CamlG>>,
                index: $index,
                proof: CamlPastaProofWithPublic<$CamlG, $CamlF>,
            ) -> Result<CamlOracles<$CamlF>, ocaml::Error> {
                let index: VerifierIndex<$G, OpeningProof<$G>> = index.into();

                let lgr_comm: Vec<PolyComm<$G>> = lgr_comm
                    .into_iter()
                    .take(proof.proof.public.len())
                    .map(Into::into)
                    .collect();
                let lgr_comm_refs: Vec<_> = lgr_comm.iter().collect();

                let p_comm = PolyComm::<$G>::multi_scalar_mul(
                    &lgr_comm_refs,
                    &proof
                        .proof
                        .public
                        .iter()
                        .map(Into::<$F>::into)
                        .map(|s| -s)
                        .collect::<Vec<_>>(),
                );

                let p_comm = {
                    index
                        .srs()
                        .mask_custom(
                            p_comm.clone(),
                            &p_comm.map(|_| $F::one()),
                        )
                        .unwrap()
                        .commitment
                };

                let (proof, public_input): (ProverProof<$G, OpeningProof<$G>>, Vec<$F>) = proof.into();

                let oracles_result =
                    proof.oracles::<
                        DefaultFqSponge<$curve_params, PlonkSpongeConstantsKimchi>,
                        DefaultFrSponge<$F, PlonkSpongeConstantsKimchi>,
                    >(&index, &p_comm, Some(&public_input))?;

                let (mut sponge, combined_inner_product, p_eval, digest, oracles) = (
                    oracles_result.fq_sponge,
                    oracles_result.combined_inner_product,
                    oracles_result.public_evals,
                    oracles_result.digest,
                    oracles_result.oracles,
                );

                sponge.absorb_fr(&[shift_scalar::<$G>(combined_inner_product)]);

                let opening_prechallenges = proof
                    .proof
                    .prechallenges(&mut sponge)
                    .into_iter()
                    .map(|x| x.0.into())
                    .collect();

                Ok(CamlOracles {
                    o: oracles.into(),
                    p_eval: (p_eval[0][0].into(), p_eval[1][0].into()),
                    opening_prechallenges,
                    digest_before_evaluations: digest.into(),
                })
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_create_no_public>](
                lgr_comm: Vec<CamlPolyComm<$CamlG>>,
                index: $index,
                proof: CamlProverPastaProof<$CamlG, $CamlF>,
            ) -> Result<CamlOracles<$CamlF>, ocaml::Error> {
                let proof = CamlPastaProofWithPublic {
                    proof,
                    public_evals: None,
                };

                let index: VerifierIndex<$G, OpeningProof<$G>> = index.into();

                let lgr_comm: Vec<PolyComm<$G>> = lgr_comm
                    .into_iter()
                    .take(proof.proof.public.len())
                    .map(Into::into)
                    .collect();
                let lgr_comm_refs: Vec<_> = lgr_comm.iter().collect();

                let p_comm = PolyComm::<$G>::multi_scalar_mul(
                    &lgr_comm_refs,
                    &proof
                        .proof
                        .public
                        .iter()
                        .map(Into::<$F>::into)
                        .map(|s| -s)
                        .collect::<Vec<_>>(),
                );

                let p_comm = {
                    index
                        .srs()
                        .mask_custom(
                            p_comm.clone(),
                            &p_comm.map(|_| $F::one()),
                        )
                        .unwrap()
                        .commitment
                };

                let (proof, public_input): (ProverProof<$G, OpeningProof<$G>>, Vec<$F>) = proof.into();

                let oracles_result =
                    proof.oracles::<
                        DefaultFqSponge<$curve_params, PlonkSpongeConstantsKimchi>,
                        DefaultFrSponge<$F, PlonkSpongeConstantsKimchi>,
                    >(&index, &p_comm, Some(&public_input))?;

                let (mut sponge, combined_inner_product, p_eval, digest, oracles) = (
                    oracles_result.fq_sponge,
                    oracles_result.combined_inner_product,
                    oracles_result.public_evals,
                    oracles_result.digest,
                    oracles_result.oracles,
                );

                sponge.absorb_fr(&[shift_scalar::<$G>(combined_inner_product)]);

                let opening_prechallenges = proof
                    .proof
                    .prechallenges(&mut sponge)
                    .into_iter()
                    .map(|x| x.0.into())
                    .collect();

                Ok(CamlOracles {
                    o: oracles.into(),
                    p_eval: (p_eval[0][0].into(), p_eval[1][0].into()),
                    opening_prechallenges,
                    digest_before_evaluations: digest.into(),
                })
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_dummy>]() -> CamlRandomOracles<$CamlF> {
                RandomOracles::<$F>::default().into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_deep_copy>](
                x: CamlRandomOracles<$CamlF>,
            ) -> CamlRandomOracles<$CamlF> {
                x
            }
        }
    }
}

pub mod fp {
    use super::*;
    use crate::arkworks::{CamlFp, CamlGVesta};
    use mina_curves::pasta::{Fp, Vesta, VestaParameters};

    impl_oracles!(
        CamlFp,
        Fp,
        CamlGVesta,
        Vesta,
        CamlPastaFpPlonkVerifierIndex,
        VestaParameters
    );
}

pub mod fq {
    use super::*;
    use crate::{
        arkworks::{CamlFq, CamlGPallas},
        oracles::CamlOracles,
        pasta_fq_plonk_verifier_index::CamlPastaFqPlonkVerifierIndex,
    };
    use mina_curves::pasta::{Fq, Pallas, PallasParameters};

    impl_oracles!(
        CamlFq,
        Fq,
        CamlGPallas,
        Pallas,
        CamlPastaFqPlonkVerifierIndex,
        PallasParameters
    );
}
