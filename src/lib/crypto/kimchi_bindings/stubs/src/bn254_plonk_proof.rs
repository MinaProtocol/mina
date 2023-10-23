use crate::{
    arkworks::{CamlBN254Fp, CamlGBN254},
    bn254_plonk_index::{CamlBN254PlonkIndexPtr, KZGProverIndex},
    field_vector::bn254::CamlBnFpVector,
};
use groupmap::GroupMap;
use kimchi::circuits::lookup::runtime_tables::{caml::CamlRuntimeTable, RuntimeTable};
use kimchi::circuits::polynomial::COLUMNS;
use kimchi::proof::{ProverProof, RecursionChallenge};
use kimchi::prover::caml::CamlBN254ProofWithPublic;
use mina_curves::bn254::{BN254Parameters, Fp, Fq, BN254};
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use poly_commitment::commitment::PolyComm;

type EFqSponge = DefaultFqSponge<BN254Parameters, PlonkSpongeConstantsKimchi>;
type EFrSponge = DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>;

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_plonk_proof_create(
    index: CamlBN254PlonkIndexPtr<'static>,
    witness: Vec<CamlBnFpVector>,
    runtime_tables: Vec<CamlRuntimeTable<CamlBN254Fp>>,
    prev_challenges: Vec<CamlBN254Fp>,
    prev_sgs: Vec<CamlGBN254>,
) -> Result<CamlBN254ProofWithPublic<CamlGBN254, CamlBN254Fp>, ocaml::Error> {
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
    let index: &KZGProverIndex = &index.as_ref().0;
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
