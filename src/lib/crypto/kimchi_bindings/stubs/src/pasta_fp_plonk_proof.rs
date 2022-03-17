use crate::{
    arkworks::{CamlFp, CamlGVesta},
    field_vector::fp::CamlFpVector,
    pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr,
    pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex,
};
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use commitment_dlog::commitment::{CommitmentCurve, PolyComm};
use commitment_dlog::evaluation_proof::OpeningProof;
use groupmap::GroupMap;
use kimchi::circuits::scalars::ProofEvaluations;
use kimchi::prover::caml::CamlProverProof;
use kimchi::prover::{ProverCommitments, ProverProof};
use kimchi::prover_index::ProverIndex;
use kimchi::{circuits::polynomial::COLUMNS, verifier::batch_verify};
use mina_curves::pasta::{
    fp::Fp,
    fq::Fq,
    vesta::{Affine as GAffine, VestaParameters},
};
use oracle::{
    poseidon::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use std::convert::TryInto;

type EFqSponge = DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>;
type EFrSponge = DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>;

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_create(
    index: CamlPastaFpPlonkIndexPtr<'static>,
    witness: Vec<CamlFpVector>,
    prev_challenges: Vec<CamlFp>,
    prev_sgs: Vec<CamlGVesta>,
) -> Result<CamlProverProof<CamlGVesta, CamlFp>, ocaml::Error> {
    {
        let ptr: &mut commitment_dlog::srs::SRS<GAffine> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&index.as_ref().0.srs) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }
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
        .map_err(|_| ocaml::Error::Message("the witness should be a column of 15 vectors"))?;
    let index: &ProverIndex<GAffine> = &index.as_ref().0;

    // NB: This method is designed only to be used by tests. However, since creating a new reference will cause `drop` to be called on it once we are done with it. Since `drop` calls `caml_shutdown` internally, we *really, really* do not want to do this, but we have no other way to get at the active runtime.
    // TODO: There's actually a way to get a handle to the runtime as a function argument. Switch
    // to doing this instead.
    let runtime = unsafe { ocaml::Runtime::recover_handle() };

    // Release the runtime lock so that other threads can run using it while we generate the proof.
    runtime.releasing_runtime(|| {
        let group_map = GroupMap::<Fq>::setup();
        let proof = ProverProof::create::<EFqSponge, EFrSponge>(&group_map, witness, index, prev)
            .map_err(|e| ocaml::Error::Error(e.into()))?;
        Ok(proof.into())
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_verify(
    index: CamlPastaFpPlonkVerifierIndex,
    proof: CamlProverProof<CamlGVesta, CamlFp>,
) -> bool {
    let group_map = <GAffine as CommitmentCurve>::Map::setup();

    batch_verify::<
        GAffine,
        DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>,
    >(&group_map, &[(&index.into(), &proof.into())].to_vec())
    .is_ok()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_batch_verify(
    indexes: Vec<CamlPastaFpPlonkVerifierIndex>,
    proofs: Vec<CamlProverProof<CamlGVesta, CamlFp>>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(proofs.into_iter())
        .map(|(i, p)| (i.into(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, p)| (i, p)).collect();
    let group_map = GroupMap::<Fq>::setup();

    batch_verify::<
        GAffine,
        DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml_gen::func]
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
            lookup: None,
        },
        proof,
        evals,
        ft_eval1: Fp::one(),
        public: vec![Fp::one(), Fp::one()],
        prev_challenges,
    };

    dlogproof.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_deep_copy(
    x: CamlProverProof<CamlGVesta, CamlFp>,
) -> CamlProverProof<CamlGVesta, CamlFp> {
    x
}
