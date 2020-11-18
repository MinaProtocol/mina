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

use crate::tweedle_dee::{CamlTweedleDeeAffine, CamlTweedleDeePolyComm};
use crate::tweedle_fp::CamlTweedleFp;
use crate::tweedle_fp_plonk_index::CamlTweedleFpPlonkIndexPtr;
use crate::tweedle_fp_plonk_verifier_index::{
    CamlTweedleFpPlonkVerifierIndexPtr, CamlTweedleFpPlonkVerifierIndexRawPtr,
};
use crate::tweedle_fp_vector::CamlTweedleFpVectorPtr;
use crate::tweedle_fq::CamlTweedleFq;

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkProofEvaluations {
    pub l: Vec<CamlTweedleFp>,
    pub r: Vec<CamlTweedleFp>,
    pub o: Vec<CamlTweedleFp>,
    pub z: Vec<CamlTweedleFp>,
    pub t: Vec<CamlTweedleFp>,
    pub f: Vec<CamlTweedleFp>,
    pub sigma1: Vec<CamlTweedleFp>,
    pub sigma2: Vec<CamlTweedleFp>,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkOpeningProof {
    pub lr: Vec<(
        CamlTweedleDeeAffine<CamlTweedleFq>,
        CamlTweedleDeeAffine<CamlTweedleFq>,
    )>,
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

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlTweedleFpPlonkProof {
    pub messages: CamlTweedleFpPlonkMessages,
    pub proof: CamlTweedleFpPlonkOpeningProof,
    pub evals: (
        CamlTweedleFpPlonkProofEvaluations,
        CamlTweedleFpPlonkProofEvaluations,
    ),
    pub public: Vec<CamlTweedleFp>,
    pub prev_challenges: Vec<(Vec<CamlTweedleFp>, CamlTweedleDeePolyComm<CamlTweedleFq>)>,
}

impl From<CamlTweedleFpPlonkProof> for DlogProof<GAffine> {
    fn from(x: CamlTweedleFpPlonkProof) -> Self {
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

impl From<DlogProof<GAffine>> for CamlTweedleFpPlonkProof {
    fn from(x: DlogProof<GAffine>) -> Self {
        CamlTweedleFpPlonkProof {
            prev_challenges: x
                .prev_challenges
                .into_iter()
                .map(|(x, y)| (x.into_iter().map(From::from).collect(), y.into()))
                .collect(),
            proof: CamlTweedleFpPlonkOpeningProof {
                lr: x
                    .proof
                    .lr
                    .into_iter()
                    .map(|(x, y)| (x.into(), y.into()))
                    .collect(),
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
            public: x.public.into_iter().map(From::from).collect(),
            evals: {
                let [evals0, evals1] = x.evals;
                (
                    CamlTweedleFpPlonkProofEvaluations {
                        l: evals0.l.into_iter().map(From::from).collect(),
                        r: evals0.r.into_iter().map(From::from).collect(),
                        o: evals0.o.into_iter().map(From::from).collect(),
                        z: evals0.z.into_iter().map(From::from).collect(),
                        t: evals0.t.into_iter().map(From::from).collect(),
                        f: evals0.f.into_iter().map(From::from).collect(),
                        sigma1: evals0.sigma1.into_iter().map(From::from).collect(),
                        sigma2: evals0.sigma2.into_iter().map(From::from).collect(),
                    },
                    CamlTweedleFpPlonkProofEvaluations {
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
pub fn caml_tweedle_fp_plonk_proof_create(
    index: CamlTweedleFpPlonkIndexPtr<'static>,
    primary_input: CamlTweedleFpVectorPtr,
    auxiliary_input: CamlTweedleFpVectorPtr,
    prev_challenges: Vec<CamlTweedleFp>,
    prev_sgs: Vec<CamlTweedleDeeAffine<CamlTweedleFq>>,
) -> CamlTweedleFpPlonkProof {
    // TODO: Should we be ignoring this?!
    let _primary_input = primary_input;

    let prev: Vec<(Vec<Fp>, PolyComm<GAffine>)> = {
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

    let map = GroupMap::<Fq>::setup();
    let proof = DlogProof::create::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&map, &auxiliary_input.as_ref().0, &index.as_ref().0, prev)
    .unwrap();

    proof.into()
}

pub fn proof_verify(
    lgr_comm: Vec<CamlTweedleDeePolyComm<CamlTweedleFq>>,
    index: &DlogVerifierIndex<GAffine>,
    proof: CamlTweedleFpPlonkProof,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
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
pub fn caml_tweedle_fp_plonk_proof_verify_raw(
    lgr_comm: Vec<CamlTweedleDeePolyComm<CamlTweedleFq>>,
    index: CamlTweedleFpPlonkVerifierIndexRawPtr<'static>,
    proof: CamlTweedleFpPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.as_ref().0, proof)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_verify(
    lgr_comm: Vec<CamlTweedleDeePolyComm<CamlTweedleFq>>,
    index: CamlTweedleFpPlonkVerifierIndexPtr,
    proof: CamlTweedleFpPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.into(), proof)
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_batch_verify_raw(
    lgr_comms: Vec<Vec<CamlTweedleDeePolyComm<CamlTweedleFq>>>,
    indexes: Vec<CamlTweedleFpPlonkVerifierIndexRawPtr<'static>>,
    proofs: Vec<CamlTweedleFpPlonkProof>,
) -> bool {
    let proofs: Vec<DlogProof<GAffine>> = proofs.into_iter().map(From::from).collect();
    let lgr_comms: Vec<Vec<PolyComm<GAffine>>> = lgr_comms
        .into_iter()
        .map(|x| x.into_iter().map(From::from).collect())
        .collect();
    let group_map = GroupMap::<Fq>::setup();
    let ts: Vec<_> = indexes
        .iter()
        .zip(lgr_comms.iter())
        .zip(proofs.iter())
        .map(|((i, l), p)| (&i.as_ref().0, l, p))
        .collect();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fp_plonk_proof_batch_verify(
    lgr_comms: Vec<Vec<CamlTweedleDeePolyComm<CamlTweedleFq>>>,
    indexes: Vec<CamlTweedleFpPlonkVerifierIndexPtr>,
    proofs: Vec<CamlTweedleFpPlonkProof>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(lgr_comms.into_iter())
        .zip(proofs.into_iter())
        .map(|((i, l), p)| (i.into(), l.into_iter().map(From::from).collect(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, l, p)| (i, l, p)).collect();
    let group_map = GroupMap::<Fq>::setup();

    DlogProof::<GAffine>::verify::<
        DefaultFqSponge<TweedledeeParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}
