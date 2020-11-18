use algebra::tweedle::{
    dum::{Affine as GAffine, TweedledumParameters},
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

use crate::caml_vector;
use crate::tweedle_dum::CamlTweedleDumPolyCommVector;
use crate::tweedle_fq::CamlTweedleFq;
use crate::tweedle_fq_plonk_proof::CamlTweedleFqPlonkProof;
use crate::tweedle_fq_plonk_verifier_index::{
    CamlTweedleFqPlonkVerifierIndexPtr, CamlTweedleFqPlonkVerifierIndexRaw,
    CamlTweedleFqPlonkVerifierIndexRawPtr,
};

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkRandomOracles {
    pub beta: CamlTweedleFq,
    pub gamma: CamlTweedleFq,
    pub alpha_chal: CamlTweedleFq,
    pub alpha: CamlTweedleFq,
    pub zeta: CamlTweedleFq,
    pub v: CamlTweedleFq,
    pub u: CamlTweedleFq,
    pub zeta_chal: CamlTweedleFq,
    pub v_chal: CamlTweedleFq,
    pub u_chal: CamlTweedleFq,
}

impl From<CamlTweedleFqPlonkRandomOracles> for plonk_circuits::scalars::RandomOracles<Fq> {
    fn from(x: CamlTweedleFqPlonkRandomOracles) -> plonk_circuits::scalars::RandomOracles<Fq> {
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

impl From<plonk_circuits::scalars::RandomOracles<Fq>> for CamlTweedleFqPlonkRandomOracles {
    fn from(x: plonk_circuits::scalars::RandomOracles<Fq>) -> CamlTweedleFqPlonkRandomOracles {
        CamlTweedleFqPlonkRandomOracles {
            beta: CamlTweedleFq(x.beta),
            gamma: CamlTweedleFq(x.gamma),
            alpha_chal: CamlTweedleFq(x.alpha_chal.0),
            alpha: CamlTweedleFq(x.alpha),
            zeta: CamlTweedleFq(x.zeta),
            v: CamlTweedleFq(x.v),
            u: CamlTweedleFq(x.u),
            zeta_chal: CamlTweedleFq(x.zeta_chal.0),
            v_chal: CamlTweedleFq(x.v_chal.0),
            u_chal: CamlTweedleFq(x.u_chal.0),
        }
    }
}

/* This exposes an `Fq.t array` in OCaml. */
pub struct CamlTweedleFqScalarChallengeVec(pub Vec<ScalarChallenge<Fq>>);

unsafe impl ocaml::FromValue for CamlTweedleFqScalarChallengeVec {
    fn from_value(value: ocaml::Value) -> Self {
        let vec: Vec<ScalarChallenge<Fq>> = caml_vector::from_array_(
            ocaml::FromValue::from_value(value),
            |value: ocaml::Value| ScalarChallenge(CamlTweedleFq::from_value(value).0.clone()),
        );
        CamlTweedleFqScalarChallengeVec(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleFqScalarChallengeVec {
    fn to_value(self: Self) -> ocaml::Value {
        let vec: Vec<CamlTweedleFq> = self.0.iter().map(|x| CamlTweedleFq(x.0)).collect();
        vec.to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkOracles {
    pub o: CamlTweedleFqPlonkRandomOracles,
    pub p_eval: (CamlTweedleFq, CamlTweedleFq),
    pub opening_prechallenges: CamlTweedleFqScalarChallengeVec,
    pub digest_before_evaluations: CamlTweedleFq,
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_oracles_create_raw(
    lgr_comm: CamlTweedleDumPolyCommVector,
    index: CamlTweedleFqPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFqPlonkProof,
) -> CamlTweedleFqPlonkOracles {
    let index = index.as_ref();
    let proof: DlogProof<GAffine> = proof.into();

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul(
        &lgr_comm
            .0
            .iter()
            .take(proof.public.len())
            .map(|l| l)
            .collect(),
        &proof.public.iter().map(|s| -*s).collect(),
    );
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _, _, combined_inner_product) =
        proof.oracles::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlTweedleFqPlonkOracles {
        o: o.into(),
        p_eval: (CamlTweedleFq(p_eval[0][0]), CamlTweedleFq(p_eval[1][0])),
        opening_prechallenges: CamlTweedleFqScalarChallengeVec(
            proof.proof.prechallenges(&mut sponge),
        ),
        digest_before_evaluations: CamlTweedleFq(digest_before_evaluations),
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_oracles_create(
    lgr_comm: CamlTweedleDumPolyCommVector,
    index: CamlTweedleFqPlonkVerifierIndexPtr,
    proof: CamlTweedleFqPlonkProof,
) -> CamlTweedleFqPlonkOracles {
    let index: CamlTweedleFqPlonkVerifierIndexRaw = index.into();
    let proof: DlogProof<GAffine> = proof.into();

    let p_comm = PolyComm::<GAffine>::multi_scalar_mul(
        &lgr_comm
            .0
            .iter()
            .take(proof.public.len())
            .map(|l| l)
            .collect(),
        &proof.public.iter().map(|s| -*s).collect(),
    );
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _, _, combined_inner_product) =
        proof.oracles::<DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>, DefaultFrSponge<Fq, PlonkSpongeConstants>>(&index.0, &p_comm);

    sponge.absorb_fr(&[shift_scalar(combined_inner_product)]);

    CamlTweedleFqPlonkOracles {
        o: o.into(),
        p_eval: (CamlTweedleFq(p_eval[0][0]), CamlTweedleFq(p_eval[1][0])),
        opening_prechallenges: CamlTweedleFqScalarChallengeVec(
            proof.proof.prechallenges(&mut sponge),
        ),
        digest_before_evaluations: CamlTweedleFq(digest_before_evaluations),
    }
}
