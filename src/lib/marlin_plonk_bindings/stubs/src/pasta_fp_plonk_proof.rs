use algebra::pasta::{
    vesta::{Affine as GAffine, VestaParameters},
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
use plonk_protocol_dlog::index::{Index as DlogIndex, VerifierIndex as DlogVerifierIndex};
use plonk_protocol_dlog::prover::ProverProof as DlogProof;

use crate::pasta_vesta::{CamlPastaVestaAffine, CamlPastaVestaPolyComm};
use crate::pasta_fp::CamlPastaFp;
use crate::pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr;
use crate::pasta_fp_plonk_verifier_index::{
    CamlPastaFpPlonkVerifierIndexPtr, CamlPastaFpPlonkVerifierIndexRawPtr,
};
use crate::pasta_fp_vector::CamlPastaFpVector;
use crate::pasta_fq::CamlPastaFq;

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFpPlonkProofEvaluations {
    pub l: Vec<CamlPastaFp>,
    pub r: Vec<CamlPastaFp>,
    pub o: Vec<CamlPastaFp>,
    pub z: Vec<CamlPastaFp>,
    pub t: Vec<CamlPastaFp>,
    pub f: Vec<CamlPastaFp>,
    pub sigma1: Vec<CamlPastaFp>,
    pub sigma2: Vec<CamlPastaFp>,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFpPlonkOpeningProof {
    pub lr: Vec<(
        CamlPastaVestaAffine<CamlPastaFq>,
        CamlPastaVestaAffine<CamlPastaFq>,
    )>,
    pub delta: CamlPastaVestaAffine<CamlPastaFq>,
    pub z1: CamlPastaFp,
    pub z2: CamlPastaFp,
    pub sg: CamlPastaVestaAffine<CamlPastaFq>,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFpPlonkMessages {
    // polynomial commitments
    pub l_comm: CamlPastaVestaPolyComm<CamlPastaFq>,
    pub r_comm: CamlPastaVestaPolyComm<CamlPastaFq>,
    pub o_comm: CamlPastaVestaPolyComm<CamlPastaFq>,
    pub z_comm: CamlPastaVestaPolyComm<CamlPastaFq>,
    pub t_comm: CamlPastaVestaPolyComm<CamlPastaFq>,
}

#[derive(ocaml::ToValue, ocaml::FromValue)]
pub struct CamlPastaFpPlonkProof {
    pub messages: CamlPastaFpPlonkMessages,
    pub proof: CamlPastaFpPlonkOpeningProof,
    pub evals: (
        CamlPastaFpPlonkProofEvaluations,
        CamlPastaFpPlonkProofEvaluations,
    ),
    pub public: Vec<CamlPastaFp>,
    pub prev_challenges: Vec<(Vec<CamlPastaFp>, CamlPastaVestaPolyComm<CamlPastaFq>)>,
}

impl From<CamlPastaFpPlonkProof> for DlogProof<GAffine> {
    fn from(x: CamlPastaFpPlonkProof) -> Self {
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

impl From<DlogProof<GAffine>> for CamlPastaFpPlonkProof {
    fn from(x: DlogProof<GAffine>) -> Self {
        CamlPastaFpPlonkProof {
            prev_challenges: x
                .prev_challenges
                .into_iter()
                .map(|(x, y)| (x.into_iter().map(From::from).collect(), y.into()))
                .collect(),
            proof: CamlPastaFpPlonkOpeningProof {
                lr: x
                    .proof
                    .lr
                    .into_iter()
                    .map(|(x, y)| (x.into(), y.into()))
                    .collect(),
                z1: CamlPastaFp(x.proof.z1),
                z2: CamlPastaFp(x.proof.z2),
                delta: x.proof.delta.into(),
                sg: x.proof.sg.into(),
            },
            messages: CamlPastaFpPlonkMessages {
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
                    CamlPastaFpPlonkProofEvaluations {
                        l: evals0.l.into_iter().map(From::from).collect(),
                        r: evals0.r.into_iter().map(From::from).collect(),
                        o: evals0.o.into_iter().map(From::from).collect(),
                        z: evals0.z.into_iter().map(From::from).collect(),
                        t: evals0.t.into_iter().map(From::from).collect(),
                        f: evals0.f.into_iter().map(From::from).collect(),
                        sigma1: evals0.sigma1.into_iter().map(From::from).collect(),
                        sigma2: evals0.sigma2.into_iter().map(From::from).collect(),
                    },
                    CamlPastaFpPlonkProofEvaluations {
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
pub fn caml_pasta_fp_plonk_proof_create(
    index: CamlPastaFpPlonkIndexPtr<'static>,
    primary_input: CamlPastaFpVector,
    auxiliary_input: CamlPastaFpVector,
    prev_challenges: Vec<CamlPastaFp>,
    prev_sgs: Vec<CamlPastaVestaAffine<CamlPastaFq>>,
) -> CamlPastaFpPlonkProof {
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

    let auxiliary_input: &Vec<Fp> = auxiliary_input.into();
    let index: &DlogIndex<GAffine> = &index.as_ref().0;

    ocaml::runtime::release_lock();

    let map = GroupMap::<Fq>::setup();
    let proof = DlogProof::create::<
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&map, auxiliary_input, index, prev)
    .unwrap();

    ocaml::runtime::acquire_lock();

    proof.into()
}

pub fn proof_verify(
    lgr_comm: Vec<CamlPastaVestaPolyComm<CamlPastaFq>>,
    index: &DlogVerifierIndex<GAffine>,
    proof: CamlPastaFpPlonkProof,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    DlogProof::verify::<
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants>,
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
pub fn caml_pasta_fp_plonk_proof_verify_raw(
    lgr_comm: Vec<CamlPastaVestaPolyComm<CamlPastaFq>>,
    index: CamlPastaFpPlonkVerifierIndexRawPtr<'static>,
    proof: CamlPastaFpPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.as_ref().0, proof)
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_verify(
    lgr_comm: Vec<CamlPastaVestaPolyComm<CamlPastaFq>>,
    index: CamlPastaFpPlonkVerifierIndexPtr,
    proof: CamlPastaFpPlonkProof,
) -> bool {
    proof_verify(lgr_comm, &index.into(), proof)
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_batch_verify_raw(
    lgr_comms: Vec<Vec<CamlPastaVestaPolyComm<CamlPastaFq>>>,
    indexes: Vec<CamlPastaFpPlonkVerifierIndexRawPtr<'static>>,
    proofs: Vec<CamlPastaFpPlonkProof>,
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
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_batch_verify(
    lgr_comms: Vec<Vec<CamlPastaVestaPolyComm<CamlPastaFq>>>,
    indexes: Vec<CamlPastaFpPlonkVerifierIndexPtr>,
    proofs: Vec<CamlPastaFpPlonkProof>,
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
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fp, PlonkSpongeConstants>,
    >(&group_map, &ts)
    .is_ok()
}
