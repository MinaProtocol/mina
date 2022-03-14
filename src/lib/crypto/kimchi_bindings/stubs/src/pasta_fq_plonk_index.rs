use crate::{gate_vector::fq::CamlPastaFqPlonkGateVectorPtr, srs::fq::CamlFqSrs};
use ark_poly::EvaluationDomain;
use kimchi::circuits::{constraints::ConstraintSystem, gate::CircuitGate};
use kimchi::{linearization::expr_linearization, prover_index::ProverIndex};
use mina_curves::pasta::{fq::Fq, pallas::Affine as GAffine, vesta::Affine as GAffineOther};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
pub struct CamlPastaFqPlonkIndex(pub Box<ProverIndex<GAffine>>);
pub type CamlPastaFqPlonkIndexPtr<'a> = ocaml::Pointer<'a, CamlPastaFqPlonkIndex>;

extern "C" fn caml_pasta_fq_plonk_index_finalize(v: ocaml::Raw) {
    unsafe {
        let mut v: CamlPastaFqPlonkIndexPtr = v.as_pointer();
        v.as_mut_ptr().drop_in_place();
    }
}

impl ocaml::custom::Custom for CamlPastaFqPlonkIndex {
    const NAME: &'static str = "CamlPastaFqPlonkIndex\0";
    const USED: usize = 1;
    /// Encourage the GC to free when there are > 12 in memory
    const MAX: usize = 12;
    const OPS: ocaml::custom::CustomOps = ocaml::custom::CustomOps {
        identifier: Self::NAME.as_ptr() as *const ocaml::sys::Char,
        finalize: Some(caml_pasta_fq_plonk_index_finalize),
        ..ocaml::custom::DEFAULT_CUSTOM_OPS
    };
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fq_plonk_index_create(
    gates: CamlPastaFqPlonkGateVectorPtr,
    public: ocaml::Int,
    srs: CamlFqSrs,
) -> Result<CamlPastaFqPlonkIndex, ocaml::Error> {
    let gates: Vec<_> = gates
        .as_ref()
        .0
        .iter()
        .map(|gate| CircuitGate::<Fq> {
            typ: gate.typ,
            wires: gate.wires,
            coeffs: gate.coeffs.clone(),
        })
        .collect();

    // create constraint system
    let cs = match ConstraintSystem::<Fq>::create(
        gates,
        vec![],
        oracle::pasta::fq_kimchi::params(),
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

    // Unsafe if we are in a multi-core ocaml
    {
        let ptr: &mut commitment_dlog::srs::SRS<GAffine> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
        ptr.add_lagrange_basis(cs.domain.d1);
    }

    // create index
    Ok(CamlPastaFqPlonkIndex(Box::new(ProverIndex::<GAffine>::create(
        cs,
        oracle::pasta::fp_kimchi::params(),
        endo_q,
        srs.clone(),
    ))))
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
    let mut t = ProverIndex::<GAffine>::deserialize(&mut rmp_serde::Deserializer::new(r))?;
    t.cs.fr_sponge_params = oracle::pasta::fq_kimchi::params();
    t.srs = srs.clone();
    t.fq_sponge_params = oracle::pasta::fp_kimchi::params();

    let (linearization, powers_of_alpha) = expr_linearization(t.cs.domain.d1, false, &None);
    t.linearization = linearization;
    t.powers_of_alpha = powers_of_alpha;

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
