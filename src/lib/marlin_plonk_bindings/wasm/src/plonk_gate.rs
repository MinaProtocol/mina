use wasm_bindgen::prelude::*;
use plonk_circuits::gate::{GateType, GateType::*};
use plonk_circuits::wires::{Col, Col::*, Wire, Wires};

#[wasm_bindgen]
#[derive(Copy, Clone)]
pub enum WasmPlonkGateType {
    Zero,    // zero gate
    Generic, // generic arithmetic gate

    Poseidon, // Poseidon permutation gate

    Add1, // Gate constraining EC addition in Affine form
    Add2, // Gate constraining EC point abscissa distinctness

    Vbmul1, // Gate constraining EC variable base scalar multiplication
    Vbmul2, // Gate constraining EC variable base scalar multiplication
    Vbmul3, // Gate constraining EC variable base scalar multiplication

    Endomul1, // Gate constraining EC variable base scalar multiplication with group endomorphim optimization
    Endomul2, // Gate constraining EC variable base scalar multiplication with group endomorphim optimization
    Endomul3, // Gate constraining EC variable base scalar multiplication with group endomorphim optimization
    Endomul4, // Gate constraining EC variable base scalar multiplication with group endomorphim optimization
}

impl From<&GateType> for WasmPlonkGateType {
    fn from(gate_type: &GateType) -> Self {
        match gate_type {
            Zero => WasmPlonkGateType::Zero,
            Generic => WasmPlonkGateType::Generic,
            Poseidon => WasmPlonkGateType::Poseidon,
            Add1 => WasmPlonkGateType::Add1,
            Add2 => WasmPlonkGateType::Add2,
            Vbmul1 => WasmPlonkGateType::Vbmul1,
            Vbmul2 => WasmPlonkGateType::Vbmul2,
            Vbmul3 => WasmPlonkGateType::Vbmul3,
            Endomul1 => WasmPlonkGateType::Endomul1,
            Endomul2 => WasmPlonkGateType::Endomul2,
            Endomul3 => WasmPlonkGateType::Endomul3,
            Endomul4 => WasmPlonkGateType::Endomul4,
        }
    }
}
impl From<GateType> for WasmPlonkGateType {
    fn from(gate_type: GateType) -> Self {
        Self::from(&gate_type)
    }
}

impl From<&WasmPlonkGateType> for GateType {
    fn from(gate_type: &WasmPlonkGateType) -> Self {
        match gate_type {
            WasmPlonkGateType::Zero => Zero,
            WasmPlonkGateType::Generic => Generic,
            WasmPlonkGateType::Poseidon => Poseidon,
            WasmPlonkGateType::Add1 => Add1,
            WasmPlonkGateType::Add2 => Add2,
            WasmPlonkGateType::Vbmul1 => Vbmul1,
            WasmPlonkGateType::Vbmul2 => Vbmul2,
            WasmPlonkGateType::Vbmul3 => Vbmul3,
            WasmPlonkGateType::Endomul1 => Endomul1,
            WasmPlonkGateType::Endomul2 => Endomul2,
            WasmPlonkGateType::Endomul3 => Endomul3,
            WasmPlonkGateType::Endomul4 => Endomul4,
        }
    }
}
impl From<WasmPlonkGateType> for GateType {
    fn from(gate_type: WasmPlonkGateType) -> Self {
        Self::from(&gate_type)
    }
}

#[wasm_bindgen]
#[derive(Copy, Clone)]
pub enum WasmPlonkCol {
    L,
    R,
    O,
}

impl From<&Col> for WasmPlonkCol {
    fn from(col: &Col) -> Self {
        match col {
            L => WasmPlonkCol::L,
            R => WasmPlonkCol::R,
            O => WasmPlonkCol::O,
        }
    }
}

impl From<Col> for WasmPlonkCol {
    fn from(col: Col) -> Self {
        Self::from(&col)
    }
}

impl From<&WasmPlonkCol> for Col {
    fn from(col: &WasmPlonkCol) -> Self {
        match col {
            WasmPlonkCol::L => L,
            WasmPlonkCol::R => R,
            WasmPlonkCol::O => O,
        }
    }
}

impl From<WasmPlonkCol> for Col {
    fn from(col: WasmPlonkCol) -> Self {
        Self::from(&col)
    }
}

#[wasm_bindgen]
#[derive(Copy, Clone)]
pub struct WasmPlonkWire {
    pub row: i32,   // wire row
    pub col: WasmPlonkCol, // wire column
}

#[wasm_bindgen]
impl WasmPlonkWire {
    #[wasm_bindgen(constructor)]
    pub fn new(row: i32, col: WasmPlonkCol) -> WasmPlonkWire {
        WasmPlonkWire {row, col}
    }
}

impl From<&Wire> for WasmPlonkWire {
    fn from(wire: &Wire) -> Self {
        WasmPlonkWire {
            row: wire.row as i32,
            col: (&wire.col).into(),
        }
    }
}
impl From<Wire> for WasmPlonkWire {
    fn from(wire: Wire) -> Self {
        Self::from(&wire)
    }
}

impl From<&WasmPlonkWire> for Wire {
    fn from(wire: &WasmPlonkWire) -> Self {
        Wire {
            row: wire.row as usize,
            col: (&wire.col).into(),
        }
    }
}
impl From<WasmPlonkWire> for Wire {
    fn from(wire: WasmPlonkWire) -> Self {
        Self::from(&wire)
    }
}

#[wasm_bindgen]
#[derive(Copy, Clone)]
pub struct WasmPlonkWires {
    pub row: i32,  // gate wire row
    pub l: WasmPlonkWire, // left input wire permutation
    pub r: WasmPlonkWire, // right input wire permutation
    pub o: WasmPlonkWire, // output input wire permutation
}

#[wasm_bindgen]
impl WasmPlonkWires {
    #[wasm_bindgen(constructor)]
    pub fn new(row: i32, l: WasmPlonkWire, r: WasmPlonkWire, o: WasmPlonkWire) -> WasmPlonkWires {
        WasmPlonkWires {row, l, r, o}
    }
}

impl From<&Wires> for WasmPlonkWires {
    fn from(wires: &Wires) -> Self {
        WasmPlonkWires {
            row: wires.row as i32,
            l: (&wires.l).into(),
            r: (&wires.r).into(),
            o: (&wires.o).into(),
        }
    }
}
impl From<Wires> for WasmPlonkWires {
    fn from(wires: Wires) -> Self {
        Self::from(&wires)
    }
}

impl From<&WasmPlonkWires> for Wires {
    fn from(wires: &WasmPlonkWires) -> Self {
        Wires {
            row: wires.row as usize,
            l: (&wires.l).into(),
            r: (&wires.r).into(),
            o: (&wires.o).into(),
        }
    }
}
impl From<WasmPlonkWires> for Wires {
    fn from(wires: WasmPlonkWires) -> Self {
        Self::from(&wires)
    }
}

/*
#[wasm_bindgen]
pub struct WasmPlonkGate<T> {
    pub typ: WasmPlonkGateType, // type of the gate
    pub wires: WasmPlonkWires,  // gate wires
    pub c: T,                   // constraints vector
}
*/
