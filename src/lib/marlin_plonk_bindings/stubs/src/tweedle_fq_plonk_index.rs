#[allow(unused_imports)]
use algebra::tweedle::{
    dee::Affine as GAffineOther,
    dum::{Affine as GAffine, TweedledumParameters},
    fq::Fq,
};

use plonk_circuits::constraints::ConstraintSystem;
use plonk_circuits::gate::CircuitGate;
use plonk_circuits::wires::Wire;

use ff_fft::EvaluationDomain;

use commitment_dlog::srs::SRS;
use plonk_protocol_dlog::index::{Index as DlogIndex, SRSSpec};

use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
    rc::Rc,
};

use crate::index_serialization;
use crate::plonk_gate::{CamlPlonkGate, CamlPlonkWire, CamlPlonkWires};
use crate::tweedle_fq_urs::CamlTweedleFqUrs;

pub struct CamlTweedleFqPlonkGateVector(Vec<CircuitGate<Fq>>);
pub type CamlTweedleFqPlonkGateVectorPtr = ocaml::Pointer<CamlTweedleFqPlonkGateVector>;

extern "C" fn caml_tweedle_fq_plonk_gate_vector_finalize(v: ocaml::Value) {
    let v: CamlTweedleFqPlonkGateVectorPtr = ocaml::FromValue::from_value(v);
    unsafe { v.drop_in_place() };
}

ocaml::custom!(CamlTweedleFqPlonkGateVector {
    finalize: caml_tweedle_fq_plonk_gate_vector_finalize,
});

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_gate_vector_create() -> CamlTweedleFqPlonkGateVector {
    CamlTweedleFqPlonkGateVector(Vec::new())
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_gate_vector_add(
    mut v: CamlTweedleFqPlonkGateVectorPtr,
    gate: CamlPlonkGate<Vec<Fq>>,
) {
    v.as_mut().0.push(CircuitGate {
        typ: gate.typ.into(),
        row: gate.row as usize,
        wires: [
            gate.wires.l.into(),
            gate.wires.r.into(),
            gate.wires.o.into(),
            gate.wires.q.into(),
            gate.wires.p.into()
        ],
        c: gate.c,
    });
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_gate_vector_get(
    v: CamlTweedleFqPlonkGateVectorPtr,
    i: ocaml::Int,
) -> CamlPlonkGate<Vec<Fq>> {
    let gate = &(v.as_ref().0)[i as usize];
    let c = gate.c.iter().map(|x| *x).collect();
    CamlPlonkGate {
        typ: (&gate.typ).into(),
        row: gate.row as isize,
        wires: CamlPlonkWires
        {
            l: (&gate.wires[0]).into(),
            r: (&gate.wires[1]).into(),
            o: (&gate.wires[2]).into(),
            q: (&gate.wires[3]).into(),
            p: (&gate.wires[4]).into(),
        },
        c,
    }
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_gate_vector_wrap(
    mut v: CamlTweedleFqPlonkGateVectorPtr,
    t: CamlPlonkWire,
    h: CamlPlonkWire,
) {
    (v.as_mut().0)[t.row as usize].wires[t.col as usize] =
        Wire
        {
            row: h.row as usize,
            col: h.col as usize,
        };
}

/* Boxed so that we don't store large proving indexes in the OCaml heap. */

pub struct CamlTweedleFqPlonkIndex<'a>(pub Box<DlogIndex<'a, GAffine>>, pub Rc<SRS<GAffine>>);
pub type CamlTweedleFqPlonkIndexPtr<'a> = ocaml::Pointer<CamlTweedleFqPlonkIndex<'a>>;

extern "C" fn caml_tweedle_fq_plonk_index_finalize(v: ocaml::Value) {
    let mut v: CamlTweedleFqPlonkIndexPtr = ocaml::FromValue::from_value(v);
    unsafe {
        v.as_mut_ptr().drop_in_place();
    }
}

ocaml::custom!(CamlTweedleFqPlonkIndex<'a> {
    finalize: caml_tweedle_fq_plonk_index_finalize,
});

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_create(
    gates: CamlTweedleFqPlonkGateVectorPtr,
    public: ocaml::Int,
    urs: CamlTweedleFqUrs,
) -> Result<CamlTweedleFqPlonkIndex<'static>, ocaml::Error> {
    let gates: Vec<_> = gates.as_ref().0.clone();

    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();
    let cs =
        match ConstraintSystem::<Fq>::create(gates, oracle::tweedle::fq5::params(), public as usize)
        {
            None => Err(ocaml::Error::failwith(
                "caml_tweedle_fq_plonk_index_create: could not create constraint system",
            )
            .err()
            .unwrap())?,
            Some(cs) => cs,
        };
    let urs_copy = Rc::clone(&urs.0);
    let urs_copy_outer = Rc::clone(&urs.0);
    let srs = {
        // We know that the underlying value is still alive, because we never convert any of our
        // Rc<_>s into weak pointers.
        SRSSpec::Use(unsafe { &*Rc::into_raw(urs_copy) })
    };
    Ok(CamlTweedleFqPlonkIndex(
        Box::new(DlogIndex::<GAffine>::create(
            cs,
            oracle::tweedle::fp5::params(),
            endo_q,
            srs,
        )),
        urs_copy_outer,
    ))
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_max_degree(index: CamlTweedleFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.srs.get_ref().max_degree() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_public_inputs(index: CamlTweedleFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.public as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_domain_d1_size(index: CamlTweedleFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d1.size() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_domain_d4_size(index: CamlTweedleFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d4.size() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_domain_d8_size(index: CamlTweedleFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d8.size() as isize
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_read(
    offset: Option<ocaml::Int>,
    urs: CamlTweedleFqUrs,
    path: String,
) -> Result<CamlTweedleFqPlonkIndex<'static>, ocaml::Error> {
    let file = match File::open(path) {
        Err(_) => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fq_plonk_index_read")
                .err()
                .unwrap(),
        )?,
        Ok(file) => file,
    };
    let mut r = BufReader::new(file);
    match offset {
        Some(offset) => {
            r.seek(Start(offset as u64))?;
        }
        None => (),
    };
    let urs_copy = Rc::clone(&urs.0);
    let urs_copy_outer = Rc::clone(&urs.0);
    let srs = {
        // We know that the underlying value is still alive, because we never convert any of our
        // Rc<_>s into weak pointers.
        unsafe { &*Rc::into_raw(urs_copy) }
    };
    let t = index_serialization::read_plonk_index(
        oracle::tweedle::fq::params(),
        oracle::tweedle::fp::params(),
        srs,
        &mut r,
    )?;
    Ok(CamlTweedleFqPlonkIndex(Box::new(t), urs_copy_outer))
}

#[ocaml::func]
pub fn caml_tweedle_fq_plonk_index_write(
    append: Option<bool>,
    index: CamlTweedleFqPlonkIndexPtr<'static>,
    path: String,
) -> Result<(), ocaml::Error> {
    let file = match OpenOptions::new().append(append.unwrap_or(true)).open(path) {
        Err(_) => Err(
            ocaml::Error::invalid_argument("caml_tweedle_fq_plonk_index_write")
                .err()
                .unwrap(),
        )?,
        Ok(file) => file,
    };
    let mut w = BufWriter::new(file);
    index_serialization::write_plonk_index(&index.as_ref().0, &mut w)?;
    Ok(())
}
