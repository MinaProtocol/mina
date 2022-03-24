//! A GateVector: this is used to represent a list of gates.

use crate::wasm_flat_vector::WasmFlatVector;
use kimchi::circuits::{
    gate::GateType,
    gate::{Circuit, CircuitGate},
    wires::Wire,
};
use o1_utils::hasher::CryptoDigest;
use wasm_bindgen::prelude::*;

use paste::paste;

#[wasm_bindgen]
#[derive(Clone, Copy, Debug)]
pub struct WasmGateWires(
    pub Wire,
    pub Wire,
    pub Wire,
    pub Wire,
    pub Wire,
    pub Wire,
    pub Wire,
);

#[wasm_bindgen]
impl WasmGateWires {
    #[wasm_bindgen(constructor)]
    pub fn new(w0: Wire, w1: Wire, w2: Wire, w3: Wire, w4: Wire, w5: Wire, w6: Wire) -> Self {
        WasmGateWires(w0, w1, w2, w3, w4, w5, w6)
    }
}

macro_rules! impl_gate_vector {
    ($name: ident,
     $WasmF: ty,
     $F: ty,
     $field_name: ident) => {
        paste! {
            #[wasm_bindgen]
            pub struct [<Wasm $field_name:camel GateVector>](
                #[wasm_bindgen(skip)] pub Vec<CircuitGate<$F>>);
            pub type WasmGateVector = [<Wasm $field_name:camel GateVector>];

            #[wasm_bindgen]
            pub struct [<Wasm $field_name:camel Gate>] {
                pub typ: GateType, // type of the gate
                pub wires: WasmGateWires,  // gate wires
                #[wasm_bindgen(skip)] pub coeffs: Vec<$WasmF>,  // constraints vector
            }

            #[wasm_bindgen]
            impl [<Wasm $field_name:camel Gate>] {
                #[wasm_bindgen(constructor)]
                pub fn new(
                    typ: GateType,
                    wires: WasmGateWires,
                    coeffs: WasmFlatVector<$WasmF>) -> Self {
                    Self {
                        typ,
                        wires,
                        coeffs: coeffs.into(),
                    }
                }
            }

            impl From<CircuitGate<$F>> for [<Wasm $field_name:camel Gate>]
            {
                fn from(cg: CircuitGate<$F>) -> Self {
                    Self {
                        typ: cg.typ,
                        wires: WasmGateWires(
                            cg.wires[0],
                            cg.wires[1],
                            cg.wires[2],
                            cg.wires[3],
                            cg.wires[4],
                            cg.wires[5],
                            cg.wires[6]),
                        coeffs: cg.coeffs.into_iter().map(Into::into).collect(),
                    }
                }
            }

            impl From<&CircuitGate<$F>> for [<Wasm $field_name:camel Gate>]
            {
                fn from(cg: &CircuitGate<$F>) -> Self {
                    Self {
                        typ: cg.typ,
                        wires: WasmGateWires(
                            cg.wires[0],
                            cg.wires[1],
                            cg.wires[2],
                            cg.wires[3],
                            cg.wires[4],
                            cg.wires[5],
                            cg.wires[6]),
                        coeffs: cg.coeffs.clone().into_iter().map(Into::into).collect(),
                    }
                }
            }

            impl From<[<Wasm $field_name:camel Gate>]> for CircuitGate<$F>
            {
                fn from(ccg: [<Wasm $field_name:camel Gate>]) -> Self {
                    Self {
                        typ: ccg.typ,
                        wires: [
                            ccg.wires.0,
                            ccg.wires.1,
                            ccg.wires.2,
                            ccg.wires.3,
                            ccg.wires.4,
                            ccg.wires.5,
                            ccg.wires.6
                        ],
                        coeffs: ccg.coeffs.into_iter().map(Into::into).collect(),
                    }
                }
            }

            #[wasm_bindgen]
            pub fn [<caml_pasta_ $name:snake _plonk_gate_vector_create>]() -> WasmGateVector {
                [<Wasm $field_name:camel GateVector>](Vec::new())
            }

            #[wasm_bindgen]
            pub fn [<caml_pasta_ $name:snake _plonk_gate_vector_add>](
                v: &mut WasmGateVector,
                gate: [<Wasm $field_name:camel Gate>],
            ) {
                let gate: CircuitGate<$F> = gate.into();
                v.0.push(gate);
            }

            #[wasm_bindgen]
            pub fn [<caml_pasta_ $name:snake _plonk_gate_vector_get>](
                v: &WasmGateVector,
                i: i32,
            ) -> [<Wasm $field_name:camel Gate>] {
                (&(v.0)[i as usize]).into()
            }

            #[wasm_bindgen]
            pub fn [<caml_pasta_ $name:snake _plonk_gate_vector_wrap>](
                v: &mut WasmGateVector,
                t: Wire,
                h: Wire,
            ) {
                (v.0)[t.row as usize].wires[t.col as usize] = h.into();
            }

            #[wasm_bindgen]
            pub fn [<caml_pasta_ $name:snake _plonk_gate_vector_digest>](
                v: &WasmGateVector
            ) -> Box<[u8]> {
                Circuit(&(v.0)).digest().to_vec().into_boxed_slice()
            }
        }
    };
}

pub mod fp {
    use super::*;
    use crate::arkworks::WasmPastaFp as WasmF;
    use mina_curves::pasta::fp::Fp as F;

    impl_gate_vector!(fp, WasmF, F, Fp);
}

//
// Fq
//

pub mod fq {
    use super::*;
    use crate::arkworks::WasmPastaFq as WasmF;
    use mina_curves::pasta::fq::Fq as F;

    impl_gate_vector!(fq, WasmF, F, Fq);
}
