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

use crate::tweedle_dum::{CamlTweedleDumAffine, CamlTweedleDumPolyComm};
use crate::tweedle_fp::CamlTweedleFp;
use crate::tweedle_fq::CamlTweedleFq;
use crate::tweedle_fq_plonk_index::CamlTweedleFqPlonkIndexPtr;
use crate::tweedle_fq_plonk_verifier_index::{
    CamlTweedleFqPlonkVerifierIndexPtr, CamlTweedleFqPlonkVerifierIndexRawPtr,
};
use crate::tweedle_fq_vector::CamlTweedleFqVectorPtr;

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkProofEvaluations {
    pub l: Vec<CamlTweedleFq>,
    pub r: Vec<CamlTweedleFq>,
    pub o: Vec<CamlTweedleFq>,
    pub z: Vec<CamlTweedleFq>,
    pub t: Vec<CamlTweedleFq>,
    pub f: Vec<CamlTweedleFq>,
    pub sigma1: Vec<CamlTweedleFq>,
    pub sigma2: Vec<CamlTweedleFq>,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkOpeningProof {
    pub lr: Vec<(
        CamlTweedleDumAffine<CamlTweedleFp>,
        CamlTweedleDumAffine<CamlTweedleFp>,
    )>,
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

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFqPlonkProof {
    pub messages: CamlTweedleFqPlonkMessages,
    pub proof: CamlTweedleFqPlonkOpeningProof,
    pub evals: (
        CamlTweedleFqPlonkProofEvaluations,
        CamlTweedleFqPlonkProofEvaluations,
    ),
    pub public: Vec<CamlTweedleFq>,
    pub prev_challenges: Vec<(Vec<CamlTweedleFq>, CamlTweedleDumPolyComm<CamlTweedleFp>)>,
}

impl From<CamlTweedleFqPlonkProof> for DlogProof<GAffine> {
    fn from(x: CamlTweedleFqPlonkProof) -> Self {
        DlogProof {
            prev_challenges: x
                .prev_challenges
                .into_iter()
                .map(|(x, y)| (x.into_iter().map(From::from).collect(), y.into()))
                .collect(),
            proof: OpeningProof {
                lr: x
                    .proof
                    .lr
                    .into_iter()
                    .map(|(x, y)| (x.into(), y.into()))
                    .collect(),
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
            public: x.public.into_iter().map(From::from).collect(),
            evals: {
                let (evals0, evals1) = x.evals;
                [
                    DlogProofEvaluations {
                        l: evals0.l.into_iter().map(From::from).collect(),
                        r: evals0.r.into_iter().map(From::from).collect(),
                        o: evals0.o.into_iter().map(From::from).collect(),
                        z: evals0.z.into_iter().map(From::from).collect(),
                        t: evals0.t.into_iter().map(From::from).collect(),
                        f: evals0.f.into_iter().map(From::from).collect(),
                        sigma1: evals0.sigma1.into_iter().map(From::from).collect(),
                        sigma2: evals0.sigma2.into_iter().map(From::from).collect(),
                    },
                    DlogProofEvaluations {
                        l: evals1.l.into_iter().map(From::from).collect(),
                        r: evals1.r.into_iter().map(From::from).collect(),
                        o: evals1.o.into_iter().map(From::from).collect(),
                        z: evals1.z.into_iter().map(From::from).collect(),
                        t: evals1.t.into_iter().map(From::from).collect(),
                        f: evals1.f.into_iter().map(From::from).collect(),
                        sigma1: evals1.sigma1.into_iter().map(From::from).collect(),
                        sigma2: evals1.sigma2.into_iter().map(From::from).collect(),
                    },
                ]
            },
        }
    }
}

impl From<DlogProof<GAffine>> for CamlTweedleFqPlonkProof {
    fn from(x: DlogProof<GAffine>) -> Self {
        CamlTweedleFqPlonkProof {
            prev_challenges: x
                .prev_challenges
                .into_iter()
                .map(|(x, y)| (x.into_iter().map(From::from).collect(), y.into()))
                .collect(),
            proof: CamlTweedleFqPlonkOpeningProof {
                lr: x
                    .proof
                    .lr
                    .into_iter()
                    .map(|(x, y)| (x.into(), y.into()))
                    .collect(),
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
            public: x.public.into_iter().map(From::from).collect(),
            evals: {
                let [evals0, evals1] = x.evals;
                (
                    CamlTweedleFqPlonkProofEvaluations {
                        l: evals0.l.into_iter().map(From::from).collect(),
                        r: evals0.r.into_iter().map(From::from).collect(),
                        o: evals0.o.into_iter().map(From::from).collect(),
                        z: evals0.z.into_iter().map(From::from).collect(),
                        t: evals0.t.into_iter().map(From::from).collect(),
                        f: evals0.f.into_iter().map(From::from).collect(),
                        sigma1: evals0.sigma1.into_iter().map(From::from).collect(),
                        sigma2: evals0.sigma2.into_iter().map(From::from).collect(),
                    },
                    CamlTweedleFqPlonkProofEvaluations {
                        l: evals1.l.into_iter().map(From::from).collect(),
                        r: evals1.r.into_iter().map(From::from).collect(),
                        o: evals1.o.into_iter().map(From::from).collect(),
                        z: evals1.z.into_iter().map(From::from).collect(),
                        t: evals1.t.into_iter().map(From::from).collect(),
                        f: evals1.f.into_iter().map(From::from).collect(),
                        sigma1: evals1.sigma1.into_iter().map(From::from).collect(),
                        sigma2: evals1.sigma2.into_iter().map(From::from).collect(),
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
    prev_sgs: Vec<CamlTweedleDumAffine<CamlTweedleFp>>,
) -> CamlTweedleFqPlonkProof {
    // TODO: Should we be ignoring this?!
    let _primary_input = primary_input;

    let prev: Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
        if prev_challenges.len() == 0 {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs
                .into_iter()
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(|x| x.0)
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg.into()],
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
    lgr_comm: Vec<CamlTweedleDumPolyComm<CamlTweedleFp>>,
    index: &DlogVerifierIndex<GAffine>,
    proof: CamlTweedleFqPlonkProof,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(
        &group_map,
        &[(
            index,
            &lgr_comm.into_iter().map(From::from).collect(),
            &proof.into(),
        )]
        .to_vec(),
    )
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_verify_raw(
    lgr_comm: Vec<CamlTweedleDumPolyComm<CamlTweedleFp>>,
    index: CamlTweedleFqPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFqPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.as_ref().0, proof)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_verify(
    lgr_comm: Vec<CamlTweedleDumPolyComm<CamlTweedleFp>>,
    index: CamlTweedleFqPlonkVerifierIndexPtr,
    proof: CamlTweedleFqPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.into(), proof)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_batch_verify_raw(
    lgr_comms: Vec<Vec<CamlTweedleDumPolyComm<CamlTweedleFp>>>,
    indexes: Vec<CamlTweedleFqPlonkVerifierIndexRawPtr<'static>>,
    proofs: Vec<CamlTweedleFqPlonkProof>,
) -> bool {
    let proofs: Vec<DlogProof<GAffine>> = proofs.into_iter().map(From::from).collect();
    let lgr_comms: Vec<Vec<PolyComm<GAffine>>> = lgr_comms
        .into_iter()
        .map(|x| x.into_iter().map(From::from).collect())
        .collect();
    let group_map = GroupMap::<Fp>::setup();
    let ts: Vec<_> = indexes
        .iter()
        .zip(lgr_comms.iter())
        .zip(proofs.iter())
        .map(|((i, l), p)| (&i.as_ref().0, l, p))
        .collect();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_batch_verify(
    lgr_comms: Vec<Vec<CamlTweedleDumPolyComm<CamlTweedleFp>>>,
    indexes: Vec<CamlTweedleFqPlonkVerifierIndexPtr>,
    proofs: Vec<CamlTweedleFqPlonkProof>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(lgr_comms.into_iter())
        .zip(proofs.into_iter())
        .map(|((i, l), p)| (i.into(), l.into_iter().map(From::from).collect(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, l, p)| (i, l, p)).collect();
    let group_map = GroupMap::<Fp>::setup();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}
