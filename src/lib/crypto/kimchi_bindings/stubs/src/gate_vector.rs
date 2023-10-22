//! A GateVector: this is used to represent a list of gates.

use kimchi::circuits::{
    gate::{caml::CamlCircuitGate, Circuit, CircuitGate},
    wires::caml::CamlWire,
};
use o1_utils::hasher::CryptoDigest;

// TODO: get rid of this

//
// Fp
//

pub mod fp {
    use super::*;
    use crate::arkworks::CamlFp;
    use mina_curves::pasta::Fp;

    //
    // CamlPastaFpPlonkGateVector
    //

    #[derive(ocaml_gen::CustomType)]
    pub struct CamlPastaFpPlonkGateVector(pub Vec<CircuitGate<Fp>>);
    pub type CamlPastaFpPlonkGateVectorPtr<'a> = ocaml::Pointer<'a, CamlPastaFpPlonkGateVector>;

    extern "C" fn caml_pasta_fp_plonk_gate_vector_finalize(v: ocaml::Raw) {
        unsafe {
            let v: CamlPastaFpPlonkGateVectorPtr = v.as_pointer();
            v.drop_in_place()
        };
    }

    ocaml::custom!(CamlPastaFpPlonkGateVector {
        finalize: caml_pasta_fp_plonk_gate_vector_finalize,
    });

    //
    // Functions
    //

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fp_plonk_gate_vector_create() -> CamlPastaFpPlonkGateVector {
        CamlPastaFpPlonkGateVector(Vec::new())
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fp_plonk_gate_vector_add(
        mut v: CamlPastaFpPlonkGateVectorPtr,
        gate: CamlCircuitGate<CamlFp>,
    ) {
        let gate: CircuitGate<Fp> = gate.into();
        v.as_mut().0.push(gate);
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fp_plonk_gate_vector_get(
        v: CamlPastaFpPlonkGateVectorPtr,
        i: ocaml::Int,
    ) -> CamlCircuitGate<CamlFp> {
        let gate = &(v.as_ref().0)[i as usize];
        gate.into()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fp_plonk_gate_vector_len(v: CamlPastaFpPlonkGateVectorPtr) -> usize {
        v.as_ref().0.len()
    }

    // TODO: remove this function
    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fp_plonk_gate_vector_wrap(
        mut v: CamlPastaFpPlonkGateVectorPtr,
        t: CamlWire,
        h: CamlWire,
    ) {
        (v.as_mut().0)[t.row as usize].wires[t.col as usize] = h.into();
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fp_plonk_gate_vector_digest(
        public_input_size: isize,
        v: CamlPastaFpPlonkGateVectorPtr,
    ) -> [u8; 32] {
        Circuit::new(usize::try_from(public_input_size).unwrap(), &v.as_ref().0).digest()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fp_plonk_circuit_serialize(
        public_input_size: isize,
        v: CamlPastaFpPlonkGateVectorPtr,
    ) -> String {
        let circuit = Circuit::new(usize::try_from(public_input_size).unwrap(), &v.as_ref().0);
        serde_json::to_string(&circuit).expect("couldn't serialize constraints")
    }
}

//
// Fq
//

pub mod fq {
    use super::*;
    use crate::arkworks::CamlFq;
    use mina_curves::pasta::Fq;

    //
    // CamlPastaFqPlonkGateVector
    //

    #[derive(ocaml_gen::CustomType)]
    pub struct CamlPastaFqPlonkGateVector(pub Vec<CircuitGate<Fq>>);
    pub type CamlPastaFqPlonkGateVectorPtr<'a> = ocaml::Pointer<'a, CamlPastaFqPlonkGateVector>;

    extern "C" fn caml_pasta_fq_plonk_gate_vector_finalize(v: ocaml::Raw) {
        unsafe {
            let v: CamlPastaFqPlonkGateVectorPtr = v.as_pointer();
            v.drop_in_place()
        };
    }

    ocaml::custom!(CamlPastaFqPlonkGateVector {
        finalize: caml_pasta_fq_plonk_gate_vector_finalize,
    });

    //
    // Functions
    //

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_gate_vector_create() -> CamlPastaFqPlonkGateVector {
        CamlPastaFqPlonkGateVector(Vec::new())
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_gate_vector_add(
        mut v: CamlPastaFqPlonkGateVectorPtr,
        gate: CamlCircuitGate<CamlFq>,
    ) {
        v.as_mut().0.push(gate.into());
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_gate_vector_get(
        v: CamlPastaFqPlonkGateVectorPtr,
        i: ocaml::Int,
    ) -> CamlCircuitGate<CamlFq> {
        let gate = &(v.as_ref().0)[i as usize];
        gate.into()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_gate_vector_len(v: CamlPastaFqPlonkGateVectorPtr) -> usize {
        v.as_ref().0.len()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_gate_vector_wrap(
        mut v: CamlPastaFqPlonkGateVectorPtr,
        t: CamlWire,
        h: CamlWire,
    ) {
        (v.as_mut().0)[t.row as usize].wires[t.col as usize] = h.into();
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_gate_vector_digest(
        public_input_size: isize,
        v: CamlPastaFqPlonkGateVectorPtr,
    ) -> [u8; 32] {
        Circuit::new(usize::try_from(public_input_size).unwrap(), &v.as_ref().0).digest()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_circuit_serialize(
        public_input_size: isize,
        v: CamlPastaFqPlonkGateVectorPtr,
    ) -> String {
        let circuit = Circuit::new(usize::try_from(public_input_size).unwrap(), &v.as_ref().0);
        serde_json::to_string(&circuit).expect("couldn't serialize constraints")
    }
}

//
// BN254Fp
//

pub mod bn254 {
    use super::*;
    use crate::arkworks::CamlBN254Fp;
    use mina_curves::bn254::Fp;

    //
    // CamlBN254PlonkGateVector
    //

    #[derive(ocaml_gen::CustomType)]
    pub struct CamlBN254PlonkGateVector(pub Vec<CircuitGate<Fp>>);
    pub type CamlBN254PlonkGateVectorPtr<'a> = ocaml::Pointer<'a, CamlBN254PlonkGateVector>;

    extern "C" fn caml_bn254_plonk_gate_vector_finalize(v: ocaml::Raw) {
        unsafe {
            let v: CamlBN254PlonkGateVectorPtr = v.as_pointer();
            v.drop_in_place()
        };
    }

    ocaml::custom!(CamlBN254PlonkGateVector {
        finalize: caml_bn254_plonk_gate_vector_finalize,
    });

    //
    // Functions
    //

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_bn254_plonk_gate_vector_create() -> CamlBN254PlonkGateVector {
        CamlBN254PlonkGateVector(Vec::new())
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_bn254_plonk_gate_vector_add(
        mut v: CamlBN254PlonkGateVectorPtr,
        gate: CamlCircuitGate<CamlBN254Fp>,
    ) {
        let gate: CircuitGate<Fp> = gate.into();
        v.as_mut().0.push(gate);
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_bn254_plonk_gate_vector_get(
        v: CamlBN254PlonkGateVectorPtr,
        i: ocaml::Int,
    ) -> CamlCircuitGate<CamlBN254Fp> {
        let gate = &(v.as_ref().0)[i as usize];
        gate.into()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_bn254_plonk_gate_vector_len(v: CamlBN254PlonkGateVectorPtr) -> usize {
        v.as_ref().0.len()
    }

    // TODO: remove this function
    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_bn254_plonk_gate_vector_wrap(
        mut v: CamlBN254PlonkGateVectorPtr,
        t: CamlWire,
        h: CamlWire,
    ) {
        (v.as_mut().0)[t.row as usize].wires[t.col as usize] = h.into();
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_bn254_plonk_gate_vector_digest(
        public_input_size: isize,
        v: CamlBN254PlonkGateVectorPtr,
    ) -> [u8; 32] {
        Circuit::new(usize::try_from(public_input_size).unwrap(), &v.as_ref().0).digest()
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_bn254_plonk_circuit_serialize(
        public_input_size: isize,
        v: CamlBN254PlonkGateVectorPtr,
    ) -> String {
        let circuit = Circuit::new(usize::try_from(public_input_size).unwrap(), &v.as_ref().0);
        serde_json::to_string(&circuit).expect("couldn't serialize constraints")
    }
}
