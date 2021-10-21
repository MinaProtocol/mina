use crate::{gate_vector::fp::CamlPastaFpPlonkGateVectorPtr, srs::fp::CamlFpSrs};
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use mina_curves::pasta::{fp::Fp, pallas::Affine as GAffineOther, vesta::Affine as GAffine};
use ocaml_gen::{ocaml_gen, OCamlCustomType};
use plonk_15_wires_circuits::{
    gate::CircuitGate,
    nolookup::constraints::ConstraintSystem,
    wires::{GateWires, Wire},
};
use plonk_15_wires_protocol_dlog::index::Index as DlogIndex;
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

//
// CamlPastaFpPlonkIndex (custom type)
//

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(OCamlCustomType)]
pub struct CamlPastaFpPlonkIndex(pub Box<DlogIndex<GAffine>>);
pub type CamlPastaFpPlonkIndexPtr<'a> = ocaml::Pointer<'a, CamlPastaFpPlonkIndex>;

extern "C" fn caml_pasta_fp_plonk_index_finalize(v: ocaml::Raw) {
    unsafe {
        let mut v: CamlPastaFpPlonkIndexPtr = v.as_pointer();
        v.as_mut_ptr().drop_in_place();
    }
}

ocaml::custom!(CamlPastaFpPlonkIndex {
    finalize: caml_pasta_fp_plonk_index_finalize,
});

//
// CamlPastaFpPlonkIndex methods
//

// shifted rows/cols, why? not sure
fn shift_wires(domain_size: usize, wires: GateWires) -> GateWires {
    array_init::array_init(|col: usize| {
        let shift = col * domain_size;
        let row = wires[col].row + shift;
        let col = wires[col].col + shift;
        Wire { row, col }
    })
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_create(
    gates: CamlPastaFpPlonkGateVectorPtr,
    public: ocaml::Int,
    srs: CamlFpSrs,
) -> Result<CamlPastaFpPlonkIndex, ocaml::Error> {
    // create domain
    let domain_size =
        Domain::<Fp>::compute_size_of_domain(gates.as_ref().0.len()).ok_or_else(|| {
            ocaml::Error::invalid_argument("caml_pasta_fp_plonk_index_create")
                .err()
                .unwrap()
        })?;

    // flatten the permutation information (because OCaml has a different way of keeping track of permutations)
    let gates: Vec<_> = gates
        .as_ref()
        .0
        .iter()
        .map(|gate| CircuitGate::<Fp> {
            row: gate.row,
            typ: gate.typ,
            wires: shift_wires(domain_size, gate.wires),
            c: gate.c.clone(),
        })
        .collect();

    // create constraint system
    let cs = match ConstraintSystem::<Fp>::create(
        gates,
        vec![vec![]],
        oracle::pasta::fp::params(),
        public as usize,
    ) {
        None => {
            return Err(ocaml::Error::failwith(
                "caml_pasta_fp_plonk_index_create: could not create constraint system",
            )
            .err()
            .unwrap())
        }
        Some(cs) => cs,
    };

    // endo
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();

    // create index
    Ok(CamlPastaFpPlonkIndex(Box::new(
        DlogIndex::<GAffine>::create(cs, oracle::pasta::fq::params(), endo_q, srs.clone()),
    )))
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_max_degree(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.srs.max_degree() as isize
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_public_inputs(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.public as isize
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_domain_d1_size(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d1.size() as isize
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_domain_d4_size(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d4.size() as isize
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_domain_d8_size(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d8.size() as isize
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFpSrs,
    path: String,
) -> Result<CamlPastaFpPlonkIndex, ocaml::Error> {
    // read from file
    let file = match File::open(path) {
        Err(_) => {
            return Err(
                ocaml::Error::invalid_argument("caml_pasta_fp_plonk_index_read")
                    .err()
                    .unwrap(),
            )
        }
        Ok(file) => file,
    };
    let mut r = BufReader::new(file);

    // optional offset in file
    if let Some(offset) = offset {
        r.seek(Start(offset as u64))?;
    }

    // deserialize the index
    let mut t: DlogIndex<GAffine> = bincode::deserialize_from(&mut r)?;
    t.cs.fr_sponge_params = oracle::pasta::fp::params();
    t.srs = srs.clone();
    t.fq_sponge_params = oracle::pasta::fq::params();

    //
    Ok(CamlPastaFpPlonkIndex(Box::new(t)))
}

#[ocaml_gen]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_write(
    append: Option<bool>,
    index: CamlPastaFpPlonkIndexPtr<'static>,
    path: String,
) -> Result<(), ocaml::Error> {
    let file = OpenOptions::new()
        .append(append.unwrap_or(true))
        .open(path)
        .map_err(|_| {
            ocaml::Error::invalid_argument("caml_pasta_fp_plonk_index_write")
                .err()
                .unwrap()
        })?;
    let mut w = BufWriter::new(file);
    bincode::serialize_into(&mut w, &index.as_ref().0).map_err(|e| e.into())
}
