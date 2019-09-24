use pairing::bls12_381::Bls12;
use zcash_primitives::jubjub::{
    edwards, fs::FsRepr, FixedGenerators, JubjubBls12, JubjubParams, Unknown,
};
use zcash_primitives::transaction::components::Amount;

mod prover;
mod verifier;

pub use self::prover::SaplingProvingContext;
pub use self::verifier::SaplingVerificationContext;

// This function computes `value` in the exponent of the value commitment base
fn compute_value_balance(
    value: Amount,
    params: &JubjubBls12,
) -> Option<edwards::Point<Bls12, Unknown>> {
    // Compute the absolute value (failing if -i64::MAX is
    // the value)
    let abs = match i64::from(value).checked_abs() {
        Some(a) => a as u64,
        None => return None,
    };

    // Is it negative? We'll have to negate later if so.
    let is_negative = value.is_negative();

    // Compute it in the exponent
    let mut value_balance = params
        .generator(FixedGenerators::ValueCommitmentValue)
        .mul(FsRepr::from(abs), params);

    // Negate if necessary
    if is_negative {
        value_balance = value_balance.negate();
    }

    // Convert to unknown order point
    Some(value_balance.into())
}
