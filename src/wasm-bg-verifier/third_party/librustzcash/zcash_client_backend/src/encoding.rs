//! Encoding and decoding functions for Zcash key and address structs.
//!
//! Human-Readable Prefixes (HRPs) for Bech32 encodings are located in the [`constants`]
//! module.

use bech32::{self, Error, FromBase32, ToBase32};
use pairing::bls12_381::Bls12;
use std::io::{self, Write};
use zcash_primitives::{
    primitives::PaymentAddress,
    zip32::{ExtendedFullViewingKey, ExtendedSpendingKey},
    JUBJUB,
};

fn bech32_encode<F>(hrp: &str, write: F) -> String
where
    F: Fn(&mut dyn Write) -> io::Result<()>,
{
    let mut data: Vec<u8> = vec![];
    write(&mut data).expect("Should be able to write to a Vec");
    bech32::encode(hrp, data.to_base32()).expect("hrp is invalid")
}

fn bech32_decode<T, F>(hrp: &str, s: &str, read: F) -> Result<Option<T>, Error>
where
    F: Fn(Vec<u8>) -> Option<T>,
{
    let (decoded_hrp, data) = bech32::decode(s)?;
    if decoded_hrp == hrp {
        Vec::<u8>::from_base32(&data).map(|data| read(data))
    } else {
        Ok(None)
    }
}

/// Writes an [`ExtendedSpendingKey`] as a Bech32-encoded string.
///
/// # Examples
///
/// ```
/// use zcash_client_backend::{
///     constants::testnet::{COIN_TYPE, HRP_SAPLING_EXTENDED_SPENDING_KEY},
///     encoding::encode_extended_spending_key,
///     keys::spending_key,
/// };
///
/// let extsk = spending_key(&[0; 32][..], COIN_TYPE, 0);
/// let encoded = encode_extended_spending_key(HRP_SAPLING_EXTENDED_SPENDING_KEY, &extsk);
/// ```
pub fn encode_extended_spending_key(hrp: &str, extsk: &ExtendedSpendingKey) -> String {
    bech32_encode(hrp, |w| extsk.write(w))
}

/// Decodes an [`ExtendedSpendingKey`] from a Bech32-encoded string.
pub fn decode_extended_spending_key(
    hrp: &str,
    s: &str,
) -> Result<Option<ExtendedSpendingKey>, Error> {
    bech32_decode(hrp, s, |data| ExtendedSpendingKey::read(&data[..]).ok())
}

/// Writes an [`ExtendedFullViewingKey`] as a Bech32-encoded string.
///
/// # Examples
///
/// ```
/// use zcash_client_backend::{
///     constants::testnet::{COIN_TYPE, HRP_SAPLING_EXTENDED_FULL_VIEWING_KEY},
///     encoding::encode_extended_full_viewing_key,
///     keys::spending_key,
/// };
/// use zcash_primitives::zip32::ExtendedFullViewingKey;
///
/// let extsk = spending_key(&[0; 32][..], COIN_TYPE, 0);
/// let extfvk = ExtendedFullViewingKey::from(&extsk);
/// let encoded = encode_extended_full_viewing_key(HRP_SAPLING_EXTENDED_FULL_VIEWING_KEY, &extfvk);
/// ```
pub fn encode_extended_full_viewing_key(hrp: &str, extfvk: &ExtendedFullViewingKey) -> String {
    bech32_encode(hrp, |w| extfvk.write(w))
}

/// Decodes an [`ExtendedFullViewingKey`] from a Bech32-encoded string.
pub fn decode_extended_full_viewing_key(
    hrp: &str,
    s: &str,
) -> Result<Option<ExtendedFullViewingKey>, Error> {
    bech32_decode(hrp, s, |data| ExtendedFullViewingKey::read(&data[..]).ok())
}

/// Writes a [`PaymentAddress`] as a Bech32-encoded string.
///
/// # Examples
///
/// ```
/// use pairing::bls12_381::Bls12;
/// use rand_core::SeedableRng;
/// use rand_xorshift::XorShiftRng;
/// use zcash_client_backend::{
///     constants::testnet::HRP_SAPLING_PAYMENT_ADDRESS,
///     encoding::encode_payment_address,
/// };
/// use zcash_primitives::{
///     jubjub::edwards,
///     primitives::{Diversifier, PaymentAddress},
///     JUBJUB,
/// };
///
/// let rng = &mut XorShiftRng::from_seed([
///     0x59, 0x62, 0xbe, 0x3d, 0x76, 0x3d, 0x31, 0x8d, 0x17, 0xdb, 0x37, 0x32, 0x54, 0x06,
///     0xbc, 0xe5,
/// ]);
///
/// let pa = PaymentAddress::from_parts(
///     Diversifier([0u8; 11]),
///     edwards::Point::<Bls12, _>::rand(rng, &JUBJUB).mul_by_cofactor(&JUBJUB),
/// )
/// .unwrap();
///
/// assert_eq!(
///     encode_payment_address(HRP_SAPLING_PAYMENT_ADDRESS, &pa),
///     "ztestsapling1qqqqqqqqqqqqqqqqqrjq05nyfku05msvu49mawhg6kr0wwljahypwyk2h88z6975u563j0ym7pe",
/// );
/// ```
pub fn encode_payment_address(hrp: &str, addr: &PaymentAddress<Bls12>) -> String {
    bech32_encode(hrp, |w| w.write_all(&addr.to_bytes()))
}

/// Decodes a [`PaymentAddress`] from a Bech32-encoded string.
///
/// # Examples
///
/// ```
/// use pairing::bls12_381::Bls12;
/// use rand_core::SeedableRng;
/// use rand_xorshift::XorShiftRng;
/// use zcash_client_backend::{
///     constants::testnet::HRP_SAPLING_PAYMENT_ADDRESS,
///     encoding::decode_payment_address,
/// };
/// use zcash_primitives::{
///     jubjub::edwards,
///     primitives::{Diversifier, PaymentAddress},
///     JUBJUB,
/// };
///
/// let rng = &mut XorShiftRng::from_seed([
///     0x59, 0x62, 0xbe, 0x3d, 0x76, 0x3d, 0x31, 0x8d, 0x17, 0xdb, 0x37, 0x32, 0x54, 0x06,
///     0xbc, 0xe5,
/// ]);
///
/// let pa = PaymentAddress::from_parts(
///     Diversifier([0u8; 11]),
///     edwards::Point::<Bls12, _>::rand(rng, &JUBJUB).mul_by_cofactor(&JUBJUB),
/// )
/// .unwrap();
///
/// assert_eq!(
///     decode_payment_address(
///         HRP_SAPLING_PAYMENT_ADDRESS,
///         "ztestsapling1qqqqqqqqqqqqqqqqqrjq05nyfku05msvu49mawhg6kr0wwljahypwyk2h88z6975u563j0ym7pe",
///     ),
///     Ok(Some(pa)),
/// );
/// ```
pub fn decode_payment_address(hrp: &str, s: &str) -> Result<Option<PaymentAddress<Bls12>>, Error> {
    bech32_decode(hrp, s, |data| {
        if data.len() != 43 {
            return None;
        }

        let mut bytes = [0; 43];
        bytes.copy_from_slice(&data);
        PaymentAddress::<Bls12>::from_bytes(&bytes, &JUBJUB)
    })
}

#[cfg(test)]
mod tests {
    use pairing::bls12_381::Bls12;
    use rand_core::SeedableRng;
    use rand_xorshift::XorShiftRng;
    use zcash_primitives::JUBJUB;
    use zcash_primitives::{
        jubjub::edwards,
        primitives::{Diversifier, PaymentAddress},
    };

    use super::{decode_payment_address, encode_payment_address};
    use crate::constants;

    #[test]
    fn payment_address() {
        let rng = &mut XorShiftRng::from_seed([
            0x59, 0x62, 0xbe, 0x3d, 0x76, 0x3d, 0x31, 0x8d, 0x17, 0xdb, 0x37, 0x32, 0x54, 0x06,
            0xbc, 0xe5,
        ]);

        let addr = PaymentAddress::from_parts(
            Diversifier([0u8; 11]),
            edwards::Point::<Bls12, _>::rand(rng, &JUBJUB).mul_by_cofactor(&JUBJUB),
        )
        .unwrap();

        let encoded_main =
            "zs1qqqqqqqqqqqqqqqqqrjq05nyfku05msvu49mawhg6kr0wwljahypwyk2h88z6975u563j8nfaxd";
        let encoded_test =
            "ztestsapling1qqqqqqqqqqqqqqqqqrjq05nyfku05msvu49mawhg6kr0wwljahypwyk2h88z6975u563j0ym7pe";

        assert_eq!(
            encode_payment_address(constants::mainnet::HRP_SAPLING_PAYMENT_ADDRESS, &addr),
            encoded_main
        );
        assert_eq!(
            decode_payment_address(
                constants::mainnet::HRP_SAPLING_PAYMENT_ADDRESS,
                encoded_main
            )
            .unwrap(),
            Some(addr.clone())
        );

        assert_eq!(
            encode_payment_address(constants::testnet::HRP_SAPLING_PAYMENT_ADDRESS, &addr),
            encoded_test
        );
        assert_eq!(
            decode_payment_address(
                constants::testnet::HRP_SAPLING_PAYMENT_ADDRESS,
                encoded_test
            )
            .unwrap(),
            Some(addr)
        );
    }

    #[test]
    fn invalid_diversifier() {
        let rng = &mut XorShiftRng::from_seed([
            0x59, 0x62, 0xbe, 0x3d, 0x76, 0x3d, 0x31, 0x8d, 0x17, 0xdb, 0x37, 0x32, 0x54, 0x06,
            0xbc, 0xe5,
        ]);

        let addr = PaymentAddress::from_parts(
            Diversifier([1u8; 11]),
            edwards::Point::<Bls12, _>::rand(rng, &JUBJUB).mul_by_cofactor(&JUBJUB),
        )
        .unwrap();

        let encoded_main =
            encode_payment_address(constants::mainnet::HRP_SAPLING_PAYMENT_ADDRESS, &addr);

        assert_eq!(
            decode_payment_address(
                constants::mainnet::HRP_SAPLING_PAYMENT_ADDRESS,
                &encoded_main
            )
            .unwrap(),
            None
        );
    }
}
