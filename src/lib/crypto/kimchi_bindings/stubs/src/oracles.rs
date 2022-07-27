use crate::pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex;
use commitment_dlog::commitment::caml::CamlPolyComm;
use kimchi::circuits::scalars::{caml::CamlRandomOracles, RandomOracles};
use kimchi::{
    oracles::caml::{create_caml_oracles, CamlOracles},
    prover::caml::CamlProverProof,
    verifier_index::VerifierIndex,
};
use oracle::{
    self,
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use paste::paste;

macro_rules! impl_oracles {
    ($CamlF: ty, $F: ty, $CamlG: ty, $G: ty, $index: ty, $curve_params: ty) => {
        paste! {
            #[ocaml_gen::func]
            #[ocaml::func]
            pub fn [<$F:snake _oracles_create>](
                lgr_comm: Vec<CamlPolyComm<$CamlG>>,
                index: $index,
                proof: CamlProverProof<$CamlG, $CamlF>,
            ) -> Result<CamlOracles<$CamlF>, ocaml::Error> {
                let index: VerifierIndex<$G> = index.into();
                let lgr_comm = lgr_comm.into_iter().map(Into::into).collect();
                let proof = proof.into();
                create_caml_oracles::<$G, $CamlF, DefaultFqSponge<$curve_params, PlonkSpongeConstantsKimchi>, DefaultFrSponge<$F, PlonkSpongeConstantsKimchi>, $curve_params>(lgr_comm, index, proof).map_err(|e| ocaml::Error::Error(e.into()))
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
    };
}

pub mod fp {
    use super::*;
    use crate::arkworks::{CamlFp, CamlGVesta};
    use mina_curves::pasta::{
        fp::Fp,
        vesta::{Vesta as GAffine, VestaParameters},
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
        pallas::{Pallas as GAffine, PallasParameters},
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
