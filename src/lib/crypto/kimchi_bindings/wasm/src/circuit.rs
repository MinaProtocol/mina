use crate::bn254_fp_plonk_index::WasmBn254FpPlonkIndex;
use ark_ff::PrimeField;
use kimchi::circuits::constraints::ConstraintSystem;
use kimchi::circuits::gate::CircuitGate;
use mina_curves::bn254::Fp as Bn254Fp;
use mina_curves::pasta::Fp;
use serde::Serialize;
use wasm_bindgen::prelude::wasm_bindgen;

use crate::pasta_fp_plonk_index::WasmPastaFpPlonkIndex;

#[derive(Serialize)]
struct Circuit<F>
where
    F: PrimeField,
{
    public_input_size: usize,
    #[serde(bound = "CircuitGate<F>: Serialize")]
    gates: Vec<CircuitGate<F>>,
}

impl<F> From<&ConstraintSystem<F>> for Circuit<F>
where
    F: PrimeField,
{
    fn from(cs: &ConstraintSystem<F>) -> Self {
        Circuit {
            public_input_size: cs.public,
            gates: cs.gates.clone(),
        }
    }
}

#[wasm_bindgen]
pub fn prover_to_json(prover_index: &WasmPastaFpPlonkIndex) -> String {
    let circuit: Circuit<Fp> = (&prover_index.0.cs).into();
    serde_json::to_string(&circuit).expect("couldn't serialize constraints")
}

#[wasm_bindgen]
pub fn prover_to_json_bn254(prover_index: &WasmBn254FpPlonkIndex) -> String {
    let circuit: Circuit<Bn254Fp> = (&prover_index.0.cs).into();
    serde_json::to_string(&circuit).expect("couldn't serialize constraints")
}
