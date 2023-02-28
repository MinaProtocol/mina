use std::ops::Deref;

use kimchi::snarky::{constraint_system::SnarkyConstraintSystem, prelude::*};
use mina_curves::pasta::{Fp, Fq};

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
