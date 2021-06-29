use crate::{
    arkworks::{CamlDlogProofPallas, CamlFq, CamlPolyCommPallas, CamlRandomOraclesFq},
    pasta_fq_plonk_verifier_index::CamlPastaFqPlonkVerifierIndex,
};
use commitment_dlog::commitment::{shift_scalar, PolyComm};
use mina_curves::pasta::{
    fq::Fq,
    pallas::{Affine as GAffine, PallasParameters},
};
use oracle::{
    self,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};
use plonk_circuits::scalars::RandomOracles;
use plonk_protocol_dlog::{
    index::VerifierIndex as DlogVerifierIndex, prover::ProverProof as DlogProof,
};

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFqPlonkOracles {
    pub o: CamlRandomOraclesFq,
    pub p_eval: (CamlFq, CamlFq),
    pub opening_prechallenges: Vec<CamlFq>,
    pub digest_before_evaluations: CamlFq,
}

#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_create(
    lgr_comm: Vec<CamlPolyCommPallas>,
    index: CamlPastaFqPlonkVerifierIndex,
    proof: CamlDlogProofPallas,
) -> CamlPastaFqPlonkOracles {
    let index: DlogVerifierIndex<'_, GAffine> = index.into();
    let proof: DlogProof<GAffine> = proof.into();
    let lgr_comm: Vec<PolyComm<GAffine>> = lgr_comm.into_iter().map(Into::into).collect();

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul(
        &lgr_comm
            .iter()
            .take(proof.public.len())
            .map(|x| x)
            .collect(),
        &proof.public.iter().map(|s| -*s).collect(),
    );
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _, _, combined_inner_product) =
        proof.oracles::<DefaultFqSponge<PallasParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    let opening_prechallenges = proof
        .proof
        .prechallenges(&mut sponge)
        .into_iter()
        .map(|x| x.0.into())
        .collect();
    CamlPastaFqPlonkOracles {
        o: o.into(),
        p_eval: (p_eval[0][0].into(), p_eval[1][0].into()),
        opening_prechallenges,
        digest_before_evaluations: digest_before_evaluations.into(),
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_dummy() -> CamlRandomOraclesFq {
    RandomOracles::<Fq>::zero().into()
}

#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_deep_copy(x: CamlRandomOraclesFq) -> CamlRandomOraclesFq {
    x
}
