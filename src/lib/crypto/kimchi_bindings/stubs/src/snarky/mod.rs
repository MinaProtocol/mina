use std::ops::Deref;

use kimchi::snarky::{constraint_system::SnarkyConstraintSystem, prelude::*};
use mina_curves::pasta::{Fp, Fq};

use crate::gate_vector::{fp::CamlPastaFpPlonkGateVector, fq::CamlPastaFqPlonkGateVector};

//
// FieldVar
//

impl_custom!(CamlFpVar, CVar<Fp>, Debug, Clone);
impl_custom!(CamlFqVar, CVar<Fq>, Debug, Clone);

//
// ConstraintSystem
//

impl_custom!(CamlFpCS, SnarkyConstraintSystem<Fp>);
impl_custom!(CamlFqCS, SnarkyConstraintSystem<Fq>);

//
// State
//

impl_custom!(CamlFpState, RunState<Fp>);
impl_custom!(CamlFqState, RunState<Fq>);

//
// ConstraintSystem functions
//

// Fp
impl_functions! {
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
}

// Fq
impl_functions! {
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
}
