use crate::pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex;
use commitment_dlog::commitment::{caml::CamlPolyComm, shift_scalar, PolyComm};
use kimchi::circuits::scalars::{caml::CamlRandomOracles, RandomOracles};
use kimchi::proof::ProverProof;
use kimchi::{prover::caml::CamlProverProof, verifier_index::VerifierIndex};
use oracle::{
    self,
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};
use paste::paste;

#[derive(ocaml::IntoValue, ocaml::FromValue, ocaml_gen::Struct)]
pub struct CamlOracles<F> {
    pub o: CamlRandomOracles<F>,
    pub p_eval: (F, F),
    pub opening_prechallenges: Vec<F>,
    pub digest_before_evaluations: F,
}

macro_rules! impl_oracles {
    ($F: ty, $CamlG: ty, $G: ty, $index: ty, $curve_params: ty) => {

        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_create>](
                lgr_comm: Vec<CamlPolyComm<$CamlG>>,
                index: $index,
                proof: CamlProverProof<$CamlG, $F>,
            ) -> Result<CamlOracles<$F>, ocaml::Error> {
                let index: VerifierIndex<$G> = index.into();

                let lgr_comm: Vec<PolyComm<$G>> = lgr_comm
                    .into_iter()
                    .take(proof.public.len())
                    .map(Into::into)
                    .collect();
                let lgr_comm_refs: Vec<_> = lgr_comm.iter().collect();

                let neg_pub: Vec<_> = proof
                .public
                .iter()
                .map(|s| -(*s))
                .collect();
                let p_comm = PolyComm::<$G>::multi_scalar_mul(
                    &lgr_comm_refs,
                    &neg_pub,
                );

                let proof: ProverProof<$G> = proof.into();

                let oracles_result =
                    proof.oracles::<DefaultFqSponge<$curve_params, PlonkSpongeConstantsKimchi>, DefaultFrSponge<$F, PlonkSpongeConstantsKimchi>>(&index, &p_comm)?;

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
            pub fn [<$F:snake _oracles_dummy>]() -> CamlRandomOracles<$F> {
                RandomOracles::<$F>::default().into()
            }

            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_deep_copy>](
                x: CamlRandomOracles<$F>,
            ) -> CamlRandomOracles<$F> {
                x
            }
        }
    }
}

pub mod fp {
    use super::*;
    use crate::arkworks::CamlGVesta;
    use mina_curves::pasta::{Fp, Vesta, VestaParameters};

    impl_oracles!(
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
        arkworks::CamlGPallas, oracles::CamlOracles,
        pasta_fq_plonk_verifier_index::CamlPastaFqPlonkVerifierIndex,
    };
    use mina_curves::pasta::{Fq, Pallas, PallasParameters};

    impl_oracles!(
        Fq,
        CamlGPallas,
        Pallas,
        CamlPastaFqPlonkVerifierIndex,
        PallasParameters
    );
}
