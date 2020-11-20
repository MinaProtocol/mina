use algebra::pasta::{
    vesta::{Affine as GAffine, VestaParameters},
    fp::Fp,
};

use oracle::{
    self,
    FqSponge,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge, ScalarChallenge},
};

use commitment_dlog::commitment::{shift_scalar, PolyComm};
use plonk_protocol_dlog::prover::ProverProof as DlogProof;

use crate::pasta_vesta::CamlPastaVestaPolyComm;
use crate::pasta_fp::CamlPastaFp;
use crate::pasta_fp_plonk_proof::CamlPastaFpPlonkProof;
use crate::pasta_fp_plonk_verifier_index::{
    CamlPastaFpPlonkVerifierIndexPtr, CamlPastaFpPlonkVerifierIndexRaw,
    CamlPastaFpPlonkVerifierIndexRawPtr,
};
use crate::pasta_fq::CamlPastaFq;

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFpPlonkRandomOracles {
    pub beta: CamlPastaFp,
    pub gamma: CamlPastaFp,
    pub alpha_chal: CamlPastaFp,
    pub alpha: CamlPastaFp,
    pub zeta: CamlPastaFp,
    pub v: CamlPastaFp,
    pub u: CamlPastaFp,
    pub zeta_chal: CamlPastaFp,
    pub v_chal: CamlPastaFp,
    pub u_chal: CamlPastaFp,
}

impl From<CamlPastaFpPlonkRandomOracles> for plonk_circuits::scalars::RandomOracles<Fp> {
    fn from(x: CamlPastaFpPlonkRandomOracles) -> plonk_circuits::scalars::RandomOracles<Fp> {
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

impl From<plonk_circuits::scalars::RandomOracles<Fp>> for CamlPastaFpPlonkRandomOracles {
    fn from(x: plonk_circuits::scalars::RandomOracles<Fp>) -> CamlPastaFpPlonkRandomOracles {
        CamlPastaFpPlonkRandomOracles {
            beta: CamlPastaFp(x.beta),
            gamma: CamlPastaFp(x.gamma),
            alpha_chal: CamlPastaFp(x.alpha_chal.0),
            alpha: CamlPastaFp(x.alpha),
            zeta: CamlPastaFp(x.zeta),
            v: CamlPastaFp(x.v),
            u: CamlPastaFp(x.u),
            zeta_chal: CamlPastaFp(x.zeta_chal.0),
            v_chal: CamlPastaFp(x.v_chal.0),
            u_chal: CamlPastaFp(x.u_chal.0),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFpPlonkOracles {
    pub o: CamlPastaFpPlonkRandomOracles,
    pub p_eval: (CamlPastaFp, CamlPastaFp),
    pub opening_prechallenges: Vec<CamlPastaFp>,
    pub digest_before_evaluations: CamlPastaFp,
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_oracles_create_raw(
    lgr_comm: Vec<CamlPastaVestaPolyComm<CamlPastaFq>>,
    index: CamlPastaFpPlonkVerifierIndexRawPtr<'static>,
    proof: CamlPastaFpPlonkProof,
) -> CamlPastaFpPlonkOracles {
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
        proof.oracles::<DefaultFqSponge<VestaParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlPastaFpPlonkOracles {
        o: o.into(),
        p_eval: (CamlPastaFp(p_eval[0][0]), CamlPastaFp(p_eval[1][0])),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(From::from)
            .collect(),
        digest_before_evaluations: CamlPastaFp(digest_before_evaluations),
    }
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_oracles_create(
    lgr_comm: Vec<CamlPastaVestaPolyComm<CamlPastaFq>>,
    index: CamlPastaFpPlonkVerifierIndexPtr,
    proof: CamlPastaFpPlonkProof,
) -> CamlPastaFpPlonkOracles {
    let index: CamlPastaFpPlonkVerifierIndexRaw = index.into();
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
        proof.oracles::<DefaultFqSponge<VestaParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlPastaFpPlonkOracles {
        o: o.into(),
        p_eval: (CamlPastaFp(p_eval[0][0]), CamlPastaFp(p_eval[1][0])),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(From::from)
            .collect(),
        digest_before_evaluations: CamlPastaFp(digest_before_evaluations),
    }
}
