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
use groupmap::GroupMap;
use kimchi::prover_index::ProverIndex;
use kimchi::verifier::verify;
use kimchi::{circuits::polynomial::COLUMNS, verifier::batch_verify};
use kimchi::{
    proof::{
        PointEvaluations, ProofEvaluations, ProverCommitments, ProverProof, RecursionChallenge,
    },
    verifier::Context,
};
use kimchi::{prover::caml::CamlProverProof, verifier_index::VerifierIndex};
use mina_curves::pasta::{Fp, Fq, Pallas, Vesta, VestaParameters};
use mina_poseidon::{
    constants::PlonkSpongeConstantsKimchi,
    sponge::{DefaultFqSponge, DefaultFrSponge},
};
use poly_commitment::commitment::{CommitmentCurve, PolyComm};
use poly_commitment::evaluation_proof::OpeningProof;
use std::array;
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
        let ptr: &mut poly_commitment::srs::SRS<Vesta> =
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

    // public input
    let public_input = witness[0][0..index.cs.public].to_vec();

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
        Ok((proof, public_input).into())
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_create_and_verify(
    index: CamlPastaFpPlonkIndexPtr<'static>,
    witness: Vec<CamlFpVector>,
    prev_challenges: Vec<CamlFp>,
    prev_sgs: Vec<CamlGVesta>,
) -> Result<CamlProverProof<CamlGVesta, CamlFp>, ocaml::Error> {
    {
        let ptr: &mut poly_commitment::srs::SRS<Vesta> =
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

    // public input
    let public_input = witness[0][0..index.cs.public].to_vec();

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

        let verifier_index = index.verifier_index();

        // Verify proof
        verify::<Vesta, EFqSponge, EFrSponge>(&group_map, &verifier_index, &proof, &public_input)?;

        Ok((proof, public_input).into())
    })
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_lookup(
    srs: CamlFpSrs,
) -> (
    CamlPastaFpPlonkIndex,
    CamlFp,
    CamlProverProof<CamlGVesta, CamlFp>,
) {
    use ark_ff::Zero;
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, GateType},
        lookup::runtime_tables::{RuntimeTable, RuntimeTableCfg},
        polynomial::COLUMNS,
        wires::Wire,
    };
    use poly_commitment::srs::{endos, SRS};

    let num_gates = 1000;
    let num_tables = 5;

    let mut runtime_tables_setup = vec![];
    for table_id in 0..num_tables {
        let cfg = RuntimeTableCfg {
            id: table_id,
            first_column: [8u32, 9, 8, 7, 1].into_iter().map(Into::into).collect(),
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
                chunk[0][row] = 9u32.into(); // index
                chunk[1][row] = 2u32.into(); // value
            }
        }
        cols
    };

    let num_public_inputs = 1;

    // not sure if theres a smarter way instead of the double unwrap, but should be fine in the test
    let cs = ConstraintSystem::<Fp>::create(gates)
        .runtime(Some(runtime_tables_setup))
        .public(num_public_inputs)
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

    let caml_prover_proof = (proof, vec![public_input]).into();

    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        public_input.into(),
        caml_prover_proof,
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_foreign_field_mul(
    srs: CamlFpSrs,
) -> (CamlPastaFpPlonkIndex, CamlProverProof<CamlGVesta, CamlFp>) {
    use ark_ff::Zero;
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, Connect},
        polynomials::foreign_field_mul,
        wires::Wire,
    };
    use num_bigint::BigUint;
    use num_bigint::RandBigInt;
    use o1_utils::{foreign_field::BigUintForeignFieldHelpers, FieldHelpers};
    use poly_commitment::srs::{endos, SRS};
    use rand::{rngs::StdRng, SeedableRng};

    let foreign_field_modulus = Fq::modulus_biguint();

    // Layout
    //      0-1  ForeignFieldMul | Zero
    //      2-5  compact-multi-range-check (result range check)
    //        6  "single" Generic (result bound)
    //      7-10 multi-range-check (quotient range check)
    //     11-14 multi-range-check (quotient_bound, product1_lo, product1_hi_0)
    //     later limb-check result bound
    //        15 Generic (left and right bounds)
    //     16-19 multi-range-check (left multiplicand)
    //     20-23 multi-range-check (right multiplicand)
    //     24-27 multi-range-check (result bound, left bound, right bound)
    // TODO: check when kimchi is merged to berkeley

    // Create foreign field multiplication gates
    let (mut next_row, mut gates) =
        CircuitGate::<Fp>::create_foreign_field_mul(0, &foreign_field_modulus);

    let rng = &mut StdRng::from_seed([2u8; 32]);
    let left_input = rng.gen_biguint_range(&BigUint::zero(), &foreign_field_modulus);
    let right_input = rng.gen_biguint_range(&BigUint::zero(), &foreign_field_modulus);

    // Compute multiplication witness
    let (mut witness, mut external_checks) =
        foreign_field_mul::witness::create(&left_input, &right_input, &foreign_field_modulus);

    // Result compact-multi-range-check
    CircuitGate::extend_compact_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((1, 0), (4, 1)); // remainder01
    gates.connect_cell_pair((1, 1), (2, 0)); // remainder2
    external_checks.extend_witness_compact_multi_range_checks(&mut witness);
    // These are the coordinates (row, col) of the remainder limbs in the witness
    // remainder0 -> (3, 0), remainder1 -> (4, 0), remainder2 -> (2,0)

    // Constant single Generic gate for result bound
    CircuitGate::extend_high_bounds(&mut gates, &mut next_row, &foreign_field_modulus);
    gates.connect_cell_pair((6, 0), (1, 1)); // remainder2
    external_checks.extend_witness_high_bounds_computation(&mut witness, &foreign_field_modulus);

    // Quotient multi-range-check
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((1, 2), (7, 0)); // quotient0
    gates.connect_cell_pair((1, 3), (8, 0)); // quotient1
    gates.connect_cell_pair((1, 4), (9, 0)); // quotient2
                                             // Witness updated below

    // Multiplication witness value quotient_bound, product1_lo, product1_hi_0 multi-range-check
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((1, 5), (11, 0)); // quotient_bound
    gates.connect_cell_pair((0, 6), (12, 0)); // product1_lo
    gates.connect_cell_pair((1, 6), (13, 0)); // product1_hi_0
                                              // Witness updated below

    // Add witness for external multi-range checks:
    // [quotient0, quotient1, quotient2]
    // [quotient_bound, product1_lo, product1_hi_0]
    external_checks.extend_witness_multi_range_checks(&mut witness);

    // DESIGNER CHOICE: left and right (and result bound from before)
    let left_limbs = left_input.to_field_limbs();
    let right_limbs = right_input.to_field_limbs();
    // Constant Double Generic gate for result and quotient bounds
    external_checks.add_high_bound_computation(&left_limbs[2]);
    external_checks.add_high_bound_computation(&right_limbs[2]);
    CircuitGate::extend_high_bounds(&mut gates, &mut next_row, &foreign_field_modulus);
    gates.connect_cell_pair((15, 0), (0, 2)); // left2
    gates.connect_cell_pair((15, 3), (0, 5)); // right2
    external_checks.extend_witness_high_bounds_computation(&mut witness, &foreign_field_modulus);

    // Left input multi-range-check
    external_checks.add_multi_range_check(&left_limbs);
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((0, 0), (16, 0)); // left_input0
    gates.connect_cell_pair((0, 1), (17, 0)); // left_input1
    gates.connect_cell_pair((0, 2), (18, 0)); // left_input2
                                              // Witness updated below

    // Right input multi-range-check
    external_checks.add_multi_range_check(&right_limbs);
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((0, 3), (20, 0)); // right_input0
    gates.connect_cell_pair((0, 4), (21, 0)); // right_input1
    gates.connect_cell_pair((0, 5), (22, 0)); // right_input2
                                              // Witness updated below

    // Add witness for external multi-range checks:
    // left and right limbs
    external_checks.extend_witness_multi_range_checks(&mut witness);

    // [result_bound, 0, 0]
    // Bounds for result limb range checks
    CircuitGate::extend_multi_range_check(&mut gates, &mut next_row);
    gates.connect_cell_pair((6, 2), (24, 0)); // result_bound
                                              // Witness updated below

    // Multi-range check bounds for left and right inputs
    let left_hi_bound =
        foreign_field_mul::witness::compute_high_bound(&left_input, &foreign_field_modulus);
    let right_hi_bound =
        foreign_field_mul::witness::compute_high_bound(&right_input, &foreign_field_modulus);
    external_checks.add_limb_check(&left_hi_bound.into());
    external_checks.add_limb_check(&right_hi_bound.into());
    gates.connect_cell_pair((15, 2), (25, 0)); // left_bound
    gates.connect_cell_pair((15, 5), (26, 0)); // right_bound

    external_checks.extend_witness_limb_checks(&mut witness);

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
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();
    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        (proof, vec![]).into(),
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_range_check(
    srs: CamlFpSrs,
) -> (CamlPastaFpPlonkIndex, CamlProverProof<CamlGVesta, CamlFp>) {
    use ark_ff::Zero;
    use kimchi::circuits::{
        constraints::ConstraintSystem, gate::CircuitGate, polynomials::range_check, wires::Wire,
    };
    use num_bigint::BigUint;
    use num_bigint::RandBigInt;
    use o1_utils::{foreign_field::BigUintForeignFieldHelpers, BigUintFieldHelpers};
    use poly_commitment::srs::{endos, SRS};
    use rand::{rngs::StdRng, SeedableRng};

    let rng = &mut StdRng::from_seed([255u8; 32]);

    // Create range-check gadget
    let (mut next_row, mut gates) = CircuitGate::<Fp>::create_multi_range_check(0);

    // Create witness
    let witness = range_check::witness::create_multi::<Fp>(
        rng.gen_biguint_range(&BigUint::zero(), &BigUint::two_to_limb())
            .to_field()
            .expect("failed to convert to field"),
        rng.gen_biguint_range(&BigUint::zero(), &BigUint::two_to_limb())
            .to_field()
            .expect("failed to convert to field"),
        rng.gen_biguint_range(&BigUint::zero(), &BigUint::two_to_limb())
            .to_field()
            .expect("failed to convert to field"),
    );

    // Temporary workaround for lookup-table/domain-size issue
    for _ in 0..(1 << 13) {
        gates.push(CircuitGate::zero(Wire::for_row(next_row)));
        next_row += 1;
    }

    // Create constraint system
    let cs = ConstraintSystem::<Fp>::create(gates)
        .lookup(vec![range_check::gadget::lookup_table()])
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
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();
    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        (proof, vec![]).into(),
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_range_check0(
    srs: CamlFpSrs,
) -> (CamlPastaFpPlonkIndex, CamlProverProof<CamlGVesta, CamlFp>) {
    use ark_ff::Zero;
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, Connect},
        polynomial::COLUMNS,
        polynomials::{generic::GenericGateSpec, range_check},
        wires::Wire,
    };
    use poly_commitment::srs::{endos, SRS};

    let gates = {
        // Public input row with value 0
        let mut gates = vec![CircuitGate::<Fp>::create_generic_gadget(
            Wire::for_row(0),
            GenericGateSpec::Const(Fp::zero()),
            None,
        )];
        let mut row = 1;
        CircuitGate::<Fp>::extend_range_check(&mut gates, &mut row);

        // Temporary workaround for lookup-table/domain-size issue
        for _ in 0..(1 << 13) {
            gates.push(CircuitGate::zero(Wire::for_row(gates.len())));
        }

        // Connect the zero row to the range-check row to check prefix are zeros
        gates.connect_64bit(0, 1);

        gates
    };

    // witness
    let witness = {
        // create row for the zero value
        let mut witness: [_; COLUMNS] = array_init(|_col| vec![Fp::zero(); 1]);
        // create row for the 64-bit value
        range_check::witness::extend_single(&mut witness, Fp::from(2u128.pow(64) - 1));
        witness
    };

    // not sure if theres a smarter way instead of the double unwrap, but should be fine in the test
    let cs = ConstraintSystem::<Fp>::create(gates)
        .lookup(vec![range_check::gadget::lookup_table()])
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
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();
    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        (proof, vec![]).into(),
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_ffadd(
    srs: CamlFpSrs,
) -> (
    CamlPastaFpPlonkIndex,
    CamlFp,
    CamlProverProof<CamlGVesta, CamlFp>,
) {
    use ark_ff::Zero;
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, Connect},
        polynomial::COLUMNS,
        polynomials::{
            foreign_field_add::witness::{create_chain, FFOps},
            generic::GenericGateSpec,
            range_check,
        },
        wires::Wire,
    };
    use num_bigint::BigUint;
    use poly_commitment::srs::{endos, SRS};

    // Includes a row to store value 1
    let num_public_inputs = 1;
    let operation = &[FFOps::Add];
    let modulus = BigUint::from_bytes_be(&[
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFF,
        0xFC, 0x2F,
    ]);

    // circuit
    // [0]       -> Public input row to store the value 1
    // [1]       -> 1 ForeignFieldAdd row
    // [2]       -> 1 ForeignFieldAdd row for final bound
    // [3]       -> 1 Zero row for bound result
    // [4..=7]   -> 1 Multi RangeCheck for left input
    // [8..=11]  -> 1 Multi RangeCheck for right input
    // [12..=15] -> 1 Multi RangeCheck for result
    // [16..=19] -> 1 Multi RangeCheck for bound check
    let gates = {
        // Public input row
        let mut gates = vec![CircuitGate::<Fp>::create_generic_gadget(
            Wire::for_row(0),
            GenericGateSpec::Pub,
            None,
        )];

        let mut curr_row = num_public_inputs;
        // Foreign field addition and bound check
        CircuitGate::<Fp>::extend_chain_ffadd(&mut gates, 0, &mut curr_row, operation, &modulus);

        // Extend rangechecks of left input, right input, result, and bound
        for _ in 0..4 {
            CircuitGate::extend_multi_range_check(&mut gates, &mut curr_row);
        }
        // Connect the witnesses of the addition to the corresponding range checks
        gates.connect_ffadd_range_checks(1, Some(4), Some(8), 12);
        // Connect the bound check range checks
        gates.connect_ffadd_range_checks(2, None, None, 16);

        // Temporary workaround for lookup-table/domain-size issue
        for _ in 0..(1 << 13) {
            gates.push(CircuitGate::zero(Wire::for_row(curr_row)));
            curr_row += 1;
        }

        gates
    };

    // witness
    let witness = {
        // create row for the public value 1
        let mut witness: [_; COLUMNS] = array_init(|_col| vec![Fp::zero(); 1]);
        witness[0][0] = Fp::one();
        // create inputs to the addition
        let left = modulus.clone() - BigUint::from_bytes_be(&[1]);
        let right = modulus.clone() - BigUint::from_bytes_be(&[1]);
        // create a chain of 1 addition
        let add_witness = create_chain::<Fp>(&vec![left, right], operation, modulus);
        for col in 0..COLUMNS {
            witness[col].extend(add_witness[col].iter());
        }
        // extend range checks for all of left, right, output, and bound
        let left = (witness[0][1], witness[1][1], witness[2][1]);
        range_check::witness::extend_multi(&mut witness, left.0, left.1, left.2);
        let right = (witness[3][1], witness[4][1], witness[5][1]);
        range_check::witness::extend_multi(&mut witness, right.0, right.1, right.2);
        let output = (witness[0][2], witness[1][2], witness[2][2]);
        range_check::witness::extend_multi(&mut witness, output.0, output.1, output.2);
        let bound = (witness[0][3], witness[1][3], witness[2][3]);
        range_check::witness::extend_multi(&mut witness, bound.0, bound.1, bound.2);
        witness
    };

    // not sure if theres a smarter way instead of the double unwrap, but should be fine in the test
    let cs = ConstraintSystem::<Fp>::create(gates)
        .public(num_public_inputs)
        .lookup(vec![range_check::gadget::lookup_table()])
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
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();
    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        public_input.into(),
        (proof, vec![public_input]).into(),
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_xor(
    srs: CamlFpSrs,
) -> (
    CamlPastaFpPlonkIndex,
    (CamlFp, CamlFp),
    CamlProverProof<CamlGVesta, CamlFp>,
) {
    use ark_ff::Zero;
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, Connect},
        polynomial::COLUMNS,
        polynomials::{generic::GenericGateSpec, xor},
        wires::Wire,
    };
    use poly_commitment::srs::{endos, SRS};

    let num_public_inputs = 2;

    // circuit
    let gates = {
        // public inputs
        let mut gates = vec![];
        for row in 0..num_public_inputs {
            gates.push(CircuitGate::<Fp>::create_generic_gadget(
                Wire::for_row(row),
                GenericGateSpec::Pub,
                None,
            ));
        }
        // 1 XOR of 128 bits. This will create 8 Xor16 gates and a Generic final gate with all zeros.
        CircuitGate::<Fp>::extend_xor_gadget(&mut gates, 128);
        // connect public inputs to the inputs of the XOR
        gates.connect_cell_pair((0, 0), (2, 0));
        gates.connect_cell_pair((1, 0), (2, 1));

        // Temporary workaround for lookup-table/domain-size issue
        for _ in 0..(1 << 13) {
            gates.push(CircuitGate::zero(Wire::for_row(gates.len())));
        }
        gates
    };

    // witness
    let witness = {
        let mut cols: [_; COLUMNS] = array_init(|_col| vec![Fp::zero(); num_public_inputs]);

        // initialize the 2 inputs
        let input1 = 0xDC811727DAF22EC15927D6AA275F406Bu128;
        let input2 = 0xA4F4417AF072DF9016A1EAB458DA80D1u128;
        cols[0][0] = input1.into();
        cols[0][1] = input2.into();

        xor::extend_xor_witness::<Fp>(&mut cols, input1.into(), input2.into(), 128);
        cols
    };

    // not sure if theres a smarter way instead of the double unwrap, but should be fine in the test
    let cs = ConstraintSystem::<Fp>::create(gates)
        .public(num_public_inputs)
        .lookup(vec![xor::lookup_table()])
        .build()
        .unwrap();

    let ptr: &mut SRS<Vesta> = unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
    ptr.add_lagrange_basis(cs.domain.d1);

    let (endo_q, _endo_r) = endos::<Pallas>();
    let index = ProverIndex::<Vesta>::create(cs, endo_q, srs.0);
    let group_map = <Vesta as CommitmentCurve>::Map::setup();
    let public_input = (witness[0][0], witness[0][1]);
    let proof = ProverProof::create_recursive::<EFqSponge, EFrSponge>(
        &group_map,
        witness,
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();
    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        (public_input.0.into(), public_input.1.into()),
        (proof, vec![public_input.0, public_input.1]).into(),
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_example_with_rot(
    srs: CamlFpSrs,
) -> (
    CamlPastaFpPlonkIndex,
    (CamlFp, CamlFp),
    CamlProverProof<CamlGVesta, CamlFp>,
) {
    use ark_ff::Zero;
    use kimchi::circuits::{
        constraints::ConstraintSystem,
        gate::{CircuitGate, Connect},
        polynomial::COLUMNS,
        polynomials::{
            generic::GenericGateSpec,
            rot::{self, RotMode},
        },
        wires::Wire,
    };
    use poly_commitment::srs::{endos, SRS};

    // Includes the actual input of the rotation and a row with the zero value
    let num_public_inputs = 2;
    // 1 ROT of 32 to the left
    let rot = 32;
    let mode = RotMode::Left;

    // circuit
    let gates = {
        let mut gates = vec![];
        // public inputs
        for row in 0..num_public_inputs {
            gates.push(CircuitGate::<Fp>::create_generic_gadget(
                Wire::for_row(row),
                GenericGateSpec::Pub,
                None,
            ));
        }
        CircuitGate::<Fp>::extend_rot(&mut gates, rot, mode, 1);
        // connect first public input to the word of the ROT
        gates.connect_cell_pair((0, 0), (2, 0));

        // Temporary workaround for lookup-table/domain-size issue
        for _ in 0..(1 << 13) {
            gates.push(CircuitGate::zero(Wire::for_row(gates.len())));
        }

        gates
    };

    // witness
    let witness = {
        // create one row for the public word
        let mut cols: [_; COLUMNS] = array_init(|_col| vec![Fp::zero(); 2]);

        // initialize the public input containing the word to be rotated
        let input = 0xDC811727DAF22EC1u64;
        cols[0][0] = input.into();
        rot::extend_rot::<Fp>(&mut cols, input, rot, mode);

        cols
    };

    // not sure if theres a smarter way instead of the double unwrap, but should be fine in the test
    let cs = ConstraintSystem::<Fp>::create(gates)
        .public(num_public_inputs)
        .lookup(vec![rot::lookup_table()])
        .build()
        .unwrap();

    let ptr: &mut SRS<Vesta> = unsafe { &mut *(std::sync::Arc::as_ptr(&srs.0) as *mut _) };
    ptr.add_lagrange_basis(cs.domain.d1);

    let (endo_q, _endo_r) = endos::<Pallas>();
    let index = ProverIndex::<Vesta>::create(cs, endo_q, srs.0);
    let group_map = <Vesta as CommitmentCurve>::Map::setup();
    let public_input = (witness[0][0], witness[0][1]);
    let proof = ProverProof::create_recursive::<EFqSponge, EFrSponge>(
        &group_map,
        witness,
        &[],
        &index,
        vec![],
        None,
    )
    .unwrap();
    (
        CamlPastaFpPlonkIndex(Box::new(index)),
        (public_input.0.into(), public_input.1.into()),
        (proof, vec![public_input.0, public_input.1]).into(),
    )
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_verify(
    index: CamlPastaFpPlonkVerifierIndex,
    proof: CamlProverProof<CamlGVesta, CamlFp>,
) -> bool {
    let group_map = <Vesta as CommitmentCurve>::Map::setup();

    let (proof, public_input) = proof.into();
    let verifier_index = index.into();
    let context = Context {
        verifier_index: &verifier_index,
        proof: &proof,
        public_input: &public_input,
    };

    batch_verify::<
        Vesta,
        DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>,
    >(&group_map, &[context])
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
        .map(|(caml_index, caml_proof)| {
            let verifier_index: VerifierIndex<Vesta> = caml_index.into();
            let (proof, public_input): (ProverProof<_>, Vec<_>) = caml_proof.into();
            (verifier_index, proof, public_input)
        })
        .collect();
    let ts_ref: Vec<_> = ts
        .iter()
        .map(|(verifier_index, proof, public_input)| Context {
            verifier_index,
            proof,
            public_input,
        })
        .collect();
    let group_map = GroupMap::<Fq>::setup();

    batch_verify::<
        Vesta,
        DefaultFqSponge<VestaParameters, PlonkSpongeConstantsKimchi>,
        DefaultFrSponge<Fp, PlonkSpongeConstantsKimchi>,
    >(&group_map, &ts_ref)
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
    let prev_challenges = vec![prev.clone(), prev.clone(), prev];

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
        generic_selector: eval(),
        poseidon_selector: eval(),
        complete_add_selector: eval(),
        mul_selector: eval(),
        emul_selector: eval(),
        endomul_scalar_selector: eval(),
        range_check0_selector: None,
        range_check1_selector: None,
        foreign_field_add_selector: None,
        foreign_field_mul_selector: None,
        xor_selector: None,
        rot_selector: None,
    lookup_aggregation: None,
    lookup_table: None,
    lookup_sorted: array::from_fn(|_| None),
    runtime_lookup_table: None,
    };

    let public = vec![Fp::one(), Fp::one()];
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
        prev_challenges,
    };

    (dlogproof, public).into()
}

#[ocaml_gen::func]
#[ocaml::func]
pub fn caml_pasta_fp_plonk_proof_deep_copy(
    x: CamlProverProof<CamlGVesta, CamlFp>,
) -> CamlProverProof<CamlGVesta, CamlFp> {
    x
}
