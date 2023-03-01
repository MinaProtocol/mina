use kimchi::snarky::prelude::*;
use mina_curves::pasta::{Fp, Fq};

impl_custom!(CamlFpState, RunState<Fp>);
impl_custom!(CamlFqState, RunState<Fq>);
