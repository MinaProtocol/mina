use algebra::tweedle::{
    dum::{Affine as GAffine, TweedledumParameters},
    fp::Fp,
    fq::Fq,
};

use oracle::{
    self,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge, ScalarChallenge},
    FqSponge,
};

use commitment_dlog::commitment::{shift_scalar, PolyComm};
use plonk_protocol_dlog::prover::ProverProof as DlogProof;

use crate::tweedle_dum::CamlTweedleDumPolyComm;
use crate::tweedle_fq_plonk_proof::CamlTweedleFqPlonkProof;
use crate::tweedle_fq_plonk_verifier_index::{
    CamlTweedleFqPlonkVerifierIndex, CamlTweedleFqPlonkVerifierIndexRaw,
    CamlTweedleFqPlonkVerifierIndexRawPtr,
};

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkRandomOracles {
    pub beta: Fq,
    pub gamma: Fq,
    pub alpha_chal: Fq,
    pub alpha: Fq,
    pub zeta: Fq,
    pub v: Fq,
    pub u: Fq,
    pub zeta_chal: Fq,
    pub v_chal: Fq,
    pub u_chal: Fq,
}

impl From<CamlTweedleFqPlonkRandomOracles> for plonk_circuits::scalars::RandomOracles<Fq> {
    fn from(x: CamlTweedleFqPlonkRandomOracles) -> plonk_circuits::scalars::RandomOracles<Fq> {
        plonk_circuits::scalars::RandomOracles {
            beta: x.beta,
            gamma: x.gamma,
            alpha_chal: ScalarChallenge(x.alpha_chal),
            alpha: x.alpha,
            zeta: x.zeta,
            v: x.v,
            u: x.u,
            zeta_chal: ScalarChallenge(x.zeta_chal),
            v_chal: ScalarChallenge(x.v_chal),
            u_chal: ScalarChallenge(x.u_chal),
        }
    }
}

impl From<plonk_circuits::scalars::RandomOracles<Fq>> for CamlTweedleFqPlonkRandomOracles {
    fn from(x: plonk_circuits::scalars::RandomOracles<Fq>) -> CamlTweedleFqPlonkRandomOracles {
        CamlTweedleFqPlonkRandomOracles {
            beta: x.beta,
            gamma: x.gamma,
            alpha_chal: x.alpha_chal.0,
            alpha: x.alpha,
            zeta: x.zeta,
            v: x.v,
            u: x.u,
            zeta_chal: x.zeta_chal.0,
            v_chal: x.v_chal.0,
            u_chal: x.u_chal.0,
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkOracles {
    pub o: CamlTweedleFqPlonkRandomOracles,
    pub p_eval: (Fq, Fq),
    pub opening_prechallenges: Vec<Fq>,
    pub digest_before_evaluations: Fq,
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_oracles_create_raw(
    lgr_comm: Vec<CamlTweedleDumPolyComm<Fp>>,
    index: CamlTweedleFqPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFqPlonkProof,
) -> CamlTweedleFqPlonkOracles {
    let index = index.as_ref();
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
        proof.oracles::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlTweedleFqPlonkOracles {
        o: o.into(),
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
pub fn caml_tweedle_fq_plonk_oracles_create(
    lgr_comm: Vec<CamlTweedleDumPolyComm<Fp>>,
    index: CamlTweedleFqPlonkVerifierIndex,
    proof: CamlTweedleFqPlonkProof,
) -> CamlTweedleFqPlonkOracles {
    let index: CamlTweedleFqPlonkVerifierIndexRaw = index.into();
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
        proof.oracles::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlTweedleFqPlonkOracles {
        o: o.into(),
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
