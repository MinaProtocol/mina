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
    pub fn caml_pasta_fp_plonk_gate_vector_digest(v: CamlPastaFpPlonkGateVectorPtr) -> [u8; 32] {
        Circuit(&v.as_ref().0).digest()
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
    pub fn caml_pasta_fq_plonk_gate_vector_wrap(
        mut v: CamlPastaFqPlonkGateVectorPtr,
        t: CamlWire,
        h: CamlWire,
    ) {
        (v.as_mut().0)[t.row as usize].wires[t.col as usize] = h.into();
    }

    #[ocaml_gen::func]
    #[ocaml::func]
    pub fn caml_pasta_fq_plonk_gate_vector_digest(v: CamlPastaFqPlonkGateVectorPtr) -> [u8; 32] {
        Circuit(&v.as_ref().0).digest()
    }
}
