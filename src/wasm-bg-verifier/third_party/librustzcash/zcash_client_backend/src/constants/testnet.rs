/// The testnet coin type for ZEC, as defined by [SLIP 44].
///
/// [SLIP 44]: https://github.com/satoshilabs/slips/blob/master/slip-0044.md
pub const COIN_TYPE: u32 = 1;

/// The HRP for a Bech32-encoded testnet [`ExtendedSpendingKey`].
///
/// Defined in [ZIP 32].
///
/// [`ExtendedSpendingKey`]: zcash_primitives::zip32::ExtendedSpendingKey
/// [ZIP 32]: https://github.com/zcash/zips/blob/master/zip-0032.rst
pub const HRP_SAPLING_EXTENDED_SPENDING_KEY: &str = "secret-extended-key-test";

/// The HRP for a Bech32-encoded testnet [`ExtendedFullViewingKey`].
///
/// Defined in [ZIP 32].
///
/// [`ExtendedFullViewingKey`]: zcash_primitives::zip32::ExtendedFullViewingKey
/// [ZIP 32]: https://github.com/zcash/zips/blob/master/zip-0032.rst
pub const HRP_SAPLING_EXTENDED_FULL_VIEWING_KEY: &str = "zxviewtestsapling";

/// The HRP for a Bech32-encoded testnet [`PaymentAddress`].
///
/// Defined in section 5.6.4 of the [Zcash Protocol Specification].
///
/// [`PaymentAddress`]: sapling_crypto::primitives::PaymentAddress
/// [Zcash Protocol Specification]: https://github.com/zcash/zips/blob/master/protocol/protocol.pdf
pub const HRP_SAPLING_PAYMENT_ADDRESS: &str = "ztestsapling";
