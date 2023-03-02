use kimchi::snarky::{
    constraint_system::{
        caml::{convert_basic_constraint, convert_constraint},
        BasicSnarkyConstraint, KimchiConstraint,
    },
    prelude::*,
};
use mina_curves::pasta::{Fp, Fq};

use crate::{arkworks::CamlFp, field_vector::fp::CamlFpVector};

use super::{CamlFpCS, CamlFpVar};

//
// Data structures
//

impl_custom!(CamlFpState, RunState<Fp>);
impl_custom!(CamlFqState, RunState<Fq>);

//
// Methods
//

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

    pub fn fp_state_stack(state: &CamlFpState) -> Vec<String> {
        todo!()
    }

    pub fn fp_state_set_stack(state: &CamlFpState, stack: Vec<String>) -> CamlFpState {
        todo!()
    }

    pub fn fp_state_eval_constraints(state: &CamlFpState) -> bool {
        state.0.eval_constraints
    }

    pub fn fp_state_next_auxiliary(state: &CamlFpState) -> usize {
        state.0.next_var
    }
}
