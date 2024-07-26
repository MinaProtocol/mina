use crate::arkworks::CamlFp;
use crate::WithLagrangeBasis;
use crate::{gate_vector::fp::CamlPastaFpPlonkGateVectorPtr, srs::fp::CamlFpSrs};
use ark_poly::EvaluationDomain;
use kimchi::circuits::lookup::runtime_tables::caml::CamlRuntimeTableCfg;
use kimchi::circuits::lookup::runtime_tables::RuntimeTableCfg;
use kimchi::circuits::lookup::tables::caml::CamlLookupTable;
use kimchi::circuits::lookup::tables::LookupTable;
use kimchi::circuits::{constraints::ConstraintSystem, gate::CircuitGate};
use kimchi::{linearization::expr_linearization, prover_index::ProverIndex};
use mina_curves::pasta::{Fp, Pallas, Vesta, VestaParameters};
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, sponge::DefaultFqSponge};
use poly_commitment::{evaluation_proof::OpeningProof, SRS as _};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
pub struct CamlPastaFpPlonkIndex(pub Box<ProverIndex<Vesta, OpeningProof<Vesta>>>);
pub type CamlPastaFpPlonkIndexPtr<'a> = ocaml::Pointer<'a, CamlPastaFpPlonkIndex>;

extern "C" fn caml_pasta_fp_plonk_index_finalize(v: ocaml::Raw) {
    unsafe {
        let mut v: CamlPastaFpPlonkIndexPtr = v.as_pointer();
        v.as_mut_ptr().drop_in_place();
    }
}

impl ocaml::custom::Custom for CamlPastaFpPlonkIndex {
    const NAME: &'static str = "CamlPastaFpPlonkIndex\0";
    const USED: usize = 1;
    /// Encourage the GC to free when there are > 12 in memory
    const MAX: usize = 12;
    const OPS: ocaml::custom::CustomOps = ocaml::custom::CustomOps {
        identifier: Self::NAME.as_ptr() as *const ocaml::sys::Char,
        finalize: Some(caml_pasta_fp_plonk_index_finalize),
        ..ocaml::custom::DEFAULT_CUSTOM_OPS
    };
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_index_create(
    gates: CamlPastaFpPlonkGateVectorPtr,
    public: ocaml::Int,
    lookup_tables: Vec<CamlLookupTable<CamlFp>>,
    runtime_tables: Vec<CamlRuntimeTableCfg<CamlFp>>,
    prev_challenges: ocaml::Int,
    srs: CamlFpSrs,
) -> Result<CamlPastaFpPlonkIndex, ocaml::Error> {
    let gates: Vec<_> = gates
        .as_ref()
        .0
        .iter()
        .map(|gate| CircuitGate::<Fp> {
            typ: gate.typ,
            wires: gate.wires,
            coeffs: gate.coeffs.clone(),
        })
        .collect();

    let runtime_tables: Vec<RuntimeTableCfg<Fp>> =
        runtime_tables.into_iter().map(Into::into).collect();

    let lookup_tables: Vec<LookupTable<Fp>> = lookup_tables.into_iter().map(Into::into).collect();

    // create constraint system
    let cs = match ConstraintSystem::<Fp>::create(gates)
        .public(public as usize)
        .prev_challenges(prev_challenges as usize)
        .max_poly_size(Some(srs.0.max_poly_size()))
        .lookup(lookup_tables)
        .runtime(if runtime_tables.is_empty() {
            None
        } else {
            Some(runtime_tables)
        })
        .build()
    {
        Err(e) => return Err(e.into()),
        Ok(cs) => cs,
    };

    // endo
    let (endo_q, _endo_r) = poly_commitment::srs::endos::<Pallas>();

    // Unsafe if we are in a multi-core ocaml
    {
        let ptr: &mut poly_commitment::srs::SRS<Vesta> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
        ptr.with_lagrange_basis(cs.domain.d1);
    }

    // create index
    let mut index = ProverIndex::<Vesta, OpeningProof<Vesta>>::create(cs, endo_q, srs.clone());
    // Compute and cache the verifier index digest
    index.compute_verifier_index_digest::<DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>>();

    Ok(CamlPastaFpPlonkIndex(Box::new(index)))
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
    let mut t = ProverIndex::<Vesta, OpeningProof<Vesta>>::deserialize(
        &mut rmp_serde::Deserializer::new(r),
    )?;
    t.srs = srs.clone();

    let (linearization, powers_of_alpha) = expr_linearization(Some(&t.cs.feature_flags), true);
    t.linearization = linearization;
    t.powers_of_alpha = powers_of_alpha;

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
