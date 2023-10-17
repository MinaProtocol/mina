use crate::{
    arkworks::{CamlFp, CamlGVesta},
    field_vector::fp::CamlFpVector,
    pasta_fp_plonk_index::{CamlPastaFpPlonkIndex, CamlPastaFpPlonkIndexPtr},
    pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex,
    srs::fp::CamlFpSrs,
};
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use groupmap::GroupMap;
use kimchi::verifier::verify;
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
use mina_curves::pasta::{Fp, Fq, VestaParameters};
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use poly_commitment::commitment::{CommitmentCurve, PolyComm};
use poly_commitment::evaluation_proof::OpeningProof;
use std::array;
use std::convert::TryInto;

type BN254 = GroupAffine<ark_bn254::g1::Parameters>;
type EFqSponge = DefaultFqSponge<ark_bn254::g1::Parameters, PlonkSpongeConstantsKimchi>;
type EFrSponge = DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>;

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_plonk_proof_create(
    index: CamlPastaFpPlonkIndexPtr<'static>,
    witness: Vec<CamlFpVector>,
    runtime_tables: Vec<CamlRuntimeTable<CamlFp>>,
    prev_challenges: Vec<CamlFp>,
    prev_sgs: Vec<CamlGVesta>,
) -> Result<CamlProofWithPublic<CamlGVesta, CamlFp>, ocaml::Error> {
    {
        let ptr: &mut poly_commitment::srs::SRS<BN254> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&index.as_ref().0.srs) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }
    let prev = if prev_challenges.is_empty() {
        Vec::new()
    } else {
        let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
        prev_sgs
            .into_iter()
            .map(Into::<BN254>::into)
            .enumerate()
            .map(|(i, sg)| {
                let chals = prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                    .iter()
                    .map(Into::<Fp>::into)
                    .collect();
                let comm = PolyComm::<BN254> {
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
        .map_err(|_| ocaml::Error::Message("the witness should be a column of 15 vectors"))?;
    let index: &ProverIndex<BN254, OpeningProof<BN254>> = &index.as_ref().0;
    let runtime_tables: Vec<RuntimeTable<Fp>> =
        runtime_tables.into_iter().map(Into::into).collect();

    // public input
    let public_input = witness[0][0..index.cs.public].to_vec();

    // NB: This method is designed only to be used by tests. However, since creating a new reference will cause `drop` to be called on it once we are done with it. Since `drop` calls `caml_shutdown` internally, we *really, really* do not want to do this, but we have no other way to get at the active runtime.
    // TODO: There's actually a way to get a handle to the runtime as a function argument. Switch
    // to doing this instead.
    let runtime = unsafe { ocaml::Runtime::recover_handle() };

    // Release the runtime lock so that other threads can run using it while we generate the proof.
    runtime.releasing_runtime(|| {
        let group_map = GroupMap::<Fq>::setup();
        let proof = ProverProof::create_recursive::<EFqSponge, EFrSponge>(
            &group_map,
            witness,
            &runtime_tables,
            index,
            prev,
            None,
        )
        .map_err(|e| ocaml::Error::Error(e.into()))?;
        Ok((proof, public_input).into())
    })
}
