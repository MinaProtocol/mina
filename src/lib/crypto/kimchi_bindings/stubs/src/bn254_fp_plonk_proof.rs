use crate::{
    arkworks::CamlBn254Fp, bn254_fp_plonk_index::CamlBn254FpPlonkIndexPtr,
    field_vector::bn254_fp::CamlBn254FpVector,
};
use ark_bn254::Parameters;
use ark_ec::bn::Bn;
use groupmap::GroupMap;
use kimchi::circuits::polynomial::COLUMNS;
use kimchi::keccak_sponge::Keccak256FqSponge;
use kimchi::proof::ProverProof;
use kimchi::{
    circuits::lookup::runtime_tables::{caml::CamlRuntimeTable, RuntimeTable},
    keccak_sponge::Keccak256FrSponge,
    prover_index::ProverIndex,
};
use mina_curves::bn254::{Bn254, Fp, Fq};
use poly_commitment::pairing_proof::PairingProof;
use poly_commitment::srs::SRS;
use std::convert::TryInto;

type BaseSponge = Keccak256FqSponge<Fq, ark_bn254::G1Affine, Fp>;
type ScalarSponge = Keccak256FrSponge<Fp>;

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_proof_create(
    index: CamlBn254FpPlonkIndexPtr<'static>,
    witness: Vec<CamlBn254FpVector>,
    runtime_tables: Vec<CamlRuntimeTable<CamlBn254Fp>>,
) -> Result<String, ocaml::Error> {
    {
        let ptr: &mut SRS<Bn254> =
            unsafe { &mut *((&index.as_ref().0.srs.full_srs as *const SRS<Bn254>) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }

    let witness: Vec<Vec<_>> = witness.iter().map(|x| (*x.0).clone()).collect();
    let witness: [Vec<_>; COLUMNS] = witness
        .try_into()
        .map_err(|_| ocaml::Error::Message("the witness should be a column of 15 vectors"))?;
    let index: &ProverIndex<Bn254, PairingProof<Bn<Parameters>>> = &index.as_ref().0;
    let runtime_tables: Vec<RuntimeTable<Fp>> =
        runtime_tables.into_iter().map(Into::into).collect();

    // NB: This method is designed only to be used by tests. However, since creating a new reference will cause `drop` to be called on it once we are done with it. Since `drop` calls `caml_shutdown` internally, we *really, really* do not want to do this, but we have no other way to get at the active runtime.
    // TODO: There's actually a way to get a handle to the runtime as a function argument. Switch
    // to doing this instead.
    let runtime = unsafe { ocaml::Runtime::recover_handle() };

    // Release the runtime lock so that other threads can run using it while we generate the proof.
    runtime.releasing_runtime(|| {
        let group_map = GroupMap::<Fq>::setup();
        let proof = ProverProof::create_recursive::<BaseSponge, ScalarSponge>(
            &group_map,
            witness,
            &runtime_tables,
            index,
            Vec::new(),
            None,
        )
        .map_err(|e| ocaml::Error::Error(e.into()))?;

        let serialized_proof = serde_json::to_string(&proof)
            .map_err(|_| ocaml::Error::Message("Could not serialize proof"))?;
        Ok(serialized_proof)
    })
}
