use crate::{
    arkworks::{CamlFq, CamlGPallas},
    field_vector::fq::CamlFqVector,
    pasta_fq_plonk_index::CamlPastaFqPlonkIndexPtr,
    pasta_fq_plonk_verifier_index::CamlPastaFqPlonkVerifierIndex,
};
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use groupmap::GroupMap;
use kimchi::{
    circuits::lookup::runtime_tables::{caml::CamlRuntimeTable, RuntimeTable},
    prover_index::ProverIndex,
};
use kimchi::{circuits::polynomial::COLUMNS, verifier::batch_verify};
use kimchi::{
    proof::{
        PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof, RecursionChallenge,
    },
    verifier::Context,
};
use kimchi::{prover::caml::CamlProofWithPublic, verifier_index::VerifierIndex};
use mina_curves::pasta::{Fp, Fq, Pallas, PallasParameters};
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use poly_commitment::commitment::{caml::CamlOpeningProof, CommitmentCurve, PolyComm};
use poly_commitment::evaluation_proof::OpeningProof;
use std::array;
use std::convert::TryInto;

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_create(
    index: CamlPastaFqPlonkIndexPtr<'static>,
    witness: Vec<CamlFqVector>,
    runtime_tables: Vec<CamlRuntimeTable<CamlFq>>,
    prev_challenges: Vec<CamlFq>,
    prev_sgs: Vec<CamlGPallas>,
) -> Result<
    CamlProofWithPublic<CamlGPallas, CamlFq, CamlOpeningProof<CamlGPallas, CamlFq>>,
    ocaml::Error,
> {
    {
        let ptr: &mut poly_commitment::srs::SRS<Pallas> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&index.as_ref().0.srs) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }
    let prev = if prev_challenges.is_empty() {
        Vec::new()
    } else {
        let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
        prev_sgs
            .into_iter()
            .map(Into::<Pallas>::into)
            .enumerate()
            .map(|(i, sg)| {
                let chals = prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                    .iter()
                    .map(Into::<Fq>::into)
                    .collect();
                let comm = PolyComm::<Pallas> {
                    unshifted: vec![sg],
                    shifted: None,
                };
                RecursionChallenge { chals, comm }
            })
            .collect()
    };

    let witness: Vec<Vec<_>> = witness.iter().map(|x| (*x.0).clone()).collect();
    let witness: [Vec<_>; COLUMNS] = witness
        .try_into()
        .expect("the witness should be a column of 15 vectors");
    let index: &ProverIndex<Pallas, OpeningProof<Pallas>> = &index.as_ref().0;

    let runtime_tables: Vec<RuntimeTable<Fq>> =
        runtime_tables.into_iter().map(Into::into).collect();

    // public input
    let public_input = witness[0][0..index.cs.public].to_vec();

    // NB: This method is designed only to be used by tests. However, since creating a new reference will cause `drop` to be called on it once we are done with it. Since `drop` calls `caml_shutdown` internally, we *really, really* do not want to do this, but we have no other way to get at the active runtime.
    // TODO: There's actually a way to get a handle to the runtime as a function argument. Switch
    // to doing this instead.
    let runtime = unsafe { ocaml::Runtime::recover_handle() };

    // Release the runtime lock so that other threads can run using it while we generate the proof.
    runtime.releasing_runtime(|| {
        let group_map = GroupMap::<Fp>::setup();
        let proof = ProverProof::create_recursive::<
            DefaultFqSponge<PallasParameters, PlonkSpongeConstantsKimchi>,
            DefaultFrSponge<Fq, PlonkSpongeConstantsKimchi>,
        >(&group_map, witness, &runtime_tables, index, prev, None)
        .map_err(|e| ocaml::Error::Error(e.into()))?;
        Ok((proof, public_input).into())
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_verify(
    index: CamlPastaFqPlonkVerifierIndex,
    proof: CamlProofWithPublic<CamlGPallas, CamlFq, CamlOpeningProof<CamlGPallas, CamlFq>>,
) -> bool {
    let group_map = <Pallas as CommitmentCurve>::Map::setup();

    let (proof, public_input) = proof.into();
    let verifier_index = index.into();
    let context = Context {
        verifier_index: &verifier_index,
        proof: &proof,
        public_input: &public_input,
    };

    batch_verify::<
        Pallas,
        DefaultFqSponge<PallasParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fq, PlonkSpongeConstantsKimchi>,
        OpeningProof<Pallas>,
    >(&group_map, &[context])
    .is_ok()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_batch_verify(
    indexes: Vec<CamlPastaFqPlonkVerifierIndex>,
    proofs: Vec<CamlProofWithPublic<CamlGPallas, CamlFq, CamlOpeningProof<CamlGPallas, CamlFq>>>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(proofs.into_iter())
        .map(|(caml_index, caml_proof)| {
            let verifier_index: VerifierIndex<Pallas, OpeningProof<Pallas>> = caml_index.into();
            let (proof, public_input): (ProverProof<Pallas, OpeningProof<Pallas>>, Vec<_>) =
                caml_proof.into();
            (verifier_index, proof, public_input)
        })
        .collect();
    let ts_ref: Vec<Context<Pallas, OpeningProof<Pallas>>> = ts
        .iter()
        .map(|(verifier_index, proof, public_input)| Context {
            verifier_index,
            proof,
            public_input,
        })
        .collect();
    let group_map = GroupMap::<Fp>::setup();

    batch_verify::<
        Pallas,
        DefaultFqSponge<PallasParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fq, PlonkSpongeConstantsKimchi>,
        OpeningProof<Pallas>,
    >(&group_map, &ts_ref)
    .is_ok()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_dummy(
) -> CamlProofWithPublic<CamlGPallas, CamlFq, CamlOpeningProof<CamlGPallas, CamlFq>> {
    fn comm() -> PolyComm<Pallas> {
        let g = Pallas::prime_subgroup_generator();
        PolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }

    let prev = RecursionChallenge {
        chals: vec![Fq::one(), Fq::one()],
        comm: comm(),
    };
    let prev_challenges = vec![prev.clone(), prev.clone(), prev];

    let g = Pallas::prime_subgroup_generator();
    let proof = OpeningProof {
        lr: vec![(g, g), (g, g), (g, g)],
        z1: Fq::one(),
        z2: Fq::one(),
        delta: g,
        sg: g,
    };
    let eval = || PointEvaluations {
        zeta: vec![Fq::one()],
        zeta_omega: vec![Fq::one()],
    };
    let evals = ProofEvaluations {
        public: Some(eval()),
        w: array_init(|_| eval()),
        coefficients: array_init(|_| eval()),
        z: eval(),
        s: array_init(|_| eval()),
        generic_selector: eval(),
        poseidon_selector: eval(),
        complete_add_selector: eval(),
        mul_selector: eval(),
        emul_selector: eval(),
        endomul_scalar_selector: eval(),
        range_check0_selector: None,
        range_check1_selector: None,
        foreign_field_add_selector: None,
        foreign_field_mul_selector: None,
        xor_selector: None,
        rot_selector: None,
        lookup_aggregation: None,
        lookup_table: None,
        lookup_sorted: array::from_fn(|_| None),
        runtime_lookup_table: None,
        runtime_lookup_table_selector: None,
        xor_lookup_selector: None,
        lookup_gate_lookup_selector: None,
        range_check_lookup_selector: None,
        foreign_field_mul_lookup_selector: None,
    };

    let public = vec![Fq::one(), Fq::one()];
    let dlogproof = ProverProof {
        commitments: ProverCommitments {
            w_comm: array_init(|_| comm()),
            z_comm: comm(),
            t_comm: comm(),
            lookup: None,
        },
        proof,
        evals,
        ft_eval1: Fq::one(),
        prev_challenges,
    };

    (dlogproof, public).into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_proof_deep_copy(
    x: CamlProofWithPublic<CamlGPallas, CamlFq, CamlOpeningProof<CamlGPallas, CamlFq>>,
) -> CamlProofWithPublic<CamlGPallas, CamlFq, CamlOpeningProof<CamlGPallas, CamlFq>> {
    x
}
