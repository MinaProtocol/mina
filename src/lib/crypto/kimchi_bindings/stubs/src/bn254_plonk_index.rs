use crate::arkworks::CamlBN254Fp;
use crate::{gate_vector::bn254::CamlBN254PlonkGateVectorPtr, srs::bn254::CamlBnFpSrs};
use kimchi::circuits::lookup::runtime_tables::caml::CamlRuntimeTableCfg;
use kimchi::circuits::lookup::runtime_tables::RuntimeTableCfg;
use kimchi::circuits::lookup::tables::caml::CamlLookupTable;
use kimchi::circuits::lookup::tables::LookupTable;
use kimchi::circuits::{constraints::ConstraintSystem, gate::CircuitGate};
use kimchi::prover_index::ProverIndex;
use mina_curves::bn254::{BN254Parameters, Fp, Pair, BN254};
use mina_poseidon::{constants::PlonkSpongeConstantsKimchi, sponge::DefaultFqSponge};
use poly_commitment::pairing_proof::PairingProof;

/// Boxed so that we don't store large proving indexes in the OCaml heap.
#[derive(ocaml_gen::CustomType)]
pub struct CamlBN254PlonkIndex(pub Box<KZGProverIndex>);
pub type CamlBN254PlonkIndexPtr<'a> = ocaml::Pointer<'a, CamlBN254PlonkIndex>;

pub type KZGProverIndex = ProverIndex<BN254, PairingProof<Pair>>;

extern "C" fn caml_bn254_plonk_index_finalize(v: ocaml::Raw) {
    unsafe {
        let mut v: CamlBN254PlonkIndexPtr = v.as_pointer();
        v.as_mut_ptr().drop_in_place();
    }
}

impl ocaml::custom::Custom for CamlBN254PlonkIndex {
    const NAME: &'static str = "CamlBN254PlonkIndex\0";
    const USED: usize = 1;
    /// Encourage the GC to free when there are > 12 in memory
    const MAX: usize = 12;
    const OPS: ocaml::custom::CustomOps = ocaml::custom::CustomOps {
        identifier: Self::NAME.as_ptr() as *const ocaml::sys::Char,
        finalize: Some(caml_bn254_plonk_index_finalize),
        ..ocaml::custom::DEFAULT_CUSTOM_OPS
    };
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_bn254_plonk_index_create(
    gates: CamlBN254PlonkGateVectorPtr,
    public: ocaml::Int,
    lookup_tables: Vec<CamlLookupTable<CamlBN254Fp>>,
    runtime_tables: Vec<CamlRuntimeTableCfg<CamlBN254Fp>>,
    prev_challenges: ocaml::Int,
    srs: CamlBnFpSrs,
) -> Result<CamlBN254PlonkIndex, ocaml::Error> {
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
    let (_endo_q, endo_r) = poly_commitment::srs::endos::<BN254>();

    // Unsafe if we are in a multi-core ocaml
    {
        let ptr: &mut poly_commitment::srs::SRS<BN254> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
        ptr.add_lagrange_basis(cs.domain.d1);
    }

    // create index
    let mut index = KZGProverIndex::create(cs, endo_r, srs.clone());
    // Compute and cache the verifier index digest
    index.compute_verifier_index_digest::<DefaultFqSponge<BN254Parameters, PlonkSpongeConstantsKimchi>>();

    Ok(CamlBN254PlonkIndex(Box::new(index)))
}
