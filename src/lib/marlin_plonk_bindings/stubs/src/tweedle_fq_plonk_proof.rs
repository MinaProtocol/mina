use algebra::{
    curves::AffineCurve,
    tweedle::{
        dum::{Affine as GAffine, TweedledumParameters},
        fp::Fp,
        fq::Fq,
    },
    One,
};

use plonk_circuits::scalars::ProofEvaluations as DlogProofEvaluations;

use oracle::{
    poseidon::PlonkSpongeConstants,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};

use groupmap::GroupMap;

use commitment_dlog::commitment::{CommitmentCurve, OpeningProof, PolyComm};
use plonk_protocol_dlog::index::{Index as DlogIndex, VerifierIndex as DlogVerifierIndex};
use plonk_protocol_dlog::prover::{ProverCommitments as DlogCommitments, ProverProof as DlogProof};

use crate::tweedle_fq_plonk_index::CamlTweedleFqPlonkIndexPtr;
use crate::tweedle_fq_plonk_verifier_index::{
    CamlTweedleFqPlonkVerifierIndex, CamlTweedleFqPlonkVerifierIndexRawPtr,
};
use crate::tweedle_fq_vector::CamlTweedleFqVector;

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_create(
    index: CamlTweedleFqPlonkIndexPtr<'static>,
    primary_input: CamlTweedleFqVector,
    auxiliary_input: CamlTweedleFqVector,
    prev_challenges: Vec<Fq>,
    prev_sgs: Vec<GAffine>,
) -> DlogProof<GAffine> {
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
                            .map(|x| *x)
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

    let auxiliary_input: &Vec<Fq> = auxiliary_input.into();
    let index: &DlogIndex<GAffine> = &index.as_ref().0;

    ocaml::runtime::release_lock();

    let map = GroupMap::<Fp>::setup();
    let proof = DlogProof::create::<
        DefaultFqSponge<TweedledumParameters, PlonkSpongeConstants>,
        DefaultFrSponge<Fq, PlonkSpongeConstants>,
    >(&map, auxiliary_input, index, prev)
    .unwrap();

    ocaml::runtime::acquire_lock();

    proof
}

pub fn proof_verify(
    lgr_comm: Vec<PolyComm<GAffine>>,
    index: &DlogVerifierIndex<GAffine>,
    proof: DlogProof<GAffine>,
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
            &proof,
        )]
        .to_vec(),
    )
    .is_ok()
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_verify_raw(
    lgr_comm: Vec<PolyComm<GAffine>>,
    index: CamlTweedleFqPlonkVerifierIndexRawPtr<'static>,
    proof: DlogProof<GAffine>,
) -> bool {
    proof_verify(lgr_comm, &index.as_ref().0, proof)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_verify(
    lgr_comm: Vec<PolyComm<GAffine>>,
    index: CamlTweedleFqPlonkVerifierIndex,
    proof: DlogProof<GAffine>,
) -> bool {
    proof_verify(lgr_comm, &index.into(), proof)
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_batch_verify_raw(
    lgr_comms: Vec<Vec<PolyComm<GAffine>>>,
    indexes: Vec<CamlTweedleFqPlonkVerifierIndexRawPtr<'static>>,
    proofs: Vec<DlogProof<GAffine>>,
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
    lgr_comms: Vec<Vec<PolyComm<GAffine>>>,
    indexes: Vec<CamlTweedleFqPlonkVerifierIndex>,
    proofs: Vec<DlogProof<GAffine>>,
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

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_dummy() -> DlogProof<GAffine> {
    let g = || GAffine::prime_subgroup_generator();
    let comm = || PolyComm {
        shifted: Some(g()),
        unshifted: vec![g(), g(), g()],
    };
    DlogProof {
        prev_challenges: vec![
            (vec![Fq::one(), Fq::one()], comm()),
            (vec![Fq::one(), Fq::one()], comm()),
            (vec![Fq::one(), Fq::one()], comm()),
        ],
        proof: OpeningProof {
            lr: vec![(g(), g()), (g(), g()), (g(), g())],
            z1: Fq::one(),
            z2: Fq::one(),
            delta: g(),
            sg: g(),
        },
        commitments: DlogCommitments {
            l_comm: comm(),
            r_comm: comm(),
            o_comm: comm(),
            z_comm: comm(),
            t_comm: comm(),
        },
        public: vec![Fq::one(), Fq::one()],
        evals: {
            let evals = || vec![Fq::one(), Fq::one(), Fq::one(), Fq::one()];
            let evals = || DlogProofEvaluations {
                l: evals(),
                r: evals(),
                o: evals(),
                z: evals(),
                t: evals(),
                f: evals(),
                sigma1: evals(),
                sigma2: evals(),
            };
            [evals(), evals()]
        },
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_proof_deep_copy(x: DlogProof<GAffine>) -> DlogProof<GAffine> {
    x
}
