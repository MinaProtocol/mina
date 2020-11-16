use algebra::tweedle::{
    dum::{Affine as GAffine, TweedledumParameters},
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
use crate::tweedle_dum::{
    CamlTweedleDumAffine, CamlTweedleDumAffinePairVector, CamlTweedleDumAffineVector,
    CamlTweedleDumPolyComm, CamlTweedleDumPolyCommVector,
};
use crate::tweedle_fp::{CamlTweedleFp, CamlTweedleFpPtr};
use crate::tweedle_fq::{CamlTweedleFq, CamlTweedleFqPtr};
use crate::tweedle_fq_plonk_index::CamlTweedleFqPlonkIndexPtr;
use crate::tweedle_fq_plonk_verifier_index::{
    CamlTweedleFqPlonkVerifierIndexPtr, CamlTweedleFqPlonkVerifierIndexRawPtr,
};
use crate::tweedle_fq_vector::CamlTweedleFqVectorPtr;

pub struct CamlTweedleFqVec(pub Vec<Fq>);

unsafe impl ocaml::FromValue for CamlTweedleFqVec {
    fn from_value(value: ocaml::Value) -> Self {
        let vec: Vec<Fq> = caml_vector::from_array_(
            ocaml::FromValue::from_value(value),
            |value: ocaml::Value| CamlTweedleFq::from_value(value).0.clone(),
        );
        CamlTweedleFqVec(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleFqVec {
    fn to_value(self: Self) -> ocaml::Value {
        let vec: Vec<CamlTweedleFq> = self.0.iter().map(|x| CamlTweedleFq(*x)).collect();
        vec.to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkProofEvaluations {
    pub l: CamlTweedleFqVec,
    pub r: CamlTweedleFqVec,
    pub o: CamlTweedleFqVec,
    pub z: CamlTweedleFqVec,
    pub t: CamlTweedleFqVec,
    pub f: CamlTweedleFqVec,
    pub sigma1: CamlTweedleFqVec,
    pub sigma2: CamlTweedleFqVec,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkOpeningProof {
    pub lr: CamlTweedleDumAffinePairVector,
    pub delta: CamlTweedleDumAffine<CamlTweedleFp>,
    pub z1: CamlTweedleFq,
    pub z2: CamlTweedleFq,
    pub sg: CamlTweedleDumAffine<CamlTweedleFp>,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkMessages {
    // polynomial commitments
    pub l_comm: CamlTweedleDumPolyComm<CamlTweedleFp>,
    pub r_comm: CamlTweedleDumPolyComm<CamlTweedleFp>,
    pub o_comm: CamlTweedleDumPolyComm<CamlTweedleFp>,
    pub z_comm: CamlTweedleDumPolyComm<CamlTweedleFp>,
    pub t_comm: CamlTweedleDumPolyComm<CamlTweedleFp>,
}

pub struct CamlTweedleFqPrevChallenges(pub Vec<(Vec<Fq>, PolyComm<GAffine>)>);

unsafe impl ocaml::FromValue for CamlTweedleFqPrevChallenges {
    fn from_value(value: ocaml::Value) -> Self {
        let vec = caml_vector::from_array_(
            ocaml::FromValue::from_value(value),
            |value: ocaml::Value| {
                let (array_value, polycomm_value): (
                    ocaml::Array<ocaml::Value>,
                    CamlTweedleDumPolyComm<CamlTweedleFpPtr>,
                ) = ocaml::FromValue::from_value(value);
                let vec: Vec<Fq> = caml_vector::from_array_(array_value, |value: ocaml::Value| {
                    CamlTweedleFqPtr::from_value(value).as_ref().0
                });
                (vec, polycomm_value.into())
            },
        );
        CamlTweedleFqPrevChallenges(vec)
    }
}

unsafe impl ocaml::ToValue for CamlTweedleFqPrevChallenges {
    fn to_value(self: Self) -> ocaml::Value {
        let vec: Vec<(Vec<CamlTweedleFq>, CamlTweedleDumPolyComm<CamlTweedleFp>)> = self
            .0
            .into_iter()
            .map(|(vec, polycomm)| {
                let vec = vec.into_iter().map(|x| CamlTweedleFq(x)).collect();
                (vec, polycomm.into())
            })
            .collect();
        vec.to_value()
    }
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkProof {
    pub messages: CamlTweedleFqPlonkMessages,
    pub proof: CamlTweedleFqPlonkOpeningProof,
    pub evals: (
        CamlTweedleFqPlonkProofEvaluations,
        CamlTweedleFqPlonkProofEvaluations,
    ),
    pub public: CamlTweedleFqVec,
    pub prev_challenges: CamlTweedleFqPrevChallenges,
}

impl From<CamlTweedleFqPlonkProof> for DlogProof<GAffine> {
    fn from(x: CamlTweedleFqPlonkProof) -> Self {
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

impl From<DlogProof<GAffine>> for CamlTweedleFqPlonkProof {
    fn from(x: DlogProof<GAffine>) -> Self {
        CamlTweedleFqPlonkProof {
            prev_challenges: CamlTweedleFqPrevChallenges(x.prev_challenges),
            proof: CamlTweedleFqPlonkOpeningProof {
                lr: CamlTweedleDumAffinePairVector(x.proof.lr),
                z1: CamlTweedleFq(x.proof.z1),
                z2: CamlTweedleFq(x.proof.z2),
                delta: x.proof.delta.into(),
                sg: x.proof.sg.into(),
            },
            messages: CamlTweedleFqPlonkMessages {
                l_comm: x.l_comm.into(),
                r_comm: x.r_comm.into(),
                o_comm: x.o_comm.into(),
                z_comm: x.z_comm.into(),
                t_comm: x.t_comm.into(),
            },
            public: CamlTweedleFqVec(x.public),
            evals: {
                let [evals0, evals1] = x.evals;
                (
                    CamlTweedleFqPlonkProofEvaluations {
                        l: CamlTweedleFqVec(evals0.l),
                        r: CamlTweedleFqVec(evals0.r),
                        o: CamlTweedleFqVec(evals0.o),
                        z: CamlTweedleFqVec(evals0.z),
                        t: CamlTweedleFqVec(evals0.t),
                        f: CamlTweedleFqVec(evals0.f),
                        sigma1: CamlTweedleFqVec(evals0.sigma1),
                        sigma2: CamlTweedleFqVec(evals0.sigma2),
                    },
                    CamlTweedleFqPlonkProofEvaluations {
                        l: CamlTweedleFqVec(evals1.l),
                        r: CamlTweedleFqVec(evals1.r),
                        o: CamlTweedleFqVec(evals1.o),
                        z: CamlTweedleFqVec(evals1.z),
                        t: CamlTweedleFqVec(evals1.t),
                        f: CamlTweedleFqVec(evals1.f),
                        sigma1: CamlTweedleFqVec(evals1.sigma1),
                        sigma2: CamlTweedleFqVec(evals1.sigma2),
                    },
                )
            },
        }
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_create(
    index: CamlTweedleFqPlonkIndexPtr<'static>,
    primary_input: CamlTweedleFqVectorPtr,
    auxiliary_input: CamlTweedleFqVectorPtr,
    prev_challenges: Vec<CamlTweedleFq>,
    prev_sgs: CamlTweedleDumAffineVector,
) -> CamlTweedleFqPlonkProof {
    // TODO: Should we be ignoring this?!
    let _primary_input = primary_input;

    let prev: Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
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

    let map = GroupMap::<Fp>::setup();
    let proof = DlogProof::create::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&map, &auxiliary_input.as_ref().0, &index.as_ref().0, prev)
    .unwrap();

    proof.into()
}

pub fn proof_verify(
    lgr_comm: CamlTweedleDumPolyCommVector,
    index: &DlogVerifierIndex<GAffine>,
    proof: CamlTweedleFqPlonkProof,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&group_map, &[(index, &lgr_comm.0, &proof.into())].to_vec())
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_verify_raw(
    lgr_comm: CamlTweedleDumPolyCommVector,
    index: CamlTweedleFqPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFqPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.as_ref().0, proof)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_verify(
    lgr_comm: CamlTweedleDumPolyCommVector,
    index: CamlTweedleFqPlonkVerifierIndexPtr,
    proof: CamlTweedleFqPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.into(), proof)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_batch_verify_raw(
    lgr_comms: Vec<CamlTweedleDumPolyCommVector>,
    indexes: Vec<CamlTweedleFqPlonkVerifierIndexRawPtr<'static>>,
    proofs: ocaml::Array<ocaml::Value>, /*Vec<CamlTweedleFqPlonkProof>*/
) -> bool {
    let proofs: Vec<DlogProof<GAffine>> =
      /* Do this up front. The rust-format proofs need to be allocated in advance for there to be a
         reference to pass to `verify`. */
      caml_vector::from_array_(proofs, |value| {
        CamlTweedleFqPlonkProof::from_value(value).into()
    });
    let group_map = GroupMap::<Fp>::setup();
    let ts: Vec<_> = indexes
        .iter()
        .zip(lgr_comms.iter())
        .zip(proofs.iter())
        .map(|((i, l), p)| (&i.as_ref().0, &l.0, p))
        .collect();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_batch_verify(
    lgr_comms: Vec<CamlTweedleDumPolyCommVector>,
    indexes: ocaml::Array<ocaml::Value>, /*Vec<CamlTweedleFqPlonkVerifierIndexPtr>*/
    proofs: ocaml::Array<ocaml::Value>,  /*Vec<CamlTweedleFqPlonkProof>*/
) -> bool {
    let proofs: Vec<DlogProof<GAffine>> =
      /* Do this up front. The rust-format proofs need to be allocated in advance for there to be a
         reference to pass to `verify`. */
      caml_vector::from_array_(proofs, |value| {
        CamlTweedleFqPlonkProof::from_value(value).into()
    });
    let indexes: Vec<DlogVerifierIndex<GAffine>> =
      /* Similarly here; allocate while deconstructing the value. */
      caml_vector::from_array_(indexes, |value| {
        CamlTweedleFqPlonkVerifierIndexPtr::from_value(value).into()
    });
    let group_map = GroupMap::<Fp>::setup();
    let ts: Vec<_> = indexes
        .iter()
        .zip(lgr_comms.iter())
        .zip(proofs.iter())
        .map(|((i, l), p)| (i, &l.0, p))
        .collect();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}
