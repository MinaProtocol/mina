use crate::{gate_vector::fq::CamlPastaFqPlonkGateVectorPtr, srs::fq::CamlFqSrs};
use ark_poly::EvaluationDomain;
use kimchi::index::Index as DlogIndex;
use kimchi_circuits::{gate::CircuitGate, nolookup::constraints::ConstraintSystem};
use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine, vesta::Affine as GAffineOther};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
pub struct CamlPastaFqPlonkIndex(pub Box<DlogIndex<GAffine>>);
pub type CamlPastaFqPlonkIndexPtr<'a> = ocaml::Pointer<'a, CamlPastaFqPlonkIndex>;

extern "C" fn caml_pasta_fq_plonk_index_finalize(v: ocaml::Raw) {
    unsafe {
        let mut v: CamlPastaFqPlonkIndexPtr = v.as_pointer();
        v.as_mut_ptr().drop_in_place();
    }
}

ocaml::custom!(CamlPastaFqPlonkIndex {
    finalize: caml_pasta_fq_plonk_index_finalize,
});

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_create(
    gates: CamlPastaFqPlonkGateVectorPtr,
    public: ocaml::Int,
    srs: CamlFqSrs,
) -> Result<CamlPastaFqPlonkIndex, ocaml::Error> {
    // flatten the permutation information (because OCaml has a different way of keeping track of permutations)
    let gates: Vec<_> = gates
        .as_ref()
        .0
        .iter()
        .map(|gate| CircuitGate::<Fq> {
            row: gate.row,
            typ: gate.typ,
            wires: gate.wires,
            c: gate.c.clone(),
        })
        .collect();

    // create constraint system
    let cs = match ConstraintSystem::<Fq>::create(
        gates,
        vec![],
        oracle::pasta::fq::params(),
        public as usize,
    ) {
        None => {
            return Err(ocaml::Error::failwith(
                "caml_pasta_fq_plonk_index_create: could not create constraint system",
            )
            .err()
            .unwrap())
        }
        Some(cs) => cs,
    };

    // endo
    let (endo_q, _endo_r) = commitment_dlog::srs::endos::<GAffineOther>();

    // create index
    Ok(CamlPastaFqPlonkIndex(Box::new(
        DlogIndex::<GAffine>::create(cs, oracle::pasta::fp::params(), endo_q, srs.clone()),
    )))
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_max_degree(index: CamlPastaFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.srs.max_degree() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_public_inputs(index: CamlPastaFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.public as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_domain_d1_size(index: CamlPastaFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d1.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_domain_d4_size(index: CamlPastaFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d4.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_domain_d8_size(index: CamlPastaFqPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d8.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFqSrs,
    path: String,
) -> Result<CamlPastaFqPlonkIndex, ocaml::Error> {
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
    let mut t = DlogIndex::<GAffine>::deserialize(&mut rmp_serde::Deserializer::new(r))?;
    t.cs.fr_sponge_params = oracle::pasta::fq::params();
    t.srs = srs.clone();
    t.fq_sponge_params = oracle::pasta::fp::params();

    Ok(CamlPastaFqPlonkIndex(Box::new(t)))
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_write(
    append: Option<bool>,
    index: CamlPastaFqPlonkIndexPtr<'static>,
    path: String,
) -> Result<(), ocaml::Error> {
    let file = OpenOptions::new()
        .append(append.unwrap_or(true))
        .open(path)
        .map_err(|_| {
            ocaml::Error::invalid_argument("caml_pasta_fq_plonk_index_write")
                .err()
                .unwrap()
        })?;
    let w = BufWriter::new(file);
    index
        .as_ref()
        .0
        .serialize(&mut rmp_serde::Serializer::new(w))
        .map_err(|e| e.into())
}
