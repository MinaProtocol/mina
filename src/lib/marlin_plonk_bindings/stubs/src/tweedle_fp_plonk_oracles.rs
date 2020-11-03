use algebra::tweedle::{
    dee::{Affine as GAffine, TweedledeeParameters},
    fp::Fp,
};

use oracle::{
    self,
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge, ScalarChallenge},
};

use commitment_dlog::commitment::PolyComm;
use plonk_protocol_dlog::prover::ProverProof as DlogProof;

use crate::caml_vector;
use crate::tweedle_dee::CamlTweedleDeePolyCommVector;
use crate::tweedle_fp::CamlTweedleFp;
use crate::tweedle_fp_plonk_proof::{CamlTweedleFpPlonkProof, CamlTweedleFpVec};
use crate::tweedle_fp_plonk_verifier_index::{
    CamlTweedleFpPlonkVerifierIndexPtr, CamlTweedleFpPlonkVerifierIndexRaw,
    CamlTweedleFpPlonkVerifierIndexRawPtr,
};

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

/* This exposes an `Fp.t array` in OCaml. */
pub struct CamlTweedleFpScalarChallengeVec(pub Vec<ScalarChallenge<Fp>>);

unsafe impl ocaml::FromValue for CamlTweedleFpScalarChallengeVec {
    fn from_value(value: ocaml::Value) -> Self {
        let vec: Vec<ScalarChallenge<Fp>> = caml_vector::from_array_(
            ocaml::FromValue::from_value(value),
            |value: ocaml::Value| ScalarChallenge(CamlTweedleFp::from_value(value).0.clone()),
        );
        CamlTweedleFpScalarChallengeVec(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleFpScalarChallengeVec {
    fn to_value(self: Self) -> ocaml::Value {
        let array =
            caml_vector::to_array_(self.0, |x| ocaml::ToValue::to_value(CamlTweedleFp(x.0)));
        array.to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkOracles {
    pub o: CamlTweedleFpPlonkRandomOracles,
    pub p_eval: (CamlTweedleFpVec, CamlTweedleFpVec),
    pub opening_prechallenges: CamlTweedleFpScalarChallengeVec,
    pub digest_before_evaluations: CamlTweedleFp,
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_create_raw(
    lgr_comm: CamlTweedleDeePolyCommVector,
    index: CamlTweedleFpPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFpPlonkProof,
) -> CamlTweedleFpPlonkOracles {
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
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _) =
        proof.oracles::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index.0, &p_comm);

    CamlTweedleFpPlonkOracles {
        o: o.into(),
        /* The clones below would normally be bad, but these are length=1 vectors.. */
        p_eval: (
            CamlTweedleFpVec(p_eval[0].clone()),
            CamlTweedleFpVec(p_eval[1].clone()),
        ),
        opening_prechallenges: CamlTweedleFpScalarChallengeVec(
            proof.proof.prechallenges(&mut sponge),
        ),
        digest_before_evaluations: CamlTweedleFp(digest_before_evaluations),
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_oracles_create(
    lgr_comm: CamlTweedleDeePolyCommVector,
    index: CamlTweedleFpPlonkVerifierIndexPtr,
    proof: CamlTweedleFpPlonkProof,
) -> CamlTweedleFpPlonkOracles {
    let index: CamlTweedleFpPlonkVerifierIndexRaw = index.into();
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
    let (mut sponge, digest_before_evaluations, o, _, p_eval, _, _) =
        proof.oracles::<DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>, DefaultFrSponge<Fp, PlonkSpongeConstants>>(&index.0, &p_comm);

    CamlTweedleFpPlonkOracles {
        o: o.into(),
        /* The clones below would normally be bad, but these are length=1 vectors.. */
        p_eval: (
            CamlTweedleFpVec(p_eval[0].clone()),
            CamlTweedleFpVec(p_eval[1].clone()),
        ),
        opening_prechallenges: CamlTweedleFpScalarChallengeVec(
            proof.proof.prechallenges(&mut sponge),
        ),
        digest_before_evaluations: CamlTweedleFp(digest_before_evaluations),
    }
}
