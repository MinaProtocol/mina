use std::rc::Rc;

use kimchi::snarky::{
    checked_runner::Constraint,
    constraint_system::{BasicSnarkyConstraint, KimchiConstraint},
    errors::SnarkyResult,
    prelude::*,
};
use mina_curves::pasta::{Fp, Fq, Pallas, Vesta};

use crate::{
    arkworks::{CamlFp, CamlFq},
    field_vector::{fp::CamlFpVector, fq::CamlFqVector},
    snarky::conv::convert_constraint_fp,
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
        eval_constraints: bool,
        system: bool,
    ) -> CamlFpState {
        let public_output_size = 0;
        let mut state = RunState::new::<Vesta>(num_inputs, public_output_size, system);
        state.eval_constraints = eval_constraints;
        CamlFpState(state)
    }

    pub fn fp_state_debug(state: ocaml::Pointer<CamlFpState>) -> String {
        let state = &state.as_ref().0;
        format!("{state:#?}")
    }

    pub fn fp_state_add_square_constraint(
        mut state: ocaml::Pointer<CamlFpState>,
        v1: CamlFpVar,
        v2: CamlFpVar,
    ) -> SnarkyResult<()> {
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::Square(v1.0, v2.0));
        state.add_constraint(constraint, None)
    }

    pub fn fp_state_add_equal_constraint(
        mut state: ocaml::Pointer<CamlFpState>,
        v1: CamlFpVar,
        v2: CamlFpVar,
    ) -> SnarkyResult<()> {
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::Equal(v1.0, v2.0));
        state.add_constraint(constraint, None)
    }

    pub fn fp_state_add_boolean_constraint(
        mut state: ocaml::Pointer<CamlFpState>,
        v1: CamlFpVar,
    ) -> SnarkyResult<()> {
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::Boolean(v1.0));
        state.add_constraint(constraint, None)
    }

    pub fn fp_state_add_r1cs_constraint(
        mut state: ocaml::Pointer<CamlFpState>,
        v1: CamlFpVar,
        v2: CamlFpVar,
        v3: CamlFpVar,
    ) -> SnarkyResult<()> {
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::R1CS(v1.0, v2.0, v3.0));
        state.add_constraint(constraint, None)
    }

    pub fn fp_state_add_kimchi_constraint(
        mut state: ocaml::Pointer<CamlFpState>,
        constraint: ocaml::Pointer<KimchiConstraint<CamlFpVar, CamlFp>>,
    ) {
        if let Some(cs) = &mut state.as_mut().0.system {
            let constraint: KimchiConstraint<FieldVar<Fp>, Fp> =
                convert_constraint_fp(constraint.as_ref());
            cs.add_constraint(constraint);
        }
    }

    pub fn fp_state_evaluate_var(state: ocaml::Pointer<CamlFpState>, var: CamlFpVar) -> CamlFp {
        CamlFp(var.0.eval(&state.as_ref().0))
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

    pub fn fp_state_has_witness(state: ocaml::Pointer<CamlFpState>) -> bool {
        state.as_ref().has_witness
    }

    pub fn fp_state_as_prover(state: ocaml::Pointer<CamlFpState>) -> bool {
        state.as_ref().as_prover
    }

    pub fn fp_state_set_as_prover(mut state: ocaml::Pointer<CamlFpState>, b: bool) {
        state.as_mut().0.as_prover = b;
    }

    pub fn fp_state_eval_constraints(state: ocaml::Pointer<CamlFpState>) -> bool {
        state.as_ref().eval_constraints
    }

    pub fn fp_state_next_auxiliary(state: ocaml::Pointer<CamlFpState>) -> usize {
        state.as_ref().next_var
    }

    pub fn fp_state_system(state: ocaml::Pointer<CamlFpState>) -> Option<CamlFpCS> {
        state.as_ref().system.clone().map(|x| CamlFpCS(x))
    }

    pub fn fp_state_finalize(mut state: ocaml::Pointer<CamlFpState>) {
        state.as_mut().0.system.as_mut().map(|x| x.finalize());
    }


    pub fn fp_state_set_public_inputs(mut state : ocaml::Pointer<CamlFpState>, inputs : CamlFpVector) {
        state.as_mut().0.generate_witness_init(inputs.0.to_vec());
    }

    pub fn fp_state_get_private_inputs(state : ocaml::Pointer<CamlFpState>) -> CamlFpVector {
        CamlFpVector(Rc::new(state.as_ref().get_private_inputs()))
    }

    pub fn fp_state_seal(mut state: ocaml::Pointer<CamlFpState>, var: CamlFpVar) -> SnarkyResult<CamlFpVar> {
        let sealed_var = var.0.seal(&mut state.as_mut().0, "seal")?;
        Ok(CamlFpVar(sealed_var))
    }
}

// Fq
impl_functions! {
    pub fn fq_state_make(
        num_inputs: usize,
        eval_constraints: bool,
        system: bool,
    ) -> CamlFqState {
        let public_output_size = 0;
        let mut state = RunState::new::<Pallas>(num_inputs, public_output_size, system);
        state.eval_constraints = eval_constraints;
        CamlFqState(state)
    }

    pub fn fq_state_debug(state: ocaml::Pointer<CamlFqState>) -> String {
        let state = &state.as_ref().0;
        format!("{state:#?}")
    }

    pub fn fq_state_add_square_constraint(
        mut state: ocaml::Pointer<CamlFqState>,
        v1: CamlFqVar,
        v2: CamlFqVar,
    )  -> SnarkyResult<()> {
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::Square(v1.0, v2.0));
        state.add_constraint(constraint, None)
    }

    pub fn fq_state_add_equal_constraint(
        mut state: ocaml::Pointer<CamlFqState>,
        v1: CamlFqVar,
        v2: CamlFqVar,
    ) -> SnarkyResult<()> {
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::Equal(v1.0, v2.0));
        state.add_constraint(constraint, None)
    }

    pub fn fq_state_add_boolean_constraint(
        mut state: ocaml::Pointer<CamlFqState>,
        v1: CamlFqVar,
    ) -> SnarkyResult<()>{
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::Boolean(v1.0));
        state.add_constraint(constraint, None)
    }

    pub fn fq_state_add_r1cs_constraint(
        mut state: ocaml::Pointer<CamlFqState>,
        v1: CamlFqVar,
        v2: CamlFqVar,
        v3: CamlFqVar,
    ) -> SnarkyResult<()> {
        let state = &mut state.as_mut().0;
        let constraint = Constraint::BasicSnarkyConstraint(BasicSnarkyConstraint::R1CS(v1.0, v2.0, v3.0));
        state.add_constraint(constraint, None)
    }

    pub fn fq_state_add_kimchi_constraint(
        mut state: ocaml::Pointer<CamlFqState>,
        constraint: ocaml::Pointer<KimchiConstraint<CamlFqVar, CamlFq>>,
    ) {
        panic!("yolo");
    }

    pub fn fq_state_evaluate_var(state: ocaml::Pointer<CamlFqState>, var: CamlFqVar) -> CamlFq {
        CamlFq(var.0.eval(&state.as_ref().0))
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

    pub fn fq_state_has_witness(state: ocaml::Pointer<CamlFqState>) -> bool {
        state.as_ref().has_witness
    }

    pub fn fq_state_as_prover(state: ocaml::Pointer<CamlFqState>) -> bool {
        state.as_ref().as_prover
    }

    pub fn fq_state_set_as_prover(mut state: ocaml::Pointer<CamlFqState>, b: bool) {
        state.as_mut().0.as_prover = b;
    }

    pub fn fq_state_eval_constraints(state: ocaml::Pointer<CamlFqState>) -> bool {
        state.as_ref().eval_constraints
    }

    pub fn fq_state_next_auxiliary(state: ocaml::Pointer<CamlFqState>) -> usize {
        state.as_ref().next_var
    }

    pub fn fq_state_system(state: ocaml::Pointer<CamlFqState>) -> Option<CamlFqCS> {
        state.as_ref().system.clone().map(|x| CamlFqCS(x))
    }

    pub fn fq_state_finalize(mut state: ocaml::Pointer<CamlFqState>) {
        state.as_mut().0.system.as_mut().map(|x| x.finalize());
    }

    pub fn fq_state_set_public_inputs(mut state : ocaml::Pointer<CamlFqState>, inputs : CamlFqVector) {
        state.as_mut().0.generate_witness_init(inputs.0.to_vec());
    }

    pub fn fq_state_get_private_inputs(state : ocaml::Pointer<CamlFqState>) -> CamlFqVector {
        CamlFqVector(Rc::new(state.as_ref().get_private_inputs()))
    }

    pub fn fq_state_seal(mut state: ocaml::Pointer<CamlFqState>, var: CamlFqVar) -> SnarkyResult<CamlFqVar> {
        let sealed_var = var.0.seal(&mut state.as_mut().0, "seal")?;
        Ok(CamlFqVar(sealed_var))
    }
}
