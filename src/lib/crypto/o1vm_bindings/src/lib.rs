use kimchi::curve::KimchiCurve;
use o1vm::pickles::proof::Proof;
use ocaml::{FromValue, ToValue, Value};

#[ocaml::func]
pub fn create_proof() -> Proof<KimchiCurve> {
    Proof::new()
}

#[ocaml::func]
pub fn verify_proof(proof: Proof<KimchiCurve>) -> bool {
    proof.verify()
}
