use algebra::tweedle::{
    dee::{Affine as GAffine, TweedledeeParameters},
    fp::Fp,
};

use oracle::{
    self,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};

use commitment_dlog::commitment::{shift_scalar, PolyComm};
use plonk_circuits::scalars::RandomOracles;
use plonk_protocol_dlog::{
    index::VerifierIndex as DlogVerifierIndex, prover::ProverProof as DlogProof,
};

use crate::tweedle_fp_plonk_verifier_index::CamlTweedleFpPlonkVerifierIndex;

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkOracles {
    pub o: RandomOracles<Fp>,
    pub p_eval: (Fp, Fp),
    pub opening_prechallenges: Vec<Fp>,
    pub digest_before_evaluations: Fp,
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_create(
    lgr_comm: Vec<PolyComm<GAffine>>,
    index: CamlTweedleFpPlonkVerifierIndex,
    proof: DlogProof<GAffine>,
) -> CamlTweedleFpPlonkOracles {
    let index: DlogVerifierIndex<'_, GAffine> = index.into();
    let proof: DlogProof<GAffine> = proof.into();
    let lgr_comm: Vec<PolyComm<GAffine>> = lgr_comm.into_iter().map(From::from).collect();

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul(
        &lgr_comm
            .iter()
            .take(proof.public.len())
            .map(|x| x)
            .collect(),
        &proof.public.iter().map(|s| -*s).collect(),
    );
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _, _, combined_inner_product) =
        proof.oracles::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlTweedleFpPlonkOracles {
        o: o,
        p_eval: (p_eval[0][0], p_eval[1][0]),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(|x| x.0)
            .collect(),
        digest_before_evaluations: digest_before_evaluations,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_dummy() -> RandomOracles<Fp> {
    RandomOracles::zero().into()
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_deep_copy(x: RandomOracles<Fp>) -> RandomOracles<Fp> {
    x
}
