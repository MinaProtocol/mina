use algebra::pasta::{
    pallas::{Affine as GAffine, PallasParameters},
    fq::Fq,
};

use oracle::{
    self,
    FqSponge,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge, ScalarChallenge},
};

use commitment_dlog::commitment::{shift_scalar, PolyComm};
use plonk_protocol_dlog::prover::ProverProof as DlogProof;

use crate::pasta_pallas::CamlPastaPallasPolyComm;
use crate::pasta_fp::CamlPastaFp;
use crate::pasta_fq::CamlPastaFq;
use crate::pasta_fq_plonk_proof::CamlPastaFqPlonkProof;
use crate::pasta_fq_plonk_verifier_index::{
    CamlPastaFqPlonkVerifierIndexPtr, CamlPastaFqPlonkVerifierIndexRaw,
    CamlPastaFqPlonkVerifierIndexRawPtr,
};

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFqPlonkRandomOracles {
    pub beta: CamlPastaFq,
    pub gamma: CamlPastaFq,
    pub alpha_chal: CamlPastaFq,
    pub alpha: CamlPastaFq,
    pub zeta: CamlPastaFq,
    pub v: CamlPastaFq,
    pub u: CamlPastaFq,
    pub zeta_chal: CamlPastaFq,
    pub v_chal: CamlPastaFq,
    pub u_chal: CamlPastaFq,
}

impl From<CamlPastaFqPlonkRandomOracles> for plonk_circuits::scalars::RandomOracles<Fq> {
    fn from(x: CamlPastaFqPlonkRandomOracles) -> plonk_circuits::scalars::RandomOracles<Fq> {
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

impl From<plonk_circuits::scalars::RandomOracles<Fq>> for CamlPastaFqPlonkRandomOracles {
    fn from(x: plonk_circuits::scalars::RandomOracles<Fq>) -> CamlPastaFqPlonkRandomOracles {
        CamlPastaFqPlonkRandomOracles {
            beta: CamlPastaFq(x.beta),
            gamma: CamlPastaFq(x.gamma),
            alpha_chal: CamlPastaFq(x.alpha_chal.0),
            alpha: CamlPastaFq(x.alpha),
            zeta: CamlPastaFq(x.zeta),
            v: CamlPastaFq(x.v),
            u: CamlPastaFq(x.u),
            zeta_chal: CamlPastaFq(x.zeta_chal.0),
            v_chal: CamlPastaFq(x.v_chal.0),
            u_chal: CamlPastaFq(x.u_chal.0),
        }
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFqPlonkOracles {
    pub o: CamlPastaFqPlonkRandomOracles,
    pub p_eval: (CamlPastaFq, CamlPastaFq),
    pub opening_prechallenges: Vec<CamlPastaFq>,
    pub digest_before_evaluations: CamlPastaFq,
}

#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_create_raw(
    lgr_comm: Vec<CamlPastaPallasPolyComm<CamlPastaFp>>,
    index: CamlPastaFqPlonkVerifierIndexRawPtr<'static>,
    proof: CamlPastaFqPlonkProof,
) -> CamlPastaFqPlonkOracles {
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
        proof.oracles::<DefaultFqSponge<PallasParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlPastaFqPlonkOracles {
        o: o.into(),
        p_eval: (CamlPastaFq(p_eval[0][0]), CamlPastaFq(p_eval[1][0])),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(From::from)
            .collect(),
        digest_before_evaluations: CamlPastaFq(digest_before_evaluations),
    }
}

#[ocaml::func]
pub fn caml_pasta_fq_plonk_oracles_create(
    lgr_comm: Vec<CamlPastaPallasPolyComm<CamlPastaFp>>,
    index: CamlPastaFqPlonkVerifierIndexPtr,
    proof: CamlPastaFqPlonkProof,
) -> CamlPastaFqPlonkOracles {
    let index: CamlPastaFqPlonkVerifierIndexRaw = index.into();
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
        proof.oracles::<DefaultFqSponge<PallasParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlPastaFqPlonkOracles {
        o: o.into(),
        p_eval: (CamlPastaFq(p_eval[0][0]), CamlPastaFq(p_eval[1][0])),
        opening_prechallenges: proof
            .proof
            .prechallenges(&mut sponge)
            .into_iter()
            .map(From::from)
            .collect(),
        digest_before_evaluations: CamlPastaFq(digest_before_evaluations),
    }
}
