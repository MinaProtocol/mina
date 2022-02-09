use crate::{gate_vector::fp::CamlPastaFpPlonkGateVectorPtr, srs::fp::CamlFpSrs};
use ark_poly::EvaluationDomain;
use kimchi::index::{expr_linearization, Index as DlogIndex};
use kimchi::circuits::{gate::CircuitGate, constraints::ConstraintSystem};
use mina_curves::pasta::{fp::Fp, pallas::Affine as GAffineOther, vesta::Affine as GAffine};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
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

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_create(
    gates: CamlPastaFpPlonkGateVectorPtr,
    public: ocaml::Int,
    srs: CamlFpSrs,
) -> Result<CamlPastaFpPlonkIndex, ocaml::Error> {
    let gates: Vec<_> = gates
        .as_ref()
        .0
        .iter()
        .map(|gate| CircuitGate::<Fp> {
            typ: gate.typ,
            wires: gate.wires,
            c: gate.c.clone(),
        })
        .collect();

    // create constraint system
    let cs = match ConstraintSystem::<Fp>::create(
        gates,
        vec![],
        oracle::pasta::fp_3::params(),
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

    // Unsafe if we are in a multi-core ocaml
    {
        let ptr: &mut commitment_dlog::srs::SRS<GAffine> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
        ptr.add_lagrange_basis(cs.domain.d1);
    }

    // create index
    Ok(CamlPastaFpPlonkIndex(Box::new(
        DlogIndex::<GAffine>::create(cs, oracle::pasta::fq_3::params(), endo_q, srs.clone()),
    )))
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_max_degree(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.srs.max_degree() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_public_inputs(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.public as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_domain_d1_size(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d1.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_domain_d4_size(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d4.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_domain_d8_size(index: CamlPastaFpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d8.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlFpSrs,
    path: String,
) -> Result<CamlPastaFpPlonkIndex, ocaml::Error> {
    // open the file for reading
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
    t.cs.fr_sponge_params = oracle::pasta::fp_3::params();
    t.srs = srs.clone();
    t.fq_sponge_params = oracle::pasta::fq_3::params();
    t.linearization = expr_linearization(t.cs.domain.d1, false, None);

    Ok(CamlPastaFpPlonkIndex(Box::new(t)))
}

#[ocaml_gen::func]
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
    let w = BufWriter::new(file);
    index
        .as_ref()
        .0
        .serialize(&mut rmp_serde::Serializer::new(w))
        .map_err(|e| e.into())
}
