use kimchi::snarky::{
    constraint_system::{
        caml::{convert_basic_constraint, convert_constraint},
        BasicSnarkyConstraint, KimchiConstraint,
    },
    prelude::*,
};
use mina_curves::pasta::{Fp, Fq};

use crate::{
    arkworks::{CamlFp, CamlFq},
    field_vector::{fp::CamlFpVector, fq::CamlFqVector},
};

use super::{CamlFpCS, CamlFpVar, CamlFqCS, CamlFqVar};

//
// Data structures
//

impl_custom!(CamlFpState, RunState<Fp>);
impl_custom!(CamlFqState, RunState<Fq>);

//
// Methods
//

// Fp
impl_functions! {
    pub fn fp_state_make(
        num_inputs: usize,
        input: CamlFpVector,
        next_auxiliary: usize,
        aux: CamlFpVector,
        system: Option<&CamlFpCS>,
        eval_constraints: bool,
        with_witness: bool,
    ) {
        todo!()
    }

    pub fn fp_state_add_legacy_constraint(
        mut state: ocaml::Pointer<CamlFpState>,
        constraint: ocaml::Pointer<BasicSnarkyConstraint<CamlFpVar>>,
    ) {
        if let Some(cs) = &mut state.as_mut().0.system {
            let constraint: BasicSnarkyConstraint<FieldVar<Fp>> =
                convert_basic_constraint(constraint.as_ref());
            cs.add_basic_snarky_constraint(constraint);
        }
    }

    pub fn fp_state_add_kimchi_constraint(
        mut state: ocaml::Pointer<CamlFpState>,
        constraint: ocaml::Pointer<KimchiConstraint<CamlFpVar, CamlFp>>,
    ) {
        if let Some(cs) = &mut state.as_mut().0.system {
            let constraint: KimchiConstraint<FieldVar<Fp>, Fp> =
                convert_constraint(constraint.as_ref());
            cs.add_constraint(constraint);
        }
    }

    pub fn fp_state_get_variable_value(state: &CamlFpState, var: usize) -> CamlFp {
        todo!()
    }

    pub fn fp_state_store_field_elt(
        mut state: ocaml::Pointer<CamlFpState>,
        value: CamlFp,
    ) -> CamlFpVar {
        let value: Fp = value.into();
        let field_var: FieldVar<Fp> = state.as_mut().0.store_field_elt(value);
        field_var.into()
    }

    pub fn fp_state_alloc_var(mut state: ocaml::Pointer<CamlFpState>) -> CamlFpVar {
        state.as_mut().0.alloc_var().into()
    }

    pub fn fp_state_has_witness(state: &CamlFpState) -> bool {
        state.0.has_witness
    }

    pub fn fp_state_as_prover(state: &CamlFpState) -> bool {
        state.0.as_prover
    }

    pub fn fp_state_set_as_prover(mut state: ocaml::Pointer<CamlFpState>, b: bool) {
        state.as_mut().0.as_prover = b;
    }

    pub fn fp_state_eval_constraints(state: &CamlFpState) -> bool {
        state.0.eval_constraints
    }

    pub fn fp_state_next_auxiliary(state: &CamlFpState) -> usize {
        state.0.next_var
    }
}

// Fq
impl_functions! {
    pub fn fq_state_make(
        num_inputs: usize,
        input: CamlFqVector,
        next_auxiliary: usize,
        aux: CamlFqVector,
        system: Option<&CamlFqCS>,
        eval_constraints: bool,
        with_witness: bool,
        as_prover: bool,
    ) {
        todo!()
    }

    pub fn fq_state_add_legacy_constraint(
        mut state: ocaml::Pointer<CamlFqState>,
        constraint: ocaml::Pointer<BasicSnarkyConstraint<CamlFqVar>>,
    ) {
        if let Some(cs) = &mut state.as_mut().0.system {
            let constraint: BasicSnarkyConstraint<FieldVar<Fq>> =
                convert_basic_constraint(constraint.as_ref());
            cs.add_basic_snarky_constraint(constraint);
        }
    }

    pub fn fq_state_add_kimchi_constraint(
        mut state: ocaml::Pointer<CamlFqState>,
        constraint: ocaml::Pointer<KimchiConstraint<CamlFqVar, CamlFq>>,
    ) {
        if let Some(cs) = &mut state.as_mut().0.system {
            let constraint: KimchiConstraint<FieldVar<Fq>, Fq> =
                convert_constraint(constraint.as_ref());
            cs.add_constraint(constraint);
        }
    }

    pub fn fq_state_get_variable_value(state: &CamlFqState, var: usize) -> CamlFq {
        todo!()
    }

    pub fn fq_state_store_field_elt(
        mut state: ocaml::Pointer<CamlFqState>,
        value: CamlFq,
    ) -> CamlFqVar {
        let value: Fq = value.into();
        let field_var: FieldVar<Fq> = state.as_mut().0.store_field_elt(value);
        field_var.into()
    }

    pub fn fq_state_alloc_var(mut state: ocaml::Pointer<CamlFqState>) -> CamlFqVar {
        state.as_mut().0.alloc_var().into()
    }

    pub fn fq_state_has_witness(state: &CamlFqState) -> bool {
        state.0.has_witness
    }

    pub fn fq_state_as_prover(state: &CamlFqState) -> bool {
        state.0.as_prover
    }

    pub fn fq_state_set_as_prover(mut state: ocaml::Pointer<CamlFqState>, b: bool) {
        state.as_mut().0.as_prover = b;
    }

    pub fn fq_state_eval_constraints(state: &CamlFqState) -> bool {
        state.0.eval_constraints
    }

    pub fn fq_state_next_auxiliary(state: &CamlFqState) -> usize {
        state.0.next_var
    }
}
