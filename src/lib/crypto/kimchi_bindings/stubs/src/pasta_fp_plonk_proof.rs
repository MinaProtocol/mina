use crate::{
    arkworks::{CamlFp, CamlGVesta},
    field_vector::fp::CamlFpVector,
    pasta_fp_plonk_index::{CamlPastaFpPlonkIndex, CamlPastaFpPlonkIndexPtr},
    pasta_fp_plonk_verifier_index::CamlPastaFpPlonkVerifierIndex,
    srs::fp::CamlFpSrs,
};
use ark_ec::AffineCurve;
use ark_ff::One;
use array_init::array_init;
use commitment_dlog::commitment::{CommitmentCurve, PolyComm};
use commitment_dlog::evaluation_proof::OpeningProof;
use groupmap::GroupMap;
use kimchi::proof::{
    PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof, RecursionChallenge,
};
use kimchi::prover::caml::CamlProverProof;
use kimchi::prover_index::ProverIndex;
use kimchi::{circuits::polynomial::COLUMNS, verifier::batch_verify};
use mina_curves::pasta::{Fp, Fq, Pallas, Vesta, VestaParameters};
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use std::convert::TryInto;

type EFqSponge = DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>;
type EFrSponge = DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>;

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_create(
    index: CamlPastaFpPlonkIndexPtr<'static>,
    witness: Vec<CamlFpVector>,
    prev_challenges: Vec<CamlFp>,
    prev_sgs: Vec<CamlGVesta>,
) -> Result<CamlProverProof<CamlGVesta, CamlFp>, ocaml::Error> {
    {
        let ptr: &mut commitment_dlog::srs::SRS<Vesta> =
            unsafe { &mut *(std::sync::Arc::as_ptr(&index.as_ref().0.srs) as *mut _) };
        ptr.add_lagrange_basis(index.as_ref().0.cs.domain.d1);
    }
    let prev = if prev_challenges.is_empty() {
        Vec::new()
    } else {
        let challenges_per_sg = prev_challenges.len() / prev_sgs.len();
        prev_sgs
            .into_iter()
            .map(Into::<Vesta>::into)
            .enumerate()
            .map(|(i, sg)| {
                let chals = prev_challenges[(i * challenges_per_sg)..(i + 1) * challenges_per_sg]
                    .iter()
                    .map(Into::<Fp>::into)
                    .collect();
                let comm = PolyComm::<Vesta> {
                    unshifted: vec![sg],
                    shifted: None,
                };
                RecursionChallenge { chals, comm }
            })
            .collect()
    };

    let witness: Vec<Vec<_>> = witness.iter().map(|x| (*x.0).clone()).collect();
    let witness: [Vec<_>; COLUMNS] = witness
        .try_into()
        .map_err(|_| ocaml::Error::Message("the witness should be a column of 15 vectors"))?;
    let index: &ProverIndex<Vesta> = &index.as_ref().0;

    // NB: This method is designed only to be used by tests. However, since creating a new reference will cause `drop` to be called on it once we are done with it. Since `drop` calls `caml_shutdown` internally, we *really, really* do not want to do this, but we have no other way to get at the active runtime.
    // TODO: There's actually a way to get a handle to the runtime as a function argument. Switch
    // to doing this instead.
    let runtime = unsafe { ocaml::Runtime::recover_handle() };

    // Release the runtime lock so that other threads can run using it while we generate the proof.
    runtime.releasing_runtime(|| {
        let group_map = GroupMap::<Fq>::setup();
        let proof = ProverProof::create_recursive::<EFqSponge, EFrSponge>(
            &group_map,
            witness,
            &[],
            index,
            prev,
            None,
        )
        .map_err(|e| ocaml::Error::Error(e.into()))?;
        Ok(proof.into())
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_lookup(
    srs: CamlFpSrs,
    indexed: bool,
) -> (
    CamlPastaFpPlonkIndex,
    CamlFp,
    CamlProverProof<CamlGVesta, CamlFp>,
) {
    use ark_ff::Zero;
    use commitment_dlog::srs::{endos, SRS};
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, GateType},
        lookup::runtime_tables::{RuntimeTable, RuntimeTableCfg, RuntimeTableSpec},
        polynomial::COLUMNS,
        wires::Wire,
    };

    let num_gates = 1000;
    let num_tables = 5;

    let mut runtime_tables_setup = vec![];
    for table_id in 0..num_tables {
        let cfg = if indexed {
            RuntimeTableCfg::Indexed(RuntimeTableSpec {
                id: table_id as i32,
                len: 5,
            })
        } else {
            RuntimeTableCfg::Custom {
                id: table_id as i32,
                first_column: [8u32, 9, 8, 7, 1].into_iter().map(Into::into).collect(),
            }
        };
        runtime_tables_setup.push(cfg);
    }

    let data: Vec<Fp> = [0u32, 2, 3, 4, 5].into_iter().map(Into::into).collect();
    let runtime_tables: Vec<RuntimeTable<Fp>> = runtime_tables_setup
        .iter()
        .map(|cfg| RuntimeTable {
            id: cfg.id(),
            data: data.clone(),
        })
        .collect();

    // circuit
    let mut gates = vec![];
    for row in 0..num_gates {
        gates.push(CircuitGate {
            typ: GateType::Lookup,
            wires: Wire::for_row(row),
            coeffs: vec![],
        });
    }

    // witness
    let witness = {
        let mut cols: [_; COLUMNS] = array_init(|_col| vec![Fp::zero(); gates.len()]);

        // only the first 7 registers are used in the lookup gate
        let (lookup_cols, _rest) = cols.split_at_mut(7);

        for row in 0..num_gates {
            // the first register is the table id
            lookup_cols[0][row] = 0u32.into();

            // create queries into our runtime lookup table
            let lookup_cols = &mut lookup_cols[1..];
            for chunk in lookup_cols.chunks_mut(2) {
                chunk[0][row] = if indexed { 1u32.into() } else { 9u32.into() }; // index
                chunk[1][row] = 2u32.into(); // value
            }
        }
        cols
    };

    let public_inputs = 1;

    // not sure if theres a smarter way instead of the double unwrap, but should be fine in the test
    let cs = ConstraintSystem::<Fp>::create(gates)
        .runtime(Some(runtime_tables_setup))
        .public(public_inputs)
        .build()
        .unwrap();

    let ptr: &mut SRS<Vesta> = unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
    ptr.add_lagrange_basis(cs.domain.d1);

    let (endo_q, _endo_r) = endos::<Pallas>();
    let index = ProverIndex::<Vesta>::create(cs, endo_q, srs.0);
    let group_map = <Vesta as CommitmentCurve>::Map::setup();
    let public_input = witness[0][0];
    let proof = ProverProof::create_recursive::<EFqSponge, EFrSponge>(
        &group_map,
        witness,
        &runtime_tables,
        &index,
        vec![],
        None,
    )
    .unwrap();
    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        public_input.into(),
        proof.into(),
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_foreign_field_mul(
    srs: CamlFpSrs,
) -> (CamlPastaFpPlonkIndex, CamlProverProof<CamlGVesta, CamlFp>) {
    use ark_ff::Zero;
    use commitment_dlog::srs::{endos, SRS};
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, Connect},
        polynomials::{foreign_field_add::witness::FFOps, foreign_field_mul, range_check},
        wires::Wire,
    };
    use num_bigint::BigUint;
    use num_bigint::RandBigInt;
    use o1_utils::{foreign_field::BigUintForeignFieldHelpers, FieldHelpers};
    use rand::{rngs::StdRng, SeedableRng};

    let foreign_field_modulus = Fq::modulus_biguint();

    // Layout
    //      0    ForeignFieldMul   (foreign field multiplication gadget)
    //      1    Zero              (foreign field multiplication gadget)
    //      4-7  multi-range-check (left multiplicand)
    //      8-11 multi-range-check (right multiplicand)
    //     12-15 multi-range-check (product1_lo, product1_hi_0, carry1_lo)
    //     16-19 multi-range-check (result range check)
    //     20-23 multi-range-check (quotient range check)

    // Create foreign field multiplication gates
    let (mut next_row, mut gates) =
        CircuitGate::<Fp>::create_foreign_field_mul(0, &foreign_field_modulus);

    let rng = &mut StdRng::from_seed([2u8; 32]);
    let left_input = rng.gen_biguint_range(&BigUint::zero(), &foreign_field_modulus);
    let right_input = rng.gen_biguint_range(&BigUint::zero(), &foreign_field_modulus);

    // Compute multiplication witness
    let (mut witness, external_checks) =
        foreign_field_mul::witness::create(&left_input, &right_input, &foreign_field_modulus);

    // Bound addition for multiplication result
    CircuitGate::extend_single_ffadd(
        &mut gates,
        &mut next_row,
        FFOps::Add,
        &foreign_field_modulus,
    );
    gates.connect_cell_pair((1, 0), (2, 0));
    gates.connect_cell_pair((1, 1), (2, 1));
    gates.connect_cell_pair((1, 2), (2, 2));
    external_checks
        .extend_witness_bound_addition(&mut witness, &foreign_field_modulus.to_field_limbs());

    // Left input multi-range-check
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((0, 0), (4, 0));
    gates.connect_cell_pair((0, 1), (5, 0));
    gates.connect_cell_pair((0, 2), (6, 0));
    range_check::witness::extend_multi_limbs(&mut witness, &left_input.to_field_limbs());

    // Right input multi-range-check
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((0, 3), (8, 0));
    gates.connect_cell_pair((0, 4), (9, 0));
    gates.connect_cell_pair((0, 5), (10, 0));
    range_check::witness::extend_multi_limbs(&mut witness, &right_input.to_field_limbs());

    // Multiplication witness value product1_lo, product1_hi_0, carry1_lo multi-range-check
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((0, 6), (12, 0)); // carry1_lo
    gates.connect_cell_pair((1, 5), (13, 0)); // product1_lo
    gates.connect_cell_pair((1, 6), (14, 0)); // product1_hi_0
                                              // Witness updated below

    // Result/remainder bound multi-range-check
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((3, 0), (16, 0));
    gates.connect_cell_pair((3, 1), (17, 0));
    gates.connect_cell_pair((3, 2), (18, 0));
    // Witness updated below

    // Add witness for external multi-range checks (product1_lo, product1_hi_0, carry1_lo and result)
    external_checks.extend_witness_multi_range_checks(&mut witness);

    // Quotient bound multi-range-check
    CircuitGate::extend_compact_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((1, 3), (22, 1));
    gates.connect_cell_pair((1, 4), (20, 0));
    external_checks.extend_witness_compact_multi_range_checks(&mut witness);

    // Temporary workaround for lookup-table/domain-size issue
    for _ in 0..(1 << 13) {
        gates.push(CircuitGate::zero(Wire::for_row(next_row)));
        next_row += 1;
    }

    // Create constraint system
    let cs = ConstraintSystem::<Fp>::create(gates)
        .lookup(vec![foreign_field_mul::gadget::lookup_table()])
        .build()
        .unwrap();

    let ptr: &mut SRS<Vesta> = unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
    ptr.add_lagrange_basis(cs.domain.d1);

    let (endo_q, _endo_r) = endos::<Pallas>();
    let index = ProverIndex::<Vesta>::create(cs, endo_q, srs.0);
    let group_map = <Vesta as CommitmentCurve>::Map::setup();
    let proof = ProverProof::create_recursive::<EFqSponge, EFrSponge>(
        &group_map,
        witness,
        &vec![],
        &index,
        vec![],
        None,
    )
    .unwrap();
    (CamlPastaFpPlonkIndex(Box::new(index)), proof.into())
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_verify(
    index: CamlPastaFpPlonkVerifierIndex,
    proof: CamlProverProof<CamlGVesta, CamlFp>,
) -> bool {
    let group_map = <Vesta as CommitmentCurve>::Map::setup();

    batch_verify::<
        Vesta,
        DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>,
    >(&group_map, &[(&index.into(), &proof.into())].to_vec())
    .is_ok()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_batch_verify(
    indexes: Vec<CamlPastaFpPlonkVerifierIndex>,
    proofs: Vec<CamlProverProof<CamlGVesta, CamlFp>>,
) -> bool {
    let ts: Vec<_> = indexes
        .into_iter()
        .zip(proofs.into_iter())
        .map(|(i, p)| (i.into(), p.into()))
        .collect();
    let ts: Vec<_> = ts.iter().map(|(i, p)| (i, p)).collect();
    let group_map = GroupMap::<Fq>::setup();

    batch_verify::<
        Vesta,
        DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>,
    >(&group_map, &ts)
    .is_ok()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_dummy() -> CamlProverProof<CamlGVesta, CamlFp> {
    fn comm() -> PolyComm<Vesta> {
        let g = Vesta::prime_subgroup_generator();
        PolyComm {
            shifted: Some(g),
            unshifted: vec![g, g, g],
        }
    }

    let prev = RecursionChallenge {
        chals: vec![Fp::one(), Fp::one()],
        comm: comm(),
    };
    let prev_challenges = vec![prev.clone(), prev.clone(), prev.clone()];

    let g = Vesta::prime_subgroup_generator();
    let proof = OpeningProof {
        lr: vec![(g, g), (g, g), (g, g)],
        z1: Fp::one(),
        z2: Fp::one(),
        delta: g,
        sg: g,
    };
    let eval = || PointEvaluations {
        zeta: vec![Fp::one()],
        zeta_omega: vec![Fp::one()],
    };
    let evals = ProofEvaluations {
        w: array_init(|_| eval()),
        coefficients: array_init(|_| eval()),
        z: eval(),
        s: array_init(|_| eval()),
        lookup: None,
        generic_selector: eval(),
        poseidon_selector: eval(),
    };

    let dlogproof = ProverProof {
        commitments: ProverCommitments {
            w_comm: array_init(|_| comm()),
            z_comm: comm(),
            t_comm: comm(),
            lookup: None,
        },
        proof,
        evals,
        ft_eval1: Fp::one(),
        public: vec![Fp::one(), Fp::one()],
        prev_challenges,
    };

    dlogproof.into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_deep_copy(
    x: CamlProverProof<CamlGVesta, CamlFp>,
) -> CamlProverProof<CamlGVesta, CamlFp> {
    x
}
