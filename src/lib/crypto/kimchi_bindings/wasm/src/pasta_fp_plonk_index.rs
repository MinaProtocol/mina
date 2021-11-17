use ark_poly::EvaluationDomain;

use kimchi::index::{expr_linearization, Index as DlogIndex};
use kimchi_circuits::{gate::CircuitGate, nolookup::constraints::ConstraintSystem};
use mina_curves::pasta::{fp::Fp, pallas::Affine as GAffineOther, vesta::Affine as GAffine};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};
use crate::srs::fp::WasmFpSrs as WasmSrs;
use crate::gate_vector::fp::WasmGateVector;
use wasm_bindgen::prelude::*;

//
// CamlPastaFpPlonkIndex (custom type)
//

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[wasm_bindgen]
pub struct WasmPastaFpPlonkIndex(
    #[wasm_bindgen(skip)]
    pub Box<DlogIndex<GAffine>>);

//
// CamlPastaFpPlonkIndex methods
//

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_create(
    gates: &WasmGateVector,
    public: i32,
    srs: &WasmSrs,
) -> Result<WasmPastaFpPlonkIndex, JsValue> {
    // flatten the permutation information (because OCaml has a different way of keeping track of permutations)
    let gates: Vec<_> = gates.0
        .iter()
        .map(|gate| CircuitGate::<Fp> {
            row: gate.row,
            typ: gate.typ,
            wires: gate.wires,
            c: gate.c.clone(),
        })
        .collect();

    /*
    for (i, g) in gates.iter().enumerate() {
        let x : Vec<_> = g.c.iter().map(|x| format!("{}", x)).collect();
        let s = x.join(", ");
        println!("c[{}][{:?}]: {}", i, g.typ, s);
    } */

    // create constraint system
    let cs = match ConstraintSystem::<Fp>::create(
        gates,
        vec![],
        oracle::pasta::fp_3::params(),
        public as usize,
    ) {
        None => {
            return Err(JsValue::from_str(
                "caml_pasta_fp_plonk_index_create: could not create constraint system",
            ));
        }
        Some(cs) => cs,
    };

    // endo
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();

    // Unsafe if we are in a multi-core ocaml
    {
        let ptr: &mut commitment_dlog::srs::SRS<GAffine> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
        ptr.add_lagrange_basis(cs.domain.d1);
    }

    // create index
    Ok(WasmPastaFpPlonkIndex(Box::new(
        DlogIndex::<GAffine>::create(cs, oracle::pasta::fq_3::params(), endo_q, srs.0.clone()),
    )))
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_max_degree(index: &WasmPastaFpPlonkIndex) -> i32 {
    index.0.srs.max_degree() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_public_inputs(index: &WasmPastaFpPlonkIndex) -> i32 {
    index.0.cs.public as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_domain_d1_size(index: &WasmPastaFpPlonkIndex) -> i32 {
    index.0.cs.domain.d1.size() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_domain_d4_size(index: &WasmPastaFpPlonkIndex) -> i32 {
    index.0.cs.domain.d4.size() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_domain_d8_size(index: &WasmPastaFpPlonkIndex) -> i32 {
    index.0.cs.domain.d8.size() as i32
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_read(
    offset: Option<i32>,
    srs: &WasmSrs,
    path: String,
) -> Result<WasmPastaFpPlonkIndex, JsValue> {
    // read from file
    let file = match File::open(path) {
        Err(_) => {
            return Err(JsValue::from_str("caml_pasta_fp_plonk_index_read"))
        }
        Ok(file) => file,
    };
    let mut r = BufReader::new(file);

    // optional offset in file
    if let Some(offset) = offset {
        r.seek(Start(offset as u64)).map_err(|err| JsValue::from_str(&format!("caml_pasta_fp_plonk_index_read: {}", err)))?;
    }

    // deserialize the index
    let mut t = DlogIndex::<GAffine>::deserialize(&mut rmp_serde::Deserializer::new(r))
        .map_err(|err| JsValue::from_str(&format!("caml_pasta_fp_plonk_index_read: {}", err)))?;
    t.cs.fr_sponge_params = oracle::pasta::fp_3::params();
    t.srs = srs.0.clone();
    t.fq_sponge_params = oracle::pasta::fq_3::params();
    t.linearization = expr_linearization(t.cs.domain.d1, false, false, None);

    //
    Ok(WasmPastaFpPlonkIndex(Box::new(t)))
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_write(
    append: Option<bool>,
    index: &WasmPastaFpPlonkIndex,
    path: String,
) -> Result<(), JsValue> {
    let file = OpenOptions::new()
        .append(append.unwrap_or(true))
        .open(path)
        .map_err(|_| {
            JsValue::from_str("caml_pasta_fp_plonk_index_write")
        })?;
    let w = BufWriter::new(file);
    index
        .0
        .serialize(&mut rmp_serde::Serializer::new(w))
        .map_err(|e| JsValue::from_str(&format!("caml_pasta_fp_plonk_index_read: {}", e)))
}
