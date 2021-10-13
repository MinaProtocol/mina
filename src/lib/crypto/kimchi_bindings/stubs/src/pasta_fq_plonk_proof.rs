use crate::arkworks::{CamlFq, CamlGPallas};
use crate::pasta_fq_plonk_index::CamlPastaFqPlonkIndexPtr;
use crate::pasta_fq_plonk_verifier_index::CamlPastaFqPlonkVerifierIndex;
use crate::pasta_fq_vector::CamlPastaFqVector;
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use commitment_dlog::commitment::caml::CamlPolyComm;
use commitment_dlog::commitment::{CommitmentCurve, OpeningProof, PolyComm};
use groupmap::GroupMap;
use mina_curves::pasta::{
    fp::Fp,
    fq::Fq,
    pallas::{Affine as GAffine, PallasParameters},
};
use ocaml_gen::ocaml_gen;
use oracle::{
    poseidon::PlonkSpongeConstants15W,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use plonk_15_wires_circuits::nolookup::scalars::ProofEvaluations;
use plonk_15_wires_circuits::polynomial::COLUMNS;
use plonk_15_wires_protocol_dlog::index::Index;
use plonk_15_wires_protocol_dlog::prover::caml::CamlProverProof;
use plonk_15_wires_protocol_dlog::prover::{ProverCommitments, ProverProof};
use std::convert::TryInto;

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_create(
    index: CamlPastaFqPlonkIndexPtr<'static>,
    witness: Vec<CamlPastaFqVector>,
    prev_challenges: Vec<CamlFq>,
    prev_sgs: Vec<CamlGPallas>,
) -> CamlProverProof<CamlGPallas, CamlFq> {
    let prev: Vec<(Vec<Fq>, PolyComm<GAffine>)> = {
        if prev_challenges.is_empty() {
            Vec::new()
        } else {
            let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
            prev_sgs
                .into_iter()
                .map(Into::<GAffine>::into)
                .enumerate()
                .map(|(i, sg)| {
                    (
                        prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                            .iter()
                            .map(Into::<Fq>::into)
                            .collect(),
                        PolyComm::<GAffine> {
                            unshifted: vec![sg],
                            shifted: None,
                        },
                    )
                })
                .collect()
        }
    };

    let witness: Vec<Vec<_>> = witness.iter().map(|x| (*x.0).clone()).collect();
    let witness: [Vec<_>; COLUMNS] = witness
        .try_into()
        .expect("the witness should be a column of 15 vectors");
    let index: &Index<GAffine> = &index.as_ref().0;

    // NB: This method is designed only to be used by tests. However, since creating a new reference will cause `drop` to be called on it once we are done with it. Since `drop` calls `caml_shutdown` internally, we *really, really* do not want to do this, but we have no other way to get at the active runtime.
    let runtime = unsafe { ocaml::Runtime::recover_handle() };

    // Release the runtime lock so that other threads can run using it while we generate the proof.
    runtime.releasing_runtime(|| {
        let group_map = GroupMap::<Fp>::setup();
        let proof = ProverProof::create::<
            DefaultFqSponge<PallasParameters, PlonkSpongeConstants15W>,
            DefaultFrSponge<Fq, PlonkSpongeConstants15W>,
        >(&group_map, &witness, index, prev)
        .unwrap();
        proof.into()
    })
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_verify(
    lgr_comm: Vec<CamlPolyComm<CamlGPallas>>,
    index: CamlPastaFqPlonkVerifierIndex,
    proof: CamlProverProof<CamlGPallas, CamlFq>,
) -> bool {
    let lgr_comm = lgr_comm.into_iter().map(|x| x.into()).collect();

    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    ProverProof::verify::<
        DefaultFqSponge<PallasParameters, PlonkSpongeConstants15W>,
        DefaultFrSponge<Fq, PlonkSpongeConstants15W>,
    >(
        &group_map,
        &[(&index.into(), &lgr_comm, &proof.into())].to_vec(),
    )
    .is_ok()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_batch_verify(
    lgr_comms: Vec<Vec<CamlPolyComm<CamlGPallas>>>,
    indexes: Vec<CamlPastaFqPlonkVerifierIndex>,
    proofs: Vec<CamlProverProof<CamlGPallas, CamlFq>>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(lgr_comms.into_iter())
        .zip(proofs.into_iter())
        .map(|((i, l), p)| (i.into(), l.into_iter().map(Into::into).collect(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, l, p)| (i, l, p)).collect();
    let group_map = GroupMap::<Fp>::setup();

    ProverProof::<GAffine>::verify::<
        DefaultFqSponge<PallasParameters, PlonkSpongeConstants15W>,
        DefaultFrSponge<Fq, PlonkSpongeConstants15W>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_dummy() -> CamlProverProof<CamlGPallas, CamlFq> {
    fn comm() -> PolyComm<GAffine> {
        let g = GAffine::prime_subgroup_generator();
        PolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }

    let prev_challenges = vec![
        (vec![Fq::one(), Fq::one()], comm()),
        (vec![Fq::one(), Fq::one()], comm()),
        (vec![Fq::one(), Fq::one()], comm()),
    ];

    let g = GAffine::prime_subgroup_generator();
    let proof = OpeningProof {
        lr: vec![(g, g), (g, g), (g, g)],
        z1: Fq::one(),
        z2: Fq::one(),
        delta: g,
        sg: g,
    };
    let proof_evals = ProofEvaluations {
        w: array_init(|_| vec![Fq::one()]),
        z: vec![Fq::one()],
        s: array_init(|_| vec![Fq::one()]),
        lookup: None,
        generic_selector: vec![Fq::one()],
        poseidon_selector: vec![Fq::one()],
    };
    let evals = [proof_evals.clone(), proof_evals];

    let dlogproof = ProverProof {
        commitments: ProverCommitments {
            w_comm: array_init(|_| comm()),
            z_comm: comm(),
            t_comm: comm(),
        },
        proof,
        evals,
        ft_eval1: Fq::one(),
        public: vec![Fq::one(), Fq::one()],
        prev_challenges,
    };

    dlogproof.into()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_deep_copy(
    x: CamlProverProof<CamlGPallas, CamlFq>,
) -> CamlProverProof<CamlGPallas, CamlFq> {
    x
}
