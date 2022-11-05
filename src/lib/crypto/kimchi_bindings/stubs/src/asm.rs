use kimchi::circuits::gate::Circuit;

use crate::gate_vector::fp::CamlPastaFpPlonkGateVectorPtr;

#[ocaml_gen::func]
#[ocaml::func]
pub fn gate_to_asm(public_input_size: isize, gates: CamlPastaFpPlonkGateVectorPtr) -> String {
    let circuit = Circuit::new(
        usize::try_from(public_input_size).unwrap(),
        &gates.as_ref().0,
    );
    circuit.generate_asm()
}
