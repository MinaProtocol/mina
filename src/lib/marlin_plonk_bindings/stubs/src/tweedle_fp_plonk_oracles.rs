use algebra::tweedle::{
    dee::{Affine as GAffine, TweedledeeParameters},
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

use crate::tweedle_dee::CamlTweedleDeePolyComm;
use crate::tweedle_fp_plonk_proof::CamlTweedleFpPlonkProof;
use crate::tweedle_fp_plonk_verifier_index::{
    CamlTweedleFpPlonkVerifierIndex, CamlTweedleFpPlonkVerifierIndexRaw,
    CamlTweedleFpPlonkVerifierIndexRawPtr,
};

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkRandomOracles {
    pub beta: Fp,
    pub gamma: Fp,
    pub alpha_chal: Fp,
    pub alpha: Fp,
    pub zeta: Fp,
    pub v: Fp,
    pub u: Fp,
    pub zeta_chal: Fp,
    pub v_chal: Fp,
    pub u_chal: Fp,
}

impl From<CamlTweedleFpPlonkRandomOracles> for plonk_circuits::scalars::RandomOracles<Fp> {
    fn from(x: CamlTweedleFpPlonkRandomOracles) -> plonk_circuits::scalars::RandomOracles<Fp> {
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

impl From<plonk_circuits::scalars::RandomOracles<Fp>> for CamlTweedleFpPlonkRandomOracles {
    fn from(x: plonk_circuits::scalars::RandomOracles<Fp>) -> CamlTweedleFpPlonkRandomOracles {
        CamlTweedleFpPlonkRandomOracles {
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
pub struct CamlTweedleFpPlonkOracles {
    pub o: CamlTweedleFpPlonkRandomOracles,
    pub p_eval: (Fp, Fp),
    pub opening_prechallenges: Vec<Fp>,
    pub digest_before_evaluations: Fp,
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_create_raw(
    lgr_comm: Vec<CamlTweedleDeePolyComm<Fq>>,
    index: CamlTweedleFpPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFpPlonkProof,
) -> CamlTweedleFpPlonkOracles {
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
        proof.oracles::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlTweedleFpPlonkOracles {
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
pub fn caml_tweedle_fp_plonk_oracles_create(
    lgr_comm: Vec<CamlTweedleDeePolyComm<Fq>>,
    index: CamlTweedleFpPlonkVerifierIndex,
    proof: CamlTweedleFpPlonkProof,
) -> CamlTweedleFpPlonkOracles {
    let index: CamlTweedleFpPlonkVerifierIndexRaw = index.into();
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
        proof.oracles::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlTweedleFpPlonkOracles {
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
