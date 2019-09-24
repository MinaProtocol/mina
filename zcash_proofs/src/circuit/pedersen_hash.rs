use super::ecc::{EdwardsPoint, MontgomeryPoint};
use bellman::gadgets::boolean::Boolean;
use bellman::gadgets::lookup::*;
use bellman::{ConstraintSystem, SynthesisError};
use zcash_primitives::jubjub::*;
pub use zcash_primitives::pedersen_hash::Personalization;

fn get_constant_bools(person: &Personalization) -> Vec<Boolean> {
    person
        .get_bits()
        .into_iter()
        .map(Boolean::constant)
        .collect()
}

pub fn pedersen_hash<E: JubjubEngine, CS>(
    mut cs: CS,
    personalization: Personalization,
    bits: &[Boolean],
    params: &E::Params,
) -> Result<EdwardsPoint<E>, SynthesisError>
where
    CS: ConstraintSystem<E>,
{
    let personalization = get_constant_bools(&personalization);
    assert_eq!(personalization.len(), 6);

    let mut edwards_result = None;
    let mut bits = personalization.iter().chain(bits.iter()).peekable();
    let mut segment_generators = params.pedersen_circuit_generators().iter();
    let boolean_false = Boolean::constant(false);

    let mut segment_i = 0;
    while bits.peek().is_some() {
        let mut segment_result = None;
        let mut segment_windows = &segment_generators.next().expect("enough segments")[..];

        let mut window_i = 0;
        while let Some(a) = bits.next() {
            let b = bits.next().unwrap_or(&boolean_false);
            let c = bits.next().unwrap_or(&boolean_false);

            let tmp = lookup3_xy_with_conditional_negation(
                cs.namespace(|| format!("segment {}, window {}", segment_i, window_i)),
                &[a.clone(), b.clone(), c.clone()],
                &segment_windows[0],
            )?;

            let tmp = MontgomeryPoint::interpret_unchecked(tmp.0, tmp.1);

            match segment_result {
                None => {
                    segment_result = Some(tmp);
                }
                Some(ref mut segment_result) => {
                    *segment_result = tmp.add(
                        cs.namespace(|| {
                            format!("addition of segment {}, window {}", segment_i, window_i)
                        }),
                        segment_result,
                        params,
                    )?;
                }
            }

            segment_windows = &segment_windows[1..];

            if segment_windows.is_empty() {
                break;
            }

            window_i += 1;
        }

        let segment_result = segment_result.expect(
            "bits is not exhausted due to while condition;
                    thus there must be a segment window;
                    thus there must be a segment result",
        );

        // Convert this segment into twisted Edwards form.
        let segment_result = segment_result.into_edwards(
            cs.namespace(|| format!("conversion of segment {} into edwards", segment_i)),
            params,
        )?;

        match edwards_result {
            Some(ref mut edwards_result) => {
                *edwards_result = segment_result.add(
                    cs.namespace(|| format!("addition of segment {} to accumulator", segment_i)),
                    edwards_result,
                    params,
                )?;
            }
            None => {
                edwards_result = Some(segment_result);
            }
        }

        segment_i += 1;
    }

    Ok(edwards_result.unwrap())
}

#[cfg(test)]
mod test {
    use super::*;
    use bellman::gadgets::boolean::{AllocatedBit, Boolean};
    use bellman::gadgets::test::*;
    use ff::PrimeField;
    use pairing::bls12_381::{Bls12, Fr};
    use rand_core::{RngCore, SeedableRng};
    use rand_xorshift::XorShiftRng;
    use zcash_primitives::pedersen_hash;

    #[test]
    fn test_pedersen_hash_constraints() {
        let mut rng = XorShiftRng::from_seed([
            0x59, 0x62, 0xbe, 0x3d, 0x76, 0x3d, 0x31, 0x8d, 0x17, 0xdb, 0x37, 0x32, 0x54, 0x06,
            0xbc, 0xe5,
        ]);
        let params = &JubjubBls12::new();
        let mut cs = TestConstraintSystem::<Bls12>::new();

        let input: Vec<bool> = (0..(Fr::NUM_BITS * 2))
            .map(|_| rng.next_u32() % 2 != 0)
            .collect();

        let input_bools: Vec<Boolean> = input
            .iter()
            .enumerate()
            .map(|(i, b)| {
                Boolean::from(
                    AllocatedBit::alloc(cs.namespace(|| format!("input {}", i)), Some(*b)).unwrap(),
                )
            })
            .collect();

        pedersen_hash(
            cs.namespace(|| "pedersen hash"),
            Personalization::NoteCommitment,
            &input_bools,
            params,
        )
        .unwrap();

        assert!(cs.is_satisfied());
        assert_eq!(cs.num_constraints(), 1377);
    }

    #[test]
    fn test_pedersen_hash() {
        let mut rng = XorShiftRng::from_seed([
            0x59, 0x62, 0xbe, 0x3d, 0x76, 0x3d, 0x31, 0x8d, 0x17, 0xdb, 0x37, 0x32, 0x54, 0x06,
            0xbc, 0xe5,
        ]);
        let params = &JubjubBls12::new();

        for length in 0..751 {
            for _ in 0..5 {
                let input: Vec<bool> = (0..length).map(|_| rng.next_u32() % 2 != 0).collect();

                let mut cs = TestConstraintSystem::<Bls12>::new();

                let input_bools: Vec<Boolean> = input
                    .iter()
                    .enumerate()
                    .map(|(i, b)| {
                        Boolean::from(
                            AllocatedBit::alloc(cs.namespace(|| format!("input {}", i)), Some(*b))
                                .unwrap(),
                        )
                    })
                    .collect();

                let res = pedersen_hash(
                    cs.namespace(|| "pedersen hash"),
                    Personalization::MerkleTree(1),
                    &input_bools,
                    params,
                )
                .unwrap();

                assert!(cs.is_satisfied());

                let expected = pedersen_hash::pedersen_hash::<Bls12, _>(
                    Personalization::MerkleTree(1),
                    input.clone().into_iter(),
                    params,
                )
                .to_xy();

                assert_eq!(res.get_x().get_value().unwrap(), expected.0);
                assert_eq!(res.get_y().get_value().unwrap(), expected.1);

                // Test against the output of a different personalization
                let unexpected = pedersen_hash::pedersen_hash::<Bls12, _>(
                    Personalization::MerkleTree(0),
                    input.into_iter(),
                    params,
                )
                .to_xy();

                assert!(res.get_x().get_value().unwrap() != unexpected.0);
                assert!(res.get_y().get_value().unwrap() != unexpected.1);
            }
        }
    }
}
