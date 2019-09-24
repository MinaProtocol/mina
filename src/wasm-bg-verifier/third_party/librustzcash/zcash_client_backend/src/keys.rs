//! Helper functions for managing light client key material.

use zcash_primitives::zip32::{ChildIndex, ExtendedSpendingKey};

/// Derives the ZIP 32 [`ExtendedSpendingKey`] for a given coin type and account from the
/// given seed.
///
/// # Panics
///
/// Panics if `seed` is shorter than 32 bytes.
///
/// # Examples
///
/// ```
/// use zcash_client_backend::{constants::testnet::COIN_TYPE, keys::spending_key};
///
/// let extsk = spending_key(&[0; 32][..], COIN_TYPE, 0);
/// ```
pub fn spending_key(seed: &[u8], coin_type: u32, account: u32) -> ExtendedSpendingKey {
    if seed.len() < 32 {
        panic!("ZIP 32 seeds MUST be at least 32 bytes");
    }

    ExtendedSpendingKey::from_path(
        &ExtendedSpendingKey::master(&seed),
        &[
            ChildIndex::Hardened(32),
            ChildIndex::Hardened(coin_type),
            ChildIndex::Hardened(account),
        ],
    )
}

#[cfg(test)]
mod tests {
    use super::spending_key;

    #[test]
    #[should_panic]
    fn spending_key_panics_on_short_seed() {
        let _ = spending_key(&[0; 31][..], 0, 0);
    }
}
