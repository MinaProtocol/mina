use kimchi::snarky::{constants::Constants, constraint_system::SnarkyConstraintSystem};
use mina_curves::pasta::{Fp, Fq, Pallas, Vesta};

use crate::{
    field_vector::{fp::CamlFpVector, fq::CamlFqVector},
    gate_vector::{fp::CamlPastaFpPlonkGateVector, fq::CamlPastaFqPlonkGateVector},
};

//
// Wrapper types
//

impl_custom!(CamlFpCS, SnarkyConstraintSystem<Fp>);
impl_custom!(CamlFqCS, SnarkyConstraintSystem<Fq>);

//
// Methods
//

// Fp
impl_functions! {
    pub fn fp_cs_create() -> CamlFpCS {
        let constants = Constants::new::<Vesta>();
        CamlFpCS(SnarkyConstraintSystem::create(constants))
    }

    pub fn fp_cs_add_constraint(label: Option<String>, mut cs: ocaml::Pointer<CamlFpCS>, constraint: usize) {
        unimplemented!();
    }

    pub fn fp_cs_finalize(mut cs: ocaml::Pointer<CamlFpCS>) {
        cs.as_mut().0.finalize();
    }

    pub fn fp_cs_digest(cs: &CamlFpCS) -> [u8; 32] {
        cs.digest()
    }

    pub fn fp_cs_get_rows_len(cs: &CamlFpCS) -> usize {
        cs.get_rows_len()
    }

    pub fn fp_cs_set_auxiliary_input_size(mut cs: ocaml::Pointer<CamlFpCS>, size: usize) {
        cs.as_mut().0.set_auxiliary_input_size(size);
    }

    pub fn fp_cs_set_primary_input_size(mut cs: ocaml::Pointer<CamlFpCS>, size: usize) {
        cs.as_mut().0.set_primary_input_size(size);
    }

    pub fn fp_cs_get_primary_input_size(cs: &CamlFpCS) -> usize {
        cs.get_primary_input_size()
    }

    pub fn fp_cs_get_prev_challenges(cs: &CamlFpCS) -> Option<usize> {
        cs.get_prev_challenges()
    }

    pub fn fp_cs_set_prev_challenges(mut cs: ocaml::Pointer<CamlFpCS>, num: usize) {
        cs.as_mut().0.set_prev_challenges(num);
    }

    pub fn fp_cs_finalize_and_get_gates(mut cs: ocaml::Pointer<CamlFpCS>) -> CamlPastaFpPlonkGateVector {
        CamlPastaFpPlonkGateVector(cs.as_mut().0.finalize_and_get_gates().clone())
    }

    pub fn fp_cs_compute_witness(mut cs: ocaml::Pointer<CamlFpCS>, primary: ocaml::Pointer<CamlFpVector>, auxiliary: ocaml::Pointer<CamlFpVector>) -> Vec<CamlFpVector> {
        cs.as_mut().0.compute_witness_for_ocaml(primary.as_ref(), auxiliary.as_ref()).into_iter().map(|v| CamlFpVector(v.into())).collect()
    }
}

// Fq
impl_functions! {

    pub fn fq_cs_create() -> CamlFqCS {
        let constants = Constants::new::<Pallas>();
        CamlFqCS(SnarkyConstraintSystem::create(constants))
    }

    pub fn fq_cs_add_constraint(label: Option<String>, mut cs: ocaml::Pointer<CamlFqCS>, constraint: usize) {
        unimplemented!();
    }

    pub fn fq_cs_finalize(mut cs: ocaml::Pointer<CamlFqCS>) {
        cs.as_mut().0.finalize();
    }

    pub fn fq_cs_digest(cs: &CamlFqCS) -> [u8; 32] {
        cs.digest()
    }

    pub fn fq_cs_get_rows_len(cs: &CamlFqCS) -> usize {
        cs.get_rows_len()
    }

    pub fn fq_cs_set_auxiliary_input_size(mut cs: ocaml::Pointer<CamlFqCS>, size: usize) {
        cs.as_mut().0.set_auxiliary_input_size(size);
    }

    pub fn fq_cs_set_primary_input_size(mut cs: ocaml::Pointer<CamlFqCS>, size: usize) {
        cs.as_mut().0.set_primary_input_size(size);
    }
    pub fn fq_cs_get_primary_input_size(cs: &CamlFqCS) -> usize {
        cs.get_primary_input_size()
    }

    pub fn fq_cs_get_prev_challenges(cs: &CamlFqCS) -> Option<usize> {
        cs.get_prev_challenges()
    }

    pub fn fq_cs_set_prev_challenges(mut cs: ocaml::Pointer<CamlFqCS>, num: usize) {
        cs.as_mut().0.set_prev_challenges(num);
    }

    pub fn fq_cs_finalize_and_get_gates(mut cs: ocaml::Pointer<CamlFqCS>) -> CamlPastaFqPlonkGateVector {
        CamlPastaFqPlonkGateVector(cs.as_mut().0.finalize_and_get_gates().clone())
    }

    pub fn fq_cs_compute_witness(mut cs: ocaml::Pointer<CamlFqCS>, primary: ocaml::Pointer<CamlFqVector>, auxiliary: ocaml::Pointer<CamlFqVector>) -> Vec<CamlFqVector> {
        cs.as_mut().0.compute_witness_for_ocaml(primary.as_ref(), auxiliary.as_ref()).into_iter().map(|v| CamlFqVector(v.into())).collect()
    }
}
