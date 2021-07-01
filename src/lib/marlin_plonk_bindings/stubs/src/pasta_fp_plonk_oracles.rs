use crate::arkworks::{CamlDlogProofVesta, CamlFp, CamlPolyCommVesta, CamlRandomOraclesFp};
use crate::pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex;
use commitment_dlog::commitment::{shift_scalar, PolyComm};
use mina_curves::pasta::{
    fp::Fp,
    vesta::{Affine as GAffine, VestaParameters},
};
use oracle::{
    self,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge},
    FqSponge,
};
use plonk_circuits::scalars::RandomOracles;
use plonk_protocol_dlog::index::VerifierIndex as DlogVerifierIndex;

/// The state of the verifier during verification
#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFpPlonkOracles {
    pub o: CamlRandomOraclesFp, // all the challenges produced during the protocol
    pub p_eval: (CamlFp, CamlFp), // two evaluation of some poly?
    pub opening_prechallenges: Vec<CamlFp>, // challenges before some opening?
    pub digest_before_evaluations: CamlFp, // digest of poseidon before evaluating?
}

/// Creates a [CamlPastaFpPlonkOracles] state which will initialize a verifier
#[ocaml::func]
pub fn caml_pasta_fp_plonk_oracles_create(
    lgr_comm: Vec<CamlPolyCommVesta>, // the bases to commit polynomials
    index: CamlPastaFpPlonkVerifierIndex, // parameters
    proof: CamlDlogProofVesta,        // the final proof (contains public elements at the beginning)
) -> CamlPastaFpPlonkOracles {
    // conversions
    let index: DlogVerifierIndex<'_, GAffine> = index.into();
    let lgr_comm: Vec<PolyComm<GAffine>> = lgr_comm
        .iter()
        .take(proof.public.len())
        .map(Into::into)
        .collect();
    let lgr_comm_refs = lgr_comm.iter().collect();

    // get commitments to the public elements
    let p_comm = PolyComm::<GAffine>::multi_scalar_mul(
        &lgr_comm_refs,
        &proof.public.iter().map(|s| -*s).collect(),
    );

    // runs the entire protocol
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _, _, combined_inner_product) =
        proof.oracles::<DefaultFqSponge<VestaParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    // return the state at that point on.
    let opening_prechallenges = proof
        .proof
        .prechallenges(&mut sponge)
        .into_iter()
        .map(|x| x.0.into())
        .collect();
    CamlPastaFpPlonkOracles {
        o: o.into(),
        p_eval: (p_eval[0][0].into(), p_eval[1][0].into()),
        opening_prechallenges,
        digest_before_evaluations: digest_before_evaluations.into(),
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_oracles_dummy() -> CamlRandomOraclesFp {
    RandomOracles::<Fp>::zero().into()
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_oracles_deep_copy(x: CamlRandomOraclesFp) -> CamlRandomOraclesFp {
    x
}
