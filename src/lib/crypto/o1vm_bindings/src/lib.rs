use kimchi::curve::KimchiCurve;
use mina_curves::pasta::{Pallas, Vesta};
use o1vm::pickles::proof::Proof;
use ocaml::{FromValue, ToValue, Value};

#[ocaml::func]
pub fn create_proof_vesta() -> Proof<Vesta> {
    Proof::new()
}

#[ocaml::func]
pub fn verify_proof_vesta(proof: Proof<Vesta>) -> bool {
    proof.verify()
}
