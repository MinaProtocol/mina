use std::iter::Sum;
use std::ops::{Add, AddAssign, Sub, SubAssign};

const COIN: i64 = 1_0000_0000;
const MAX_MONEY: i64 = 21_000_000 * COIN;

pub const DEFAULT_FEE: Amount = Amount(10000);

/// A type-safe representation of some quantity of Zcash.
///
/// An Amount can only be constructed from an integer that is within the valid monetary
/// range of `{-MAX_MONEY..MAX_MONEY}` (where `MAX_MONEY` = 21,000,000 × 10⁸ zatoshis).
/// However, this range is not preserved as an invariant internally; it is possible to
/// add two valid Amounts together to obtain an invalid Amount. It is the user's
/// responsibility to handle the result of serializing potentially-invalid Amounts. In
/// particular, a [`Transaction`] containing serialized invalid Amounts will be rejected
/// by the network consensus rules.
///
/// [`Transaction`]: crate::transaction::Transaction
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Amount(i64);

impl Amount {
    /// Returns a zero-valued Amount.
    pub const fn zero() -> Self {
        Amount(0)
    }

    /// Creates an Amount from an i64.
    ///
    /// Returns an error if the amount is outside the range `{-MAX_MONEY..MAX_MONEY}`.
    pub fn from_i64(amount: i64) -> Result<Self, ()> {
        if -MAX_MONEY <= amount && amount <= MAX_MONEY {
            Ok(Amount(amount))
        } else {
            Err(())
        }
    }

    /// Creates a non-negative Amount from an i64.
    ///
    /// Returns an error if the amount is outside the range `{0..MAX_MONEY}`.
    pub fn from_nonnegative_i64(amount: i64) -> Result<Self, ()> {
        if 0 <= amount && amount <= MAX_MONEY {
            Ok(Amount(amount))
        } else {
            Err(())
        }
    }

    /// Creates an Amount from a u64.
    ///
    /// Returns an error if the amount is outside the range `{0..MAX_MONEY}`.
    pub fn from_u64(amount: u64) -> Result<Self, ()> {
        if amount <= MAX_MONEY as u64 {
            Ok(Amount(amount as i64))
        } else {
            Err(())
        }
    }

    /// Reads an Amount from a signed 64-bit little-endian integer.
    ///
    /// Returns an error if the amount is outside the range `{-MAX_MONEY..MAX_MONEY}`.
    pub fn from_i64_le_bytes(bytes: [u8; 8]) -> Result<Self, ()> {
        let amount = i64::from_le_bytes(bytes);
        Amount::from_i64(amount)
    }

    /// Reads a non-negative Amount from a signed 64-bit little-endian integer.
    ///
    /// Returns an error if the amount is outside the range `{0..MAX_MONEY}`.
    pub fn from_nonnegative_i64_le_bytes(bytes: [u8; 8]) -> Result<Self, ()> {
        let amount = i64::from_le_bytes(bytes);
        Amount::from_nonnegative_i64(amount)
    }

    /// Reads an Amount from an unsigned 64-bit little-endian integer.
    ///
    /// Returns an error if the amount is outside the range `{0..MAX_MONEY}`.
    pub fn from_u64_le_bytes(bytes: [u8; 8]) -> Result<Self, ()> {
        let amount = u64::from_le_bytes(bytes);
        Amount::from_u64(amount)
    }

    /// Returns the Amount encoded as a signed 64-bit little-endian integer.
    pub fn to_i64_le_bytes(self) -> [u8; 8] {
        self.0.to_le_bytes()
    }

    /// Returns `true` if `self` is positive and `false` if the Amount is zero or
    /// negative.
    pub const fn is_positive(self) -> bool {
        self.0.is_positive()
    }

    /// Returns `true` if `self` is negative and `false` if the Amount is zero or
    /// positive.
    pub const fn is_negative(self) -> bool {
        self.0.is_negative()
    }
}

impl From<Amount> for i64 {
    fn from(amount: Amount) -> i64 {
        amount.0
    }
}

impl From<Amount> for u64 {
    fn from(amount: Amount) -> u64 {
        amount.0 as u64
    }
}

impl Add<Amount> for Amount {
    type Output = Amount;

    fn add(self, rhs: Amount) -> Amount {
        Amount::from_i64(self.0 + rhs.0).expect("addition should remain in range")
    }
}

impl AddAssign<Amount> for Amount {
    fn add_assign(&mut self, rhs: Amount) {
        *self = *self + rhs
    }
}

impl Sub<Amount> for Amount {
    type Output = Amount;

    fn sub(self, rhs: Amount) -> Amount {
        Amount::from_i64(self.0 - rhs.0).expect("subtraction should remain in range")
    }
}

impl SubAssign<Amount> for Amount {
    fn sub_assign(&mut self, rhs: Amount) {
        *self = *self - rhs
    }
}

impl Sum for Amount {
    fn sum<I: Iterator<Item = Amount>>(iter: I) -> Amount {
        iter.fold(Amount::zero(), Add::add)
    }
}

#[cfg(test)]
mod tests {
    use super::{Amount, MAX_MONEY};

    #[test]
    fn amount_in_range() {
        let zero = b"\x00\x00\x00\x00\x00\x00\x00\x00";
        assert_eq!(Amount::from_u64_le_bytes(zero.clone()).unwrap(), Amount(0));
        assert_eq!(
            Amount::from_nonnegative_i64_le_bytes(zero.clone()).unwrap(),
            Amount(0)
        );
        assert_eq!(Amount::from_i64_le_bytes(zero.clone()).unwrap(), Amount(0));

        let neg_one = b"\xff\xff\xff\xff\xff\xff\xff\xff";
        assert!(Amount::from_u64_le_bytes(neg_one.clone()).is_err());
        assert!(Amount::from_nonnegative_i64_le_bytes(neg_one.clone()).is_err());
        assert_eq!(
            Amount::from_i64_le_bytes(neg_one.clone()).unwrap(),
            Amount(-1)
        );

        let max_money = b"\x00\x40\x07\x5a\xf0\x75\x07\x00";
        assert_eq!(
            Amount::from_u64_le_bytes(max_money.clone()).unwrap(),
            Amount(MAX_MONEY)
        );
        assert_eq!(
            Amount::from_nonnegative_i64_le_bytes(max_money.clone()).unwrap(),
            Amount(MAX_MONEY)
        );
        assert_eq!(
            Amount::from_i64_le_bytes(max_money.clone()).unwrap(),
            Amount(MAX_MONEY)
        );

        let max_money_p1 = b"\x01\x40\x07\x5a\xf0\x75\x07\x00";
        assert!(Amount::from_u64_le_bytes(max_money_p1.clone()).is_err());
        assert!(Amount::from_nonnegative_i64_le_bytes(max_money_p1.clone()).is_err());
        assert!(Amount::from_i64_le_bytes(max_money_p1.clone()).is_err());

        let neg_max_money = b"\x00\xc0\xf8\xa5\x0f\x8a\xf8\xff";
        assert!(Amount::from_u64_le_bytes(neg_max_money.clone()).is_err());
        assert!(Amount::from_nonnegative_i64_le_bytes(neg_max_money.clone()).is_err());
        assert_eq!(
            Amount::from_i64_le_bytes(neg_max_money.clone()).unwrap(),
            Amount(-MAX_MONEY)
        );

        let neg_max_money_m1 = b"\xff\xbf\xf8\xa5\x0f\x8a\xf8\xff";
        assert!(Amount::from_u64_le_bytes(neg_max_money_m1.clone()).is_err());
        assert!(Amount::from_nonnegative_i64_le_bytes(neg_max_money_m1.clone()).is_err());
        assert!(Amount::from_i64_le_bytes(neg_max_money_m1.clone()).is_err());
    }

    #[test]
    #[should_panic]
    fn add_panics_on_overflow() {
        let v = Amount(MAX_MONEY);
        let _sum = v + Amount(1);
    }

    #[test]
    #[should_panic]
    fn add_assign_panics_on_overflow() {
        let mut a = Amount(MAX_MONEY);
        a += Amount(1);
    }

    #[test]
    #[should_panic]
    fn sub_panics_on_underflow() {
        let v = Amount(-MAX_MONEY);
        let _diff = v - Amount(1);
    }

    #[test]
    #[should_panic]
    fn sub_assign_panics_on_underflow() {
        let mut a = Amount(-MAX_MONEY);
        a -= Amount(1);
    }
}
