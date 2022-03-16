use crate::pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex;
use commitment_dlog::commitment::{caml::CamlPolyComm, shift_scalar, PolyComm};
use kimchi::circuits::scalars::{caml::CamlRandomOracles, RandomOracles};
use kimchi::prover::ProverProof;
use kimchi::{prover::caml::CamlProverProof, verifier_index::VerifierIndex};
use oracle::{
    self,
    poseidon::PlonkSpongeConstantsKimchi,
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
    ($CamlF: ty, $F: ty, $CamlG: ty, $G: ty, $index: ty, $curve_params: ty) => {

        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_create>](
                lgr_comm: Vec<CamlPolyComm<$CamlG>>,
                index: $index,
                proof: CamlProverProof<$CamlG, $CamlF>,
            ) -> CamlOracles<$CamlF> {
                let index: VerifierIndex<$G> = index.into();

                let lgr_comm: Vec<PolyComm<$G>> = lgr_comm
                    .into_iter()
                    .take(proof.public.len())
                    .map(Into::into)
                    .collect();
                let lgr_comm_refs: Vec<_> = lgr_comm.iter().collect();

                let p_comm = PolyComm::<$G>::multi_scalar_mul(
                    &lgr_comm_refs,
                    &proof
                        .public
                        .iter()
                        .map(Into::<$F>::into)
                        .map(|s| -s)
                        .collect::<Vec<_>>(),
                );

                let proof: ProverProof<$G> = proof.into();

                let oracles_result =
                    proof.oracles::<DefaultFqSponge<$curve_params, PlonkSpongeConstantsKimchi>, DefaultFrSponge<$F, PlonkSpongeConstantsKimchi>>(&index, &p_comm);

                let (mut sponge, combined_inner_product, p_eval, digest, oracles) = (
                    oracles_result.fq_sponge,
                    oracles_result.combined_inner_product,
                    oracles_result.p_eval,
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

                CamlOracles {
                    o: oracles.into(),
                    p_eval: (p_eval[0][0].into(), p_eval[1][0].into()),
                    opening_prechallenges,
                    digest_before_evaluations: digest.into(),
                }
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
    use mina_curves::pasta::{
        fp::Fp,
        vesta::{Affine as GAffine, VestaParameters},
    };

    impl_oracles!(
        CamlFp,
        Fp,
        CamlGVesta,
        GAffine,
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
    use mina_curves::pasta::{
        fq::Fq,
        pallas::{Affine as GAffine, PallasParameters},
    };

    impl_oracles!(
        CamlFq,
        Fq,
        CamlGPallas,
        GAffine,
        CamlPastaFqPlonkVerifierIndex,
        PallasParameters
    );
}
