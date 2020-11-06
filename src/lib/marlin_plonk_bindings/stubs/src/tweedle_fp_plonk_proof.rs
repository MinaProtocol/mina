use algebra::tweedle::{
    dee::{Affine as GAffine, TweedledeeParameters},
    fp::Fp,
    fq::Fq,
};

use plonk_circuits::scalars::ProofEvaluations as DlogProofEvaluations;

use oracle::{
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};

use groupmap::GroupMap;

use commitment_dlog::commitment::{CommitmentCurve, OpeningProof, PolyComm};
use plonk_protocol_dlog::index::VerifierIndex as DlogVerifierIndex;
use plonk_protocol_dlog::prover::ProverProof as DlogProof;

use ocaml::FromValue;

use crate::caml_vector;
use crate::tweedle_dee::{
    CamlTweedleDeeAffine, CamlTweedleDeeAffinePairVector, CamlTweedleDeeAffineVector,
    CamlTweedleDeePolyComm, CamlTweedleDeePolyCommVector,
};
use crate::tweedle_fp::{CamlTweedleFp, CamlTweedleFpPtr};
use crate::tweedle_fp_plonk_index::CamlTweedleFpPlonkIndexPtr;
use crate::tweedle_fp_plonk_verifier_index::{
    CamlTweedleFpPlonkVerifierIndexPtr, CamlTweedleFpPlonkVerifierIndexRawPtr,
};
use crate::tweedle_fp_vector::CamlTweedleFpVectorPtr;
use crate::tweedle_fq::{CamlTweedleFq, CamlTweedleFqPtr};

pub struct CamlTweedleFpVec(pub Vec<Fp>);

unsafe impl ocaml::FromValue for CamlTweedleFpVec {
    fn from_value(value: ocaml::Value) -> Self {
        let vec: Vec<Fp> = caml_vector::from_array_(
            ocaml::FromValue::from_value(value),
            |value: ocaml::Value| CamlTweedleFp::from_value(value).0.clone(),
        );
        CamlTweedleFpVec(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleFpVec {
    fn to_value(self: Self) -> ocaml::Value {
        let array = caml_vector::to_array_(self.0, |x| ocaml::ToValue::to_value(CamlTweedleFp(x)));
        array.to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkProofEvaluations {
    pub l: CamlTweedleFpVec,
    pub r: CamlTweedleFpVec,
    pub o: CamlTweedleFpVec,
    pub z: CamlTweedleFpVec,
    pub t: CamlTweedleFpVec,
    pub f: CamlTweedleFpVec,
    pub sigma1: CamlTweedleFpVec,
    pub sigma2: CamlTweedleFpVec,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkOpeningProof {
    pub lr: CamlTweedleDeeAffinePairVector,
    pub delta: CamlTweedleDeeAffine<CamlTweedleFq>,
    pub z1: CamlTweedleFp,
    pub z2: CamlTweedleFp,
    pub sg: CamlTweedleDeeAffine<CamlTweedleFq>,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkMessages {
    // polynomial commitments
    pub l_comm: CamlTweedleDeePolyComm<CamlTweedleFq>,
    pub r_comm: CamlTweedleDeePolyComm<CamlTweedleFq>,
    pub o_comm: CamlTweedleDeePolyComm<CamlTweedleFq>,
    pub z_comm: CamlTweedleDeePolyComm<CamlTweedleFq>,
    pub t_comm: CamlTweedleDeePolyComm<CamlTweedleFq>,
}

pub struct CamlTweedleFpPrevChallenges(pub Vec<(Vec<Fp>, PolyComm<GAffine>)>);

unsafe impl ocaml::FromValue for CamlTweedleFpPrevChallenges {
    fn from_value(value: ocaml::Value) -> Self {
        let vec = caml_vector::from_array_(
            ocaml::FromValue::from_value(value),
            |value: ocaml::Value| {
                let (array_value, polycomm_value): (
                    ocaml::Array<ocaml::Value>,
                    CamlTweedleDeePolyComm<CamlTweedleFqPtr>,
                ) = ocaml::FromValue::from_value(value);
                let vec: Vec<Fp> = caml_vector::from_array_(array_value, |value: ocaml::Value| {
                    CamlTweedleFpPtr::from_value(value).as_ref().0
                });
                (vec, polycomm_value.into())
            },
        );
        CamlTweedleFpPrevChallenges(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleFpPrevChallenges {
    fn to_value(self: Self) -> ocaml::Value {
        let array = caml_vector::to_array_(self.0, |(vec, polycomm)| {
            ocaml::frame!((array_value) {
                let polycomm: CamlTweedleDeePolyComm<CamlTweedleFq> = polycomm.into();
                let array_inner =
                    caml_vector::to_array_(vec, |x| ocaml::ToValue::to_value(CamlTweedleFp(x)));
                array_value = array_inner.to_value().clone();
                ocaml::ToValue::to_value((array_inner, polycomm))
            })
        });
        array.to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkProof {
    pub messages: CamlTweedleFpPlonkMessages,
    pub proof: CamlTweedleFpPlonkOpeningProof,
    pub evals: (
        CamlTweedleFpPlonkProofEvaluations,
        CamlTweedleFpPlonkProofEvaluations,
    ),
    pub public: CamlTweedleFpVec,
    pub prev_challenges: CamlTweedleFpPrevChallenges,
}

impl From<CamlTweedleFpPlonkProof> for DlogProof<GAffine> {
    fn from(x: CamlTweedleFpPlonkProof) -> Self {
        DlogProof {
            prev_challenges: x.prev_challenges.0,
            proof: OpeningProof {
                lr: x.proof.lr.0,
                z1: x.proof.z1.0,
                z2: x.proof.z2.0,
                delta: x.proof.delta.into(),
                sg: x.proof.sg.into(),
            },
            l_comm: x.messages.l_comm.into(),
            r_comm: x.messages.r_comm.into(),
            o_comm: x.messages.o_comm.into(),
            z_comm: x.messages.z_comm.into(),
            t_comm: x.messages.t_comm.into(),
            public: x.public.0,
            evals: {
                let (evals0, evals1) = x.evals;
                [
                    DlogProofEvaluations {
                        l: evals0.l.0,
                        r: evals0.r.0,
                        o: evals0.o.0,
                        z: evals0.z.0,
                        t: evals0.t.0,
                        f: evals0.f.0,
                        sigma1: evals0.sigma1.0,
                        sigma2: evals0.sigma2.0,
                    },
                    DlogProofEvaluations {
                        l: evals1.l.0,
                        r: evals1.r.0,
                        o: evals1.o.0,
                        z: evals1.z.0,
                        t: evals1.t.0,
                        f: evals1.f.0,
                        sigma1: evals1.sigma1.0,
                        sigma2: evals1.sigma2.0,
                    },
                ]
            },
        }
    }
}

impl From<DlogProof<GAffine>> for CamlTweedleFpPlonkProof {
    fn from(x: DlogProof<GAffine>) -> Self {
        CamlTweedleFpPlonkProof {
            prev_challenges: CamlTweedleFpPrevChallenges(x.prev_challenges),
            proof: CamlTweedleFpPlonkOpeningProof {
                lr: CamlTweedleDeeAffinePairVector(x.proof.lr),
                z1: CamlTweedleFp(x.proof.z1),
                z2: CamlTweedleFp(x.proof.z2),
                delta: x.proof.delta.into(),
                sg: x.proof.sg.into(),
            },
            messages: CamlTweedleFpPlonkMessages {
                l_comm: x.l_comm.into(),
                r_comm: x.r_comm.into(),
                o_comm: x.o_comm.into(),
                z_comm: x.z_comm.into(),
                t_comm: x.t_comm.into(),
            },
            public: CamlTweedleFpVec(x.public),
            evals: {
                let [evals0, evals1] = x.evals;
                (
                    CamlTweedleFpPlonkProofEvaluations {
                        l: CamlTweedleFpVec(evals0.l),
                        r: CamlTweedleFpVec(evals0.r),
                        o: CamlTweedleFpVec(evals0.o),
                        z: CamlTweedleFpVec(evals0.z),
                        t: CamlTweedleFpVec(evals0.t),
                        f: CamlTweedleFpVec(evals0.f),
                        sigma1: CamlTweedleFpVec(evals0.sigma1),
                        sigma2: CamlTweedleFpVec(evals0.sigma2),
                    },
                    CamlTweedleFpPlonkProofEvaluations {
                        l: CamlTweedleFpVec(evals1.l),
                        r: CamlTweedleFpVec(evals1.r),
                        o: CamlTweedleFpVec(evals1.o),
                        z: CamlTweedleFpVec(evals1.z),
                        t: CamlTweedleFpVec(evals1.t),
                        f: CamlTweedleFpVec(evals1.f),
                        sigma1: CamlTweedleFpVec(evals1.sigma1),
                        sigma2: CamlTweedleFpVec(evals1.sigma2),
                    },
                )
            },
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_create(
    index: CamlTweedleFpPlonkIndexPtr<'static>,
    primary_input: CamlTweedleFpVectorPtr,
    auxiliary_input: CamlTweedleFpVectorPtr,
    prev_challenges: Vec<CamlTweedleFp>,
    prev_sgs: CamlTweedleDeeAffineVector,
) -> CamlTweedleFpPlonkProof {
    // TODO: Should we be ignoring this?!
    let _primary_input = primary_input;

    let prev: Vec<(Vec<Fp>, PolyComm<GAffine>)> = {
        if prev_challenges.len() == 0 {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.0.len();
            prev_sgs
                .0
                .iter()
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(|x| x.0)
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg.clone()],
                            shifted: None,
                        },
                    )
                })
                .collect()
        }
    };

    let map = GroupMap::<Fq>::setup();
    let proof = DlogProof::create::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&map, &auxiliary_input.as_ref().0, &index.as_ref().0, prev)
    .unwrap();

    proof.into()
}

pub fn proof_verify(
    lgr_comm: CamlTweedleDeePolyCommVector,
    index: &DlogVerifierIndex<GAffine>,
    proof: CamlTweedleFpPlonkProof,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &[(index, &lgr_comm.0, &proof.into())].to_vec())
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_verify_raw(
    lgr_comm: CamlTweedleDeePolyCommVector,
    index: CamlTweedleFpPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFpPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.as_ref().0, proof)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_verify(
    lgr_comm: CamlTweedleDeePolyCommVector,
    index: CamlTweedleFpPlonkVerifierIndexPtr,
    proof: CamlTweedleFpPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.into(), proof)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_batch_verify_raw(
    lgr_comms: Vec<CamlTweedleDeePolyCommVector>,
    indexes: Vec<CamlTweedleFpPlonkVerifierIndexRawPtr<'static>>,
    proofs: ocaml::Array<ocaml::Value>, /*Vec<CamlTweedleFpPlonkProof>*/
) -> bool {
    let proofs: Vec<DlogProof<GAffine>> =
      /* Do this up front. The rust-format proofs need to be allocated in advance for there to be a
         reference to pass to `verify`. */
      caml_vector::from_array_(proofs, |value| {
        CamlTweedleFpPlonkProof::from_value(value).into()
    });
    let group_map = GroupMap::<Fq>::setup();
    let ts: Vec<_> = indexes
        .iter()
        .zip(lgr_comms.iter())
        .zip(proofs.iter())
        .map(|((i, l), p)| (&i.as_ref().0, &l.0, p))
        .collect();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_batch_verify(
    lgr_comms: Vec<CamlTweedleDeePolyCommVector>,
    indexes: ocaml::Array<ocaml::Value>, /*Vec<CamlTweedleFpPlonkVerifierIndexPtr>*/
    proofs: ocaml::Array<ocaml::Value>,  /*Vec<CamlTweedleFpPlonkProof>*/
) -> bool {
    let proofs: Vec<DlogProof<GAffine>> =
      /* Do this up front. The rust-format proofs need to be allocated in advance for there to be a
         reference to pass to `verify`. */
      caml_vector::from_array_(proofs, |value| {
        CamlTweedleFpPlonkProof::from_value(value).into()
    });
    let indexes: Vec<DlogVerifierIndex<GAffine>> =
      /* Similarly here; allocate while deconstructing the value. */
      caml_vector::from_array_(indexes, |value| {
        CamlTweedleFpPlonkVerifierIndexPtr::from_value(value).into()
    });
    let group_map = GroupMap::<Fq>::setup();
    let ts: Vec<_> = indexes
        .iter()
        .zip(lgr_comms.iter())
        .zip(proofs.iter())
        .map(|((i, l), p)| (i, &l.0, p))
        .collect();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}
