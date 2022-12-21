use kimchi::snarky::{constants::Constants, constraint_system::BasicSnarkyConstraint};
use kimchi::snarky::{constraint_system::SnarkyConstraintSystem, cvar::CVar};

pub mod fp {
    use crate::gate_vector::fp::CamlPastaFpPlonkGateVector;

    use super::*;

    use kimchi::circuits::gate::CircuitGate;
    use mina_curves::pasta::{Fp, Vesta};

    #[derive(ocaml_gen::CustomType)]
    pub struct CamlCvarFp(CVar<Fp>);

    ocaml::custom!(CamlCvarFp);

    #[derive(ocaml_gen::CustomType)]
    pub struct CamlGatesFp(Vec<CircuitGate<Fp>>);

    ocaml::custom!(CamlGatesFp);

    #[derive(ocaml_gen::CustomType)]
    pub struct CamlSnarkyConstraintSystemFp(SnarkyConstraintSystem<Fp>);

    ocaml::custom!(CamlSnarkyConstraintSystemFp);

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_create_snarky_constraint_system_fp() -> CamlSnarkyConstraintSystemFp {
        let constants = Constants::new::<Vesta>();
        CamlSnarkyConstraintSystemFp(SnarkyConstraintSystem::create(constants))
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_get_public_input_size(cs: &CamlSnarkyConstraintSystemFp) -> Option<usize> {
        // TODO: this is supposed to implement Set_once in OCaml, which we can do
        // but do we really want to do that instead of Option?
        todo!()
    }

    // TODO: rename all these function names (primary? auxiliary?)
    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_get_primary_input_size(cs: &CamlSnarkyConstraintSystemFp) -> usize {
        cs.0.get_primary_input_size()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_set_primary_input_size(cs: &CamlSnarkyConstraintSystemFp, input_size: usize) {
        cs.0.set_public_input_size(input_size)
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_get_auxiliary_input_size(cs: &CamlSnarkyConstraintSystemFp) -> usize {
        cs.0.get_auxiliary_input_size()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_set_auxiliary_input_size(cs: &CamlSnarkyConstraintSystemFp, input_size: usize) {
        cs.0.set_auxiliary_input_size(input_size)
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_get_prev_challenges(cs: &CamlSnarkyConstraintSystemFp) -> Option<usize> {
        // TODO: weird, we didn't copy that field over to rust
        todo!()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_set_prev_challenges(cs: &CamlSnarkyConstraintSystemFp, prev_challenges: usize) {
        // TODO: weird, we didn't copy that field over to rust
        todo!()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_get_rows_len(cs: &CamlSnarkyConstraintSystemFp) -> usize {
        cs.0.rows.len()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_next_row(cs: &CamlSnarkyConstraintSystemFp) -> usize {
        cs.0.next_row
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_add_constraint(
        &mut self,
        _label: Option<String>,
        constraint: BasicSnarkyConstraint<CamlCvarFp>,
    ) {
        // TODO: label doesn't seem used
        cs.0.add_basic_snarky_constraint(constraint);
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_compute_witness(
        cs: &CamlSnarkyConstraintSystemFp,
        table: HashMap<usize, Fp>,
    ) -> Vec<Vec<Fp>> {
        todo!()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_finalize(&mut self) {
        todo!()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_finalize_and_get_gates(&mut self) -> CamlPastaFpPlonkGateVector {
        CamlPastaFpPlonkGateVector(cs.finalize_and_get_gates())
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_digest(cs: &CamlSnarkyConstraintSystemFp) -> [u8; 32] {
        cs.0.digest()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_to_json(cs: &CamlSnarkyConstraintSystemFp) -> String {
        todo!();
    }
}
