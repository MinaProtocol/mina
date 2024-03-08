use kimchi::circuits::lookup::runtime_tables::RuntimeTableCfg;

use crate::arkworks::WasmBn254Fp;
use crate::gate_vector::bn254_fp::WasmGateVector;
use crate::srs::bn254_fp::WasmBn254FpSrs as WasmSrs;
use crate::wasm_flat_vector::WasmFlatVector;
use crate::wasm_vector::{bn254_fp::*, WasmVector};
use ark_poly::EvaluationDomain;
use kimchi::circuits::lookup::tables::LookupTable;
use kimchi::circuits::{constraints::ConstraintSystem, gate::CircuitGate};
use kimchi::linearization::expr_linearization;
use kimchi::poly_commitment::evaluation_proof::OpeningProof;
use kimchi::prover_index::ProverIndex;
use mina_curves::bn254::{Bn254 as GAffine, Bn254Parameters, Fp};
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, sponge::DefaultFqSponge};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};
use wasm_bindgen::prelude::*;

//
// CamlPastaFpPlonkIndex (custom type)
//

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[wasm_bindgen]
pub struct WasmBn254FpPlonkIndex(
    #[wasm_bindgen(skip)] pub Box<ProverIndex<GAffine, OpeningProof<GAffine>>>,
);

// This should mimic LookupTable structure
#[wasm_bindgen]
pub struct WasmBn254FpLookupTable {
    #[wasm_bindgen(skip)]
    pub id: i32,
    #[wasm_bindgen(skip)]
    pub data: WasmVecVecBn254Fp,
}

// Converter from WasmBn254FpLookupTable to LookupTable, used by the binding
// below.
impl From<WasmBn254FpLookupTable> for LookupTable<Fp> {
    fn from(wasm_lt: WasmBn254FpLookupTable) -> LookupTable<Fp> {
        LookupTable {
            id: wasm_lt.id.into(),
            data: wasm_lt.data.0,
        }
    }
}

// JS constructor for js/bindings.js
#[wasm_bindgen]
impl WasmBn254FpLookupTable {
    #[wasm_bindgen(constructor)]
    pub fn new(id: i32, data: WasmVecVecBn254Fp) -> WasmBn254FpLookupTable {
        WasmBn254FpLookupTable { id, data }
    }
}

// Runtime table config

#[wasm_bindgen]
pub struct WasmBn254FpRuntimeTableCfg {
    #[wasm_bindgen(skip)]
    pub id: i32,
    #[wasm_bindgen(skip)]
    pub first_column: WasmFlatVector<WasmBn254Fp>,
}

// JS constructor for js/bindings.js
#[wasm_bindgen]
impl WasmBn254FpRuntimeTableCfg {
    #[wasm_bindgen(constructor)]
    pub fn new(id: i32, first_column: WasmFlatVector<WasmBn254Fp>) -> Self {
        Self { id, first_column }
    }
}

impl From<WasmBn254FpRuntimeTableCfg> for RuntimeTableCfg<Fp> {
    fn from(wasm_rt_table_cfg: WasmBn254FpRuntimeTableCfg) -> Self {
        Self {
            id: wasm_rt_table_cfg.id,
            first_column: wasm_rt_table_cfg
                .first_column
                .into_iter()
                .map(Into::into)
                .collect(),
        }
    }
}

// CamlPastaFpPlonkIndex methods
//

// Change js/web/worker-spec.js accordingly
#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_create(
    gates: &WasmGateVector,
    public_: i32,
    lookup_tables: WasmVector<WasmBn254FpLookupTable>,
    runtime_table_cfgs: WasmVector<WasmBn254FpRuntimeTableCfg>,
    prev_challenges: i32,
    srs: &WasmSrs,
) -> Result<WasmBn254FpPlonkIndex, JsError> {
    console_error_panic_hook::set_once();
    let index = crate::rayon::run_in_pool(|| {
        // flatten the permutation information (because OCaml has a different way of keeping track of permutations)
        let gates: Vec<_> = gates
            .0
            .iter()
            .map(|gate| CircuitGate::<Fp> {
                typ: gate.typ,
                wires: gate.wires,
                coeffs: gate.coeffs.clone(),
            })
            .collect();

        let rust_runtime_table_cfgs: Vec<RuntimeTableCfg<Fp>> =
            runtime_table_cfgs.into_iter().map(Into::into).collect();

        let rust_lookup_tables: Vec<LookupTable<Fp>> =
            lookup_tables.into_iter().map(Into::into).collect();

        // create constraint system
        let mut cs = match ConstraintSystem::<Fp>::create(gates)
            .public(public_ as usize)
            .prev_challenges(prev_challenges as usize)
            .lookup(rust_lookup_tables)
            .runtime(if rust_runtime_table_cfgs.is_empty() {
                None
            } else {
                Some(rust_runtime_table_cfgs)
            })
            .build()
        {
            Err(_) => {
                return Err("caml_bn254_fp_plonk_index_create: could not create constraint system");
            }
            Ok(cs) => cs,
        };

        // endo
        let (_endo_r, endo_q) = poly_commitment::srs::endos::<GAffine>();

        // Unsafe if we are in a multi-core ocaml
        {
            let ptr: &mut poly_commitment::srs::SRS<GAffine> =
                unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
            ptr.add_lagrange_basis(cs.domain.d1);
        }

        let mut index =
            ProverIndex::<GAffine, OpeningProof<GAffine>>::create(cs, endo_q, srs.0.clone());
        // Compute and cache the verifier index digest
        index.compute_verifier_index_digest::<DefaultFqSponge<Bn254Parameters, PlonkSpongeConstantsKimchi>>();
        Ok(index)
    });

    // create index
    match index {
        Ok(index) => Ok(WasmBn254FpPlonkIndex(Box::new(index))),
        Err(str) => Err(JsError::new(str)),
    }
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_max_degree(index: &WasmBn254FpPlonkIndex) -> i32 {
    index.0.srs.max_degree() as i32
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_public_inputs(index: &WasmBn254FpPlonkIndex) -> i32 {
    index.0.cs.public as i32
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_domain_d1_size(index: &WasmBn254FpPlonkIndex) -> i32 {
    index.0.cs.domain.d1.size() as i32
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_domain_d4_size(index: &WasmBn254FpPlonkIndex) -> i32 {
    index.0.cs.domain.d4.size() as i32
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_domain_d8_size(index: &WasmBn254FpPlonkIndex) -> i32 {
    index.0.cs.domain.d8.size() as i32
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_read(
    offset: Option<i32>,
    srs: &WasmSrs,
    path: String,
) -> Result<WasmBn254FpPlonkIndex, JsValue> {
    // read from file
    let file = match File::open(path) {
        Err(_) => return Err(JsValue::from_str("caml_bn254_fp_plonk_index_read")),
        Ok(file) => file,
    };
    let mut r = BufReader::new(file);

    // optional offset in file
    if let Some(offset) = offset {
        r.seek(Start(offset as u64))
            .map_err(|err| JsValue::from_str(&format!("caml_bn254_fp_plonk_index_read: {err}")))?;
    }

    // deserialize the index
    let mut t = ProverIndex::<GAffine, OpeningProof<GAffine>>::deserialize(
        &mut rmp_serde::Deserializer::new(r),
    )
    .map_err(|err| JsValue::from_str(&format!("caml_bn254_fp_plonk_index_read: {err}")))?;
    t.srs = srs.0.clone();
    let (linearization, powers_of_alpha) = expr_linearization(Some(&t.cs.feature_flags), true, 3);
    t.linearization = linearization;
    t.powers_of_alpha = powers_of_alpha;

    //
    Ok(WasmBn254FpPlonkIndex(Box::new(t)))
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_write(
    append: Option<bool>,
    index: &WasmBn254FpPlonkIndex,
    path: String,
) -> Result<(), JsValue> {
    let file = OpenOptions::new()
        .append(append.unwrap_or(true))
        .open(path)
        .map_err(|_| JsValue::from_str("caml_bn254_fp_plonk_index_write"))?;
    let w = BufWriter::new(file);
    index
        .0
        .serialize(&mut rmp_serde::Serializer::new(w))
        .map_err(|e| JsValue::from_str(&format!("caml_bn254_fp_plonk_index_read: {e}")))
}

#[wasm_bindgen]
pub fn caml_bn254_fp_plonk_index_serialize(index: &WasmBn254FpPlonkIndex) -> String {
    let serialized = rmp_serde::to_vec(&index.0).unwrap();
    base64::encode(serialized)
}

// helpers

fn format_field(f: &Fp) -> String {
    // TODO this could be much nicer, should end up as "1", "-1", "0" etc
    format!("{f}")
}

pub fn format_circuit_gate(i: usize, gate: &CircuitGate<Fp>) -> String {
    let coeffs = gate
        .coeffs
        .iter()
        .map(format_field)
        .collect::<Vec<_>>()
        .join("\n");
    let wires = gate
        .wires
        .iter()
        .enumerate()
        .filter(|(j, wire)| wire.row != i || wire.col != *j)
        .map(|(j, wire)| format!("({}, {}) --> ({}, {})", i, j, wire.row, wire.col))
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "c[{}][{:?}]:\nconstraints\n{}\nwires\n{}\n",
        i, gate.typ, coeffs, wires
    )
}
