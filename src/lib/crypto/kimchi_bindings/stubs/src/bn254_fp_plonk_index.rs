use crate::arkworks::CamlBn254Fp;
use crate::{
    gate_vector::bn254_fp::CamlBn254FpPlonkGateVectorPtr, pairing_srs::bn254_fp::CamlBn254FpSrs,
};
use ark_bn254::Parameters;
use ark_ec::bn::Bn;
use ark_poly::EvaluationDomain;
use kimchi::circuits::lookup::runtime_tables::caml::CamlRuntimeTableCfg;
use kimchi::circuits::lookup::runtime_tables::RuntimeTableCfg;
use kimchi::circuits::lookup::tables::caml::CamlLookupTable;
use kimchi::circuits::lookup::tables::LookupTable;
use kimchi::circuits::{constraints::ConstraintSystem, gate::CircuitGate};
use kimchi::curve::KimchiCurve;
use kimchi::{linearization::expr_linearization, prover_index::ProverIndex};
use mina_curves::bn254::{Bn254, Bn254Parameters, Fp};
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, sponge::DefaultFqSponge};
use poly_commitment::{pairing_proof::PairingProof, SRS as _};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom::Start},
};

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
pub struct CamlBn254FpPlonkIndex(pub Box<ProverIndex<Bn254, PairingProof<Bn<Parameters>>>>);
pub type CamlBn254FpPlonkIndexPtr<'a> = ocaml::Pointer<'a, CamlBn254FpPlonkIndex>;

extern "C" fn caml_bn254_fp_plonk_index_finalize(v: ocaml::Raw) {
    unsafe {
        let mut v: CamlBn254FpPlonkIndexPtr = v.as_pointer();
        v.as_mut_ptr().drop_in_place();
    }
}

impl ocaml::custom::Custom for CamlBn254FpPlonkIndex {
    const NAME: &'static str = "CamlBn254FpPlonkIndex\0";
    const USED: usize = 1;
    /// Encourage the GC to free when there are > 12 in memory
    const MAX: usize = 12;
    const OPS: ocaml::custom::CustomOps = ocaml::custom::CustomOps {
        identifier: Self::NAME.as_ptr() as *const ocaml::sys::Char,
        finalize: Some(caml_bn254_fp_plonk_index_finalize),
        ..ocaml::custom::DEFAULT_CUSTOM_OPS
    };
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_create(
    gates: CamlBn254FpPlonkGateVectorPtr,
    public: ocaml::Int,
    lookup_tables: Vec<CamlLookupTable<CamlBn254Fp>>,
    runtime_tables: Vec<CamlRuntimeTableCfg<CamlBn254Fp>>,
    prev_challenges: ocaml::Int,
    srs: CamlBn254FpSrs,
) -> Result<CamlBn254FpPlonkIndex, ocaml::Error> {
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
        .max_poly_size(Some(srs.0.full_srs.max_poly_size()))
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
    let &endo_q = Bn254::other_curve_endo();

    // Unsafe if we are in a multi-core ocaml
    {
        let ptr: &mut poly_commitment::srs::SRS<Bn254> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
        ptr.add_lagrange_basis(cs.domain.d1);
    }

    // create index
    let mut index =
        ProverIndex::<Bn254, PairingProof<Bn<Parameters>>>::create(cs, endo_q, srs.clone());
    // Compute and cache the verifier index digest
    index.compute_verifier_index_digest::<DefaultFqSponge<Bn254Parameters, PlonkSpongeConstantsKimchi>>();

    Ok(CamlBn254FpPlonkIndex(Box::new(index)))
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_max_degree(index: CamlBn254FpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.srs.full_srs.max_degree() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_public_inputs(index: CamlBn254FpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.public as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_domain_d1_size(index: CamlBn254FpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d1.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_domain_d4_size(index: CamlBn254FpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d4.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_domain_d8_size(index: CamlBn254FpPlonkIndexPtr) -> ocaml::Int {
    index.as_ref().0.cs.domain.d8.size() as isize
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_read(
    offset: Option<ocaml::Int>,
    srs: CamlBn254FpSrs,
    path: String,
) -> Result<CamlBn254FpPlonkIndex, ocaml::Error> {
    // open the file for reading
    let file = match File::open(path) {
        Err(_) => {
            return Err(
                ocaml::Error::invalid_argument("caml_bn254_fp_plonk_index_read")
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
    let mut t = ProverIndex::<Bn254, PairingProof<Bn<Parameters>>>::deserialize(
        &mut rmp_serde::Deserializer::new(r),
    )?;
    t.srs = srs.clone();

    let (linearization, powers_of_alpha) = expr_linearization(Some(&t.cs.feature_flags), true);
    t.linearization = linearization;
    t.powers_of_alpha = powers_of_alpha;

    Ok(CamlBn254FpPlonkIndex(Box::new(t)))
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_fp_plonk_index_write(
    append: Option<bool>,
    index: CamlBn254FpPlonkIndexPtr<'static>,
    path: String,
) -> Result<(), ocaml::Error> {
    let file = OpenOptions::new()
        .append(append.unwrap_or(true))
        .open(path)
        .map_err(|_| {
            ocaml::Error::invalid_argument("caml_bn254_fp_plonk_index_write")
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
