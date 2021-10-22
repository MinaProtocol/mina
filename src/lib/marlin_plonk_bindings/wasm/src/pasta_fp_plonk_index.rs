use wasm_bindgen::prelude::*;
use wasm_bindgen::JsValue;
use mina_curves::pasta::{
    vesta::Affine as GAffine,
    pallas::Affine as GAffineOther,
    fp::Fp,
};

use plonk_circuits::constraints::ConstraintSystem;
use plonk_circuits::gate::{CircuitGate, Gate};
use plonk_circuits::wires::{Col::*, GateWires, Wire};

use ff_fft::{EvaluationDomain, Radix2EvaluationDomain as Domain};

use commitment_dlog::srs::{SRS, SRSSpec, SRSValue};
use plonk_protocol_dlog::index::Index as DlogIndex;

use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
    rc::Rc,
};

use crate::index_serialization;
use crate::plonk_gate::{WasmPlonkCol, WasmPlonkGateType, WasmPlonkWire, WasmPlonkWires};
use crate::pasta_fp::WasmPastaFp;
use crate::pasta_fp_urs::WasmPastaFpUrs;
use crate::wasm_flat_vector::WasmFlatVector;

#[wasm_bindgen]
pub struct WasmPastaFpPlonkGateVector(
    #[wasm_bindgen(skip)] pub Vec<Gate<Fp>>);

#[wasm_bindgen]
pub struct WasmPastaFpPlonkGate {
    pub typ: WasmPlonkGateType, // type of the gate
    pub wires: WasmPlonkWires,  // gate wires
    #[wasm_bindgen(skip)] pub c: Vec<WasmPastaFp>,  // constraints vector
}

#[wasm_bindgen]
impl WasmPastaFpPlonkGate {
    #[wasm_bindgen(constructor)]
    pub fn new(typ: WasmPlonkGateType, wires: WasmPlonkWires, c: WasmFlatVector<WasmPastaFp>) -> WasmPastaFpPlonkGate {
        WasmPastaFpPlonkGate {typ, wires, c: c.into()}
    }

    #[wasm_bindgen(getter)]
    pub fn c(&self) -> WasmFlatVector<WasmPastaFp> {
        self.c.clone().into()
    }

    #[wasm_bindgen(setter)]
    pub fn set_c(&mut self, c: WasmFlatVector<WasmPastaFp>) {
        self.c = c.into()
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_gate_vector_create() -> WasmPastaFpPlonkGateVector {
    WasmPastaFpPlonkGateVector(Vec::new())
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_gate_vector_add(
    v: &mut WasmPastaFpPlonkGateVector,
    gate: WasmPastaFpPlonkGate,
) {
    let WasmPastaFpPlonkGate {typ, wires, c} = gate;
    v.0.push(Gate {
        typ: typ.into(),
        wires: wires.into(),
        c: c.iter().map(|x| x.0).collect(),
    });
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_gate_vector_get(
    v: &WasmPastaFpPlonkGateVector,
    i: i32,
) -> WasmPastaFpPlonkGate {
    let gate = &(v.0)[i as usize];
    let c: Vec<_> = gate.c.iter().map(|x| WasmPastaFp(*x)).collect();
    WasmPastaFpPlonkGate {
        typ: (&gate.typ).into(),
        wires: (&gate.wires).into(),
        c: c.into(),
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_gate_vector_wrap(
    v: &mut WasmPastaFpPlonkGateVector,
    t: WasmPlonkWire,
    h: WasmPlonkWire,
) {
    match t.col {
        WasmPlonkCol::L => {
            (v.0)[t.row as usize].wires.l = Wire {
                row: h.row as usize,
                col: h.col.into(),
            }
        }
        WasmPlonkCol::R => {
            (v.0)[t.row as usize].wires.r = Wire {
                row: h.row as usize,
                col: h.col.into(),
            }
        }
        WasmPlonkCol::O => {
            (v.0)[t.row as usize].wires.o = Wire {
                row: h.row as usize,
                col: h.col.into(),
            }
        }
    }
}

/* Boxed so that we don't store large proving indexes in the JS heap. */

#[wasm_bindgen]
pub struct WasmPastaFpPlonkIndex(
    #[wasm_bindgen(skip)]
    pub Box<DlogIndex<'static, GAffine>>,
    #[wasm_bindgen(skip)]
    pub Rc<SRS<GAffine>>);

impl Drop for WasmPastaFpPlonkIndex {
    fn drop(&mut self) {
        let WasmPastaFpPlonkIndex(index, _srs) = &*self;
        match **index {
            DlogIndex {srs: SRSValue::Ref(x), .. } => {
                // Reconstruct the Rc that we used to create the SRS, so that we decrement the
                // refcount by dropping it.
                let _srs = unsafe { Rc::from_raw(x as *const SRS<GAffine>) };
            }
            DlogIndex {srs: SRSValue::Value(_), .. } => { }
        }
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_create(
    gates: &WasmPastaFpPlonkGateVector,
    public_: i32,
    urs: &WasmPastaFpUrs,
) -> Result<WasmPastaFpPlonkIndex, JsValue> {
    let n = match Domain::<Fp>::compute_size_of_domain(gates.0.len()) {
        None => Err(JsValue::from_str("caml_pasta_fp_plonk_index_create"))?,
        Some(n) => n,
    };
    let wire = |w: Wire| -> usize {
        match w.col {
            L => w.row,
            R => w.row + n,
            O => w.row + 2 * n,
        }
    };

    let gates: Vec<_> = gates
        .0
        .iter()
        .map(|gate| CircuitGate::<Fp> {
            typ: gate.typ.clone(),
            wires: GateWires {
                l: (gate.wires.row, wire(gate.wires.l)),
                r: (gate.wires.row + n, wire(gate.wires.r)),
                o: (gate.wires.row + 2 * n, wire(gate.wires.o)),
            },
            c: gate.c.clone(),
        })
        .collect();

    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
    let cs =
        match ConstraintSystem::<Fp>::create(gates, oracle::pasta::fp::params(), public_ as usize)
        {
            None => Err(JsValue::from_str(
                "caml_pasta_fp_plonk_index_create: could not create constraint system",
            ))?,
            Some(cs) => cs,
        };
    let urs_copy = Rc::clone(&**urs);
    let urs_copy_outer = Rc::clone(&**urs);
    let srs = {
        // We know that the underlying value is still alive, because we never convert any of our
        // Rc<_>s into weak pointers.
        SRSSpec::Use(unsafe { &*Rc::into_raw(urs_copy) })
    };
    Ok(WasmPastaFpPlonkIndex(
        Box::new(DlogIndex::<GAffine>::create(
            cs,
            oracle::pasta::fq::params(),
            endo_q,
            srs,
        )),
        urs_copy_outer,
    ))
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_max_degree(index: &WasmPastaFpPlonkIndex) -> i32 {
    index.0.srs.get_ref().max_degree() as i32
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
    urs: &WasmPastaFpUrs,
    path: String,
) -> Result<WasmPastaFpPlonkIndex, JsValue> {
    let file = match File::open(path) {
        Err(err) => Err(
            JsValue::from_str(format!("caml_pasta_fp_plonk_index_read: {}", err).as_str()),
        )?,
        Ok(file) => file,
    };
    let mut r = BufReader::new(file);
    match offset {
        Some(offset) => {
            r.seek(Start(offset as u64)).map_err(|err| {
                JsValue::from_str(format!("caml_pasta_fp_plonk_index_read: {}", err).as_str())
            })?;
        }
        None => (),
    };
    let urs_copy = Rc::clone(&**urs);
    let urs_copy_outer = Rc::clone(&**urs);
    let srs = {
        // We know that the underlying value is still alive, because we never convert any of our
        // Rc<_>s into weak pointers.
        unsafe { &*Rc::into_raw(urs_copy) }
    };
    let t = index_serialization::read_plonk_index(
        oracle::pasta::fp::params(),
        oracle::pasta::fq::params(),
        srs,
        &mut r,
    ).map_err(|err| {
        JsValue::from_str(format!("caml_pasta_fp_plonk_index_read: {}", err).as_str())
    })?;
    Ok(WasmPastaFpPlonkIndex(Box::new(t), urs_copy_outer))
}

#[wasm_bindgen]
pub fn caml_pasta_fp_plonk_index_write(
    append: Option<bool>,
    index: &WasmPastaFpPlonkIndex,
    path: String,
) -> Result<(), JsValue> {
    let file = match OpenOptions::new().append(append.unwrap_or(true)).open(path) {
        Err(err) => Err(JsValue::from_str(format!("caml_pasta_fp_plonk_index_write: {}", err).as_str()))?,
        Ok(file) => file,
    };
    let mut w = BufWriter::new(file);
    index_serialization::write_plonk_index(&index.0, &mut w).map_err(|err| {
        JsValue::from_str(format!("caml_pasta_fp_plonk_index_write: {}", err).as_str())
    })
}
