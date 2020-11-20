use algebra::tweedle::{
    dee::{Affine as GAffine, TweedledeeParameters},
    fp::Fp,
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
use crate::tweedle_fp::CamlTweedleFp;
use crate::tweedle_fp_plonk_proof::CamlTweedleFpPlonkProof;
use crate::tweedle_fp_plonk_verifier_index::{
    CamlTweedleFpPlonkVerifierIndexPtr, CamlTweedleFpPlonkVerifierIndexRaw,
    CamlTweedleFpPlonkVerifierIndexRawPtr,
};
use crate::tweedle_fq::CamlTweedleFq;

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkRandomOracles {
    pub beta: CamlTweedleFp,
    pub gamma: CamlTweedleFp,
    pub alpha_chal: CamlTweedleFp,
    pub alpha: CamlTweedleFp,
    pub zeta: CamlTweedleFp,
    pub v: CamlTweedleFp,
    pub u: CamlTweedleFp,
    pub zeta_chal: CamlTweedleFp,
    pub v_chal: CamlTweedleFp,
    pub u_chal: CamlTweedleFp,
}

impl From<CamlTweedleFpPlonkRandomOracles> for plonk_circuits::scalars::RandomOracles<Fp> {
    fn from(x: CamlTweedleFpPlonkRandomOracles) -> plonk_circuits::scalars::RandomOracles<Fp> {
        plonk_circuits::scalars::RandomOracles {
            beta: x.beta.0,
            gamma: x.gamma.0,
            alpha_chal: ScalarChallenge(x.alpha_chal.0),
            alpha: x.alpha.0,
            zeta: x.zeta.0,
            v: x.v.0,
            u: x.u.0,
            zeta_chal: ScalarChallenge(x.zeta_chal.0),
            v_chal: ScalarChallenge(x.v_chal.0),
            u_chal: ScalarChallenge(x.u_chal.0),
        }
    }
}

impl From<plonk_circuits::scalars::RandomOracles<Fp>> for CamlTweedleFpPlonkRandomOracles {
    fn from(x: plonk_circuits::scalars::RandomOracles<Fp>) -> CamlTweedleFpPlonkRandomOracles {
        CamlTweedleFpPlonkRandomOracles {
            beta: CamlTweedleFp(x.beta),
            gamma: CamlTweedleFp(x.gamma),
            alpha_chal: CamlTweedleFp(x.alpha_chal.0),
            alpha: CamlTweedleFp(x.alpha),
            zeta: CamlTweedleFp(x.zeta),
            v: CamlTweedleFp(x.v),
            u: CamlTweedleFp(x.u),
            zeta_chal: CamlTweedleFp(x.zeta_chal.0),
            v_chal: CamlTweedleFp(x.v_chal.0),
            u_chal: CamlTweedleFp(x.u_chal.0),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkOracles {
    pub o: CamlTweedleFpPlonkRandomOracles,
    pub p_eval: (CamlTweedleFp, CamlTweedleFp),
    pub opening_prechallenges: Vec<CamlTweedleFp>,
    pub digest_before_evaluations: CamlTweedleFp,
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_create_raw(
    lgr_comm: Vec<CamlTweedleDeePolyComm<CamlTweedleFq>>,
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
        p_eval: (CamlTweedleFp(p_eval[0][0]), CamlTweedleFp(p_eval[1][0])),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(From::from)
            .collect(),
        digest_before_evaluations: CamlTweedleFp(digest_before_evaluations),
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_create(
    lgr_comm: Vec<CamlTweedleDeePolyComm<CamlTweedleFq>>,
    index: CamlTweedleFpPlonkVerifierIndexPtr,
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
        p_eval: (CamlTweedleFp(p_eval[0][0]), CamlTweedleFp(p_eval[1][0])),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(From::from)
            .collect(),
        digest_before_evaluations: CamlTweedleFp(digest_before_evaluations),
    }
}
