use ark_poly::EvaluationDomain;

use crate::gate_vector::fq::WasmGateVector;
use crate::srs::fq::WasmFqSrs as WasmSrs;
use kimchi::circuits::{constraints::ConstraintSystem, gate::CircuitGate};
use kimchi::linearization::expr_linearization;
use kimchi::prover_index::ProverIndex;
use mina_curves::pasta::{Fq, Pallas as GAffine, PallasParameters, Vesta as GAffineOther};
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, sponge::DefaultFqSponge};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};
use wasm_bindgen::prelude::*;

//
// CamlPastaFqPlonkIndex (custom type)
//

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[wasm_bindgen]
pub struct WasmPastaFqPlonkIndex(#[wasm_bindgen(skip)] pub Box<ProverIndex<GAffine>>);

//
// CamlPastaFqPlonkIndex methods
//

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_create(
    gates: &WasmGateVector,
    public_: i32,
    prev_challenges: i32,
    srs: &WasmSrs,
) -> Result<WasmPastaFqPlonkIndex, JsError> {
    console_error_panic_hook::set_once();
    let index = crate::rayon::run_in_pool(|| {
        // flatten the permutation information (because OCaml has a different way of keeping track of permutations)
        let gates: Vec<_> = gates
            .0
            .iter()
            .map(|gate| CircuitGate::<Fq> {
                typ: gate.typ,
                wires: gate.wires,
                coeffs: gate.coeffs.clone(),
            })
            .collect();

        // create constraint system
        let cs = match ConstraintSystem::<Fq>::create(gates)
            .public(public_ as usize)
            .prev_challenges(prev_challenges as usize)
            .build()
        {
            Err(_) => {
                return Err("caml_pasta_fq_plonk_index_create: could not create constraint system");
            }
            Ok(cs) => cs,
        };

        // endo
        let (endo_q, _endo_r) = poly_commitment::srs::endos::<GAffineOther>();

        // Unsafe if we are in a multi-core ocaml
        {
            let ptr: &mut poly_commitment::srs::SRS<GAffine> =
                unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
            ptr.add_lagrange_basis(cs.domain.d1);
        }

        let mut index = ProverIndex::<GAffine>::create(cs, endo_q, srs.0.clone());
        // Compute and cache the verifier index digest
        index.compute_verifier_index_digest::<DefaultFqSponge<PallasParameters, PlonkSpongeConstantsKimchi>>();

        Ok(index)
    });

    // create index
    match index {
        Ok(index) => Ok(WasmPastaFqPlonkIndex(Box::new(index))),
        Err(str) => Err(JsError::new(str)),
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_max_degree(index: &WasmPastaFqPlonkIndex) -> i32 {
    index.0.srs.max_degree() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_public_inputs(index: &WasmPastaFqPlonkIndex) -> i32 {
    index.0.cs.public as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_domain_d1_size(index: &WasmPastaFqPlonkIndex) -> i32 {
    index.0.cs.domain.d1.size() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_domain_d4_size(index: &WasmPastaFqPlonkIndex) -> i32 {
    index.0.cs.domain.d4.size() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_domain_d8_size(index: &WasmPastaFqPlonkIndex) -> i32 {
    index.0.cs.domain.d8.size() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_read(
    offset: Option<i32>,
    srs: &WasmSrs,
    path: String,
) -> Result<WasmPastaFqPlonkIndex, JsValue> {
    // read from file
    let file = match File::open(path) {
        Err(_) => return Err(JsValue::from_str("caml_pasta_fq_plonk_index_read")),
        Ok(file) => file,
    };
    let mut r = BufReader::new(file);

    // optional offset in file
    if let Some(offset) = offset {
        r.seek(Start(offset as u64))
            .map_err(|err| JsValue::from_str(&format!("caml_pasta_fq_plonk_index_read: {err}")))?;
    }

    // deserialize the index
    let mut t = ProverIndex::<GAffine>::deserialize(&mut rmp_serde::Deserializer::new(r))
        .map_err(|err| JsValue::from_str(&format!("caml_pasta_fq_plonk_index_read: {err}")))?;
    t.srs = srs.0.clone();
    let (linearization, powers_of_alpha) = expr_linearization(Some(&t.cs.feature_flags), true);
    t.linearization = linearization;
    t.powers_of_alpha = powers_of_alpha;

    //
    Ok(WasmPastaFqPlonkIndex(Box::new(t)))
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_write(
    append: Option<bool>,
    index: &WasmPastaFqPlonkIndex,
    path: String,
) -> Result<(), JsValue> {
    let file = OpenOptions::new()
        .append(append.unwrap_or(true))
        .open(path)
        .map_err(|_| JsValue::from_str("caml_pasta_fq_plonk_index_write"))?;
    let w = BufWriter::new(file);
    index
        .0
        .serialize(&mut rmp_serde::Serializer::new(w))
        .map_err(|e| JsValue::from_str(&format!("caml_pasta_fq_plonk_index_read: {e}")))
}

#[wasm_bindgen]
pub fn caml_pasta_fq_plonk_index_serialize(index: &WasmPastaFqPlonkIndex) -> String {
    let serialized = rmp_serde::to_vec(&index.0).unwrap();
    base64::encode(serialized)
}
