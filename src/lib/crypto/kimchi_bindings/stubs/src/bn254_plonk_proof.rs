use crate::{
    arkworks::{CamlBN254Fp, CamlFp, CamlGBN254, CamlGVesta},
    field_vector::fp::CamlFpVector,
    pasta_fp_plonk_index::CamlPastaFpPlonkIndexPtr,
};
use ark_ff::Zero;
use groupmap::GroupMap;
use kimchi::circuits::lookup::runtime_tables::caml::CamlRuntimeTable;
use kimchi::circuits::polynomial::COLUMNS;
use kimchi::circuits::polynomials::generic::testing::create_circuit;
use kimchi::circuits::polynomials::generic::testing::fill_in_witness;
use kimchi::proof::ProverProof;
use kimchi::prover::caml::CamlPastaProofWithPublic;
use kimchi::prover_index::testing::new_index_for_test_with_lookups;
use mina_curves::bn254::{BN254Parameters, Fp, BN254};
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use poly_commitment::commitment::CommitmentCurve;
use std::array;

type EFqSponge = DefaultFqSponge<BN254Parameters, PlonkSpongeConstantsKimchi>;
type EFrSponge = DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>;

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_plonk_proof_create(
    _index: CamlPastaFpPlonkIndexPtr<'static>,
    _witness: Vec<CamlFpVector>,
    _runtime_tables: Vec<CamlRuntimeTable<CamlFp>>,
    _prev_challenges: Vec<CamlFp>,
    _prev_sgs: Vec<CamlGVesta>,
) -> Result<CamlPastaProofWithPublic<CamlGBN254, CamlBN254Fp>, ocaml::Error> {
    let gates = create_circuit(0, 0);

    // create witness
    let mut witness: [Vec<Fp>; COLUMNS] = array::from_fn(|_| vec![Fp::zero(); gates.len()]);
    fill_in_witness(0, &mut witness, &[]);

    let prover =
        new_index_for_test_with_lookups::<BN254>(gates, 0, 0, vec![], Some(vec![]), false, None);
    let public_inputs = vec![];

    prover.verify(&witness, &public_inputs).unwrap();

    // NB: This method is designed only to be used by tests. However, since creating a new reference will cause `drop` to be called on it once we are done with it. Since `drop` calls `caml_shutdown` internally, we *really, really* do not want to do this, but we have no other way to get at the active runtime.
    // TODO: There's actually a way to get a handle to the runtime as a function argument. Switch
    // to doing this instead.
    let runtime = unsafe { ocaml::Runtime::recover_handle() };

    // Release the runtime lock so that other threads can run using it while we generate the proof.
    runtime.releasing_runtime(|| {
        // add the proof to the batch
        let group_map = <BN254 as CommitmentCurve>::Map::setup();

        let proof = ProverProof::create_recursive::<EFqSponge, EFrSponge>(
            &group_map,
            witness,
            &[],
            &prover,
            vec![],
            None,
        )
        .map_err(|e| ocaml::Error::Error(e.into()))?;
        Ok((proof, public_inputs).into())
    })
}
