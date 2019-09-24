use crate::jubjub::{edwards, JubjubEngine, PrimeOrder};

use ff::PrimeField;

use crate::constants;
use blake2s_simd::Params;

/// Produces a random point in the Jubjub curve.
/// The point is guaranteed to be prime order
/// and not the identity.
pub fn group_hash<E: JubjubEngine>(
    tag: &[u8],
    personalization: &[u8],
    params: &E::Params,
) -> Option<edwards::Point<E, PrimeOrder>> {
    assert_eq!(personalization.len(), 8);

    // Check to see that scalar field is 255 bits
    assert!(E::Fr::NUM_BITS == 255);

    let h = Params::new()
        .hash_length(32)
        .personal(personalization)
        .to_state()
        .update(constants::GH_FIRST_BLOCK)
        .update(tag)
        .finalize();

    match edwards::Point::<E, _>::read(h.as_ref(), params) {
        Ok(p) => {
            let p = p.mul_by_cofactor(params);

            if p != edwards::Point::zero() {
                Some(p)
            } else {
                None
            }
        }
        Err(_) => None,
    }
}
