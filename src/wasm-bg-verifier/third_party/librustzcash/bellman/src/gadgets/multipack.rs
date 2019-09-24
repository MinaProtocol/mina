use super::boolean::Boolean;
use super::num::Num;
use super::Assignment;
use crate::{ConstraintSystem, SynthesisError};
use ff::{Field, PrimeField, ScalarEngine};

/// Takes a sequence of booleans and exposes them as compact
/// public inputs
pub fn pack_into_inputs<E, CS>(mut cs: CS, bits: &[Boolean]) -> Result<(), SynthesisError>
where
    E: ScalarEngine,
    CS: ConstraintSystem<E>,
{
    for (i, bits) in bits.chunks(E::Fr::CAPACITY as usize).enumerate() {
        let mut num = Num::<E>::zero();
        let mut coeff = E::Fr::one();
        for bit in bits {
            num = num.add_bool_with_coeff(CS::one(), bit, coeff);

            coeff.double();
        }

        let input = cs.alloc_input(|| format!("input {}", i), || Ok(*num.get_value().get()?))?;

        // num * 1 = input
        cs.enforce(
            || format!("packing constraint {}", i),
            |_| num.lc(E::Fr::one()),
            |lc| lc + CS::one(),
            |lc| lc + input,
        );
    }

    Ok(())
}

pub fn bytes_to_bits(bytes: &[u8]) -> Vec<bool> {
    bytes
        .iter()
        .flat_map(|&v| (0..8).rev().map(move |i| (v >> i) & 1 == 1))
        .collect()
}

pub fn bytes_to_bits_le(bytes: &[u8]) -> Vec<bool> {
    bytes
        .iter()
        .flat_map(|&v| (0..8).map(move |i| (v >> i) & 1 == 1))
        .collect()
}

pub fn compute_multipacking<E: ScalarEngine>(bits: &[bool]) -> Vec<E::Fr> {
    let mut result = vec![];

    for bits in bits.chunks(E::Fr::CAPACITY as usize) {
        let mut cur = E::Fr::zero();
        let mut coeff = E::Fr::one();

        for bit in bits {
            if *bit {
                cur.add_assign(&coeff);
            }

            coeff.double();
        }

        result.push(cur);
    }

    result
}

#[test]
fn test_multipacking() {
    use crate::ConstraintSystem;
    use pairing::bls12_381::Bls12;
    use rand_core::{RngCore, SeedableRng};
    use rand_xorshift::XorShiftRng;

    use super::boolean::{AllocatedBit, Boolean};
    use crate::gadgets::test::*;

    let mut rng = XorShiftRng::from_seed([
        0x59, 0x62, 0xbe, 0x3d, 0x76, 0x3d, 0x31, 0x8d, 0x17, 0xdb, 0x37, 0x32, 0x54, 0x06, 0xbc,
        0xe5,
    ]);

    for num_bits in 0..1500 {
        let mut cs = TestConstraintSystem::<Bls12>::new();

        let bits: Vec<bool> = (0..num_bits).map(|_| rng.next_u32() % 2 != 0).collect();

        let circuit_bits = bits
            .iter()
            .enumerate()
            .map(|(i, &b)| {
                Boolean::from(
                    AllocatedBit::alloc(cs.namespace(|| format!("bit {}", i)), Some(b)).unwrap(),
                )
            })
            .collect::<Vec<_>>();

        let expected_inputs = compute_multipacking::<Bls12>(&bits);

        pack_into_inputs(cs.namespace(|| "pack"), &circuit_bits).unwrap();

        assert!(cs.is_satisfied());
        assert!(cs.verify(&expected_inputs));
    }
}
