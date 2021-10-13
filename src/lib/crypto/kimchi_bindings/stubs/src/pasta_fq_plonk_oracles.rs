use crate::{
    arkworks::{CamlFq, CamlGPallas},
    oracles::CamlOracles,
    pasta_fq_plonk_verifier_index::CamlPastaFqPlonkVerifierIndex,
};
use commitment_dlog::commitment::{caml::CamlPolyComm, shift_scalar, PolyComm};
use mina_curves::pasta::{
    fq::Fq,
    pallas::{Affine as GAffine, PallasParameters},
};
use ocaml_gen::ocaml_gen;
use oracle::{
    self,
    poseidon::PlonkSpongeConstants15W,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};
use plonk_15_wires_circuits::nolookup::scalars::{caml::CamlRandomOracles, RandomOracles};
use plonk_15_wires_protocol_dlog::{
    index::VerifierIndex as DlogVerifierIndex,
    prover::{caml::CamlProverProof, ProverProof},
};

//
// Methods
//

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_create(
    lgr_comm: Vec<CamlPolyComm<CamlGPallas>>,
    index: CamlPastaFqPlonkVerifierIndex,
    proof: CamlProverProof<CamlGPallas, CamlFq>,
) -> CamlOracles<CamlFq> {
    // conversions
    let index: DlogVerifierIndex<GAffine> = index.into();
    let lgr_comm: Vec<PolyComm<GAffine>> = lgr_comm
        .into_iter()
        .take(proof.public.len())
        .map(Into::into)
        .collect();
    let lgr_comm_refs = lgr_comm.iter().collect();

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul(
        &lgr_comm_refs,
        &proof
            .public
            .iter()
            .map(Into::<Fq>::into)
            .map(|s| -s)
            .collect(),
    );

    let proof: ProverProof<GAffine> = proof.into();

    let oracles_result =
        proof.oracles::<DefaultFqSponge<PallasParameters, PlonkSpongeConstants15W>, DefaultFrSponge<Fq, PlonkSpongeConstants15W>>(&index, &p_comm);

    let (mut sponge, combined_inner_product, p_eval, digest, oracles) = (
        oracles_result.fq_sponge,
        oracles_result.combined_inner_product,
        oracles_result.p_eval,
        oracles_result.digest,
        oracles_result.oracles,
    );

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

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

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_dummy() -> CamlRandomOracles<CamlFq> {
    RandomOracles::<Fq>::default().into()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_deep_copy(
    x: CamlRandomOracles<CamlFq>,
) -> CamlRandomOracles<CamlFq> {
    x
}
