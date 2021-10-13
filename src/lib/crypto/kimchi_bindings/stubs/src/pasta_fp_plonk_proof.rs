use crate::arkworks::{CamlFp, CamlGVesta};
use crate::pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr;
use crate::pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex;
use crate::pasta_fp_vector::CamlPastaFpVector;
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use commitment_dlog::commitment::caml::CamlPolyComm;
use commitment_dlog::commitment::{CommitmentCurve, OpeningProof, PolyComm};
use groupmap::GroupMap;
use mina_curves::pasta::{
    fp::Fp,
    fq::Fq,
    vesta::{Affine as GAffine, VestaParameters},
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
pub fn caml_pasta_fp_plonk_proof_create(
    index: CamlPastaFpPlonkIndexPtr<'static>,
    witness: Vec<CamlPastaFpVector>,
    prev_challenges: Vec<CamlFp>,
    prev_sgs: Vec<CamlGVesta>,
) -> CamlProverProof<CamlGVesta, CamlFp> {
    let prev: Vec<(Vec<Fp>, PolyComm<GAffine>)> = {
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
                            .map(Into::<Fp>::into)
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
        let group_map = GroupMap::<Fq>::setup();
        let proof = ProverProof::create::<
            DefaultFqSponge<VestaParameters, PlonkSpongeConstants15W>,
            DefaultFrSponge<Fp, PlonkSpongeConstants15W>,
        >(&group_map, &witness, index, prev)
        .unwrap();
        proof.into()
    })
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_verify(
    lgr_comm: Vec<CamlPolyComm<CamlGVesta>>,
    index: CamlPastaFpPlonkVerifierIndex,
    proof: CamlProverProof<CamlGVesta, CamlFp>,
) -> bool {
    let lgr_comm = lgr_comm.into_iter().map(|x| x.into()).collect();

    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    ProverProof::verify::<
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants15W>,
        DefaultFrSponge<Fp, PlonkSpongeConstants15W>,
    >(
        &group_map,
        &[(&index.into(), &lgr_comm, &proof.into())].to_vec(),
    )
    .is_ok()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_batch_verify(
    lgr_comms: Vec<Vec<CamlPolyComm<CamlGVesta>>>,
    indexes: Vec<CamlPastaFpPlonkVerifierIndex>,
    proofs: Vec<CamlProverProof<CamlGVesta, CamlFp>>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(lgr_comms.into_iter())
        .zip(proofs.into_iter())
        .map(|((i, l), p)| (i.into(), l.into_iter().map(Into::into).collect(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, l, p)| (i, l, p)).collect();
    let group_map = GroupMap::<Fq>::setup();

    ProverProof::<GAffine>::verify::<
        DefaultFqSponge<VestaParameters, PlonkSpongeConstants15W>,
        DefaultFrSponge<Fp, PlonkSpongeConstants15W>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_dummy() -> CamlProverProof<CamlGVesta, CamlFp> {
    fn comm() -> PolyComm<GAffine> {
        let g = GAffine::prime_subgroup_generator();
        PolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }

    let prev_challenges = vec![
        (vec![Fp::one(), Fp::one()], comm()),
        (vec![Fp::one(), Fp::one()], comm()),
        (vec![Fp::one(), Fp::one()], comm()),
    ];

    let g = GAffine::prime_subgroup_generator();
    let proof = OpeningProof {
        lr: vec![(g, g), (g, g), (g, g)],
        z1: Fp::one(),
        z2: Fp::one(),
        delta: g,
        sg: g,
    };
    let proof_evals = ProofEvaluations {
        w: array_init(|_| vec![Fp::one()]),
        z: vec![Fp::one()],
        s: array_init(|_| vec![Fp::one()]),
        lookup: None,
        generic_selector: vec![Fp::one()],
        poseidon_selector: vec![Fp::one()],
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
        ft_eval1: Fp::one(),
        public: vec![Fp::one(), Fp::one()],
        prev_challenges,
    };

    dlogproof.into()
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_deep_copy(
    x: CamlProverProof<CamlGVesta, CamlFp>,
) -> CamlProverProof<CamlGVesta, CamlFp> {
    x
}
