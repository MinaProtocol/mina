use kimchi::prover_index::ProverIndex;
use mina_curves::pasta::Vesta;
use poly_commitment::evaluation_proof::OpeningProof;

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
pub struct BN254PlonkIndex(pub Box<ProverIndex<Vesta, OpeningProof<Vesta>>>);
pub type BN254PlonkIndexPtr<'a> = ocaml::Pointer<'a, BN254PlonkIndex>;
