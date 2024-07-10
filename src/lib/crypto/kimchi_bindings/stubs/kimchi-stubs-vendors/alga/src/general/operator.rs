//! Operators traits and structures.
#[cfg(feature = "decimal")]
use decimal::d128;
pub use std::ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Neg, Rem, Sub, SubAssign};

use num::Num;
use num_complex::Complex;

/// Trait implemented by types representing abstract operators.
pub trait Operator: Copy {
    /// Returns the structure that identifies the operator.
    fn operator_token() -> Self;
}

/// Trait used to define the two_sided_inverse element relative to the given operator.
///
/// The operator, e.g., `Additive` or `Multiplicative`, is identified by the type parameter `O`.
pub trait TwoSidedInverse<O: Operator>: Sized {
    /// Returns the two_sided_inverse of `self`, relative to the operator `O`.
    ///
    /// The parameter `O` is generally either `Additive` or `Multiplicative`.
    fn two_sided_inverse(&self) -> Self;

    /// In-place inversion of `self`, relative to the operator `O`.
    ///
    /// The parameter `O` is generally either `Additive` or `Multiplicative`.
    #[inline]
    fn two_sided_inverse_mut(&mut self) {
        *self = self.two_sided_inverse()
    }
}

/*
 *
 * Implementations.
 *
 */

#[derive(Clone, Copy)]
/// The addition operator, commonly symbolized by `+`.
pub struct Additive;

#[derive(Clone, Copy)]
/// The multiplication operator, commonly symbolized by `×`.
pub struct Multiplicative;

#[derive(Clone, Copy)]
/// The default abstract operator.
pub struct AbstractOperator;

impl Operator for Additive {
    #[inline]
    fn operator_token() -> Self {
        Additive
    }
}

impl Operator for Multiplicative {
    #[inline]
    fn operator_token() -> Self {
        Multiplicative
    }
}

impl Operator for AbstractOperator {
    #[inline]
    fn operator_token() -> Self {
        AbstractOperator
    }
}

macro_rules! impl_additive_inverse(
    ($($T:ty),* $(,)*) => {$(
        impl TwoSidedInverse<Additive> for $T {
            fn two_sided_inverse(&self) -> Self {
                -*self
            }
        }
    )*}
);

impl_additive_inverse!(i8, i16, i32, i64, i128, isize, f32, f64);
#[cfg(feature = "decimal")]
impl_additive_inverse!(d128);

impl<N: TwoSidedInverse<Additive>> TwoSidedInverse<Additive> for Complex<N> {
    #[inline]
    fn two_sided_inverse(&self) -> Complex<N> {
        Complex {
            re: self.re.two_sided_inverse(),
            im: self.im.two_sided_inverse(),
        }
    }
}

impl TwoSidedInverse<Multiplicative> for f32 {
    #[inline]
    fn two_sided_inverse(&self) -> f32 {
        1.0 / self
    }
}

impl TwoSidedInverse<Multiplicative> for f64 {
    #[inline]
    fn two_sided_inverse(&self) -> f64 {
        1.0 / self
    }
}

#[cfg(feature = "decimal")]
impl TwoSidedInverse<Multiplicative> for d128 {
    #[inline]
    fn two_sided_inverse(&self) -> d128 {
        d128!(1.0) / self
    }
}

impl<N: Num + Clone + ClosedNeg> TwoSidedInverse<Multiplicative> for Complex<N> {
    #[inline]
    fn two_sided_inverse(&self) -> Self {
        self.inv()
    }
}

/// [Alias] Trait alias for `Add` and `AddAssign` with result of type `Self`.
pub trait ClosedAdd<Right = Self>: Sized + Add<Right, Output = Self> + AddAssign<Right> {}

/// [Alias] Trait alias for `Sub` and `SubAssign` with result of type `Self`.
pub trait ClosedSub<Right = Self>: Sized + Sub<Right, Output = Self> + SubAssign<Right> {}

/// [Alias] Trait alias for `Mul` and `MulAssign` with result of type `Self`.
pub trait ClosedMul<Right = Self>: Sized + Mul<Right, Output = Self> + MulAssign<Right> {}

/// [Alias] Trait alias for `Div` and `DivAssign` with result of type `Self`.
pub trait ClosedDiv<Right = Self>: Sized + Div<Right, Output = Self> + DivAssign<Right> {}

/// [Alias] Trait alias for `Neg` with result of type `Self`.
pub trait ClosedNeg: Sized + Neg<Output = Self> {}

impl<T, Right> ClosedAdd<Right> for T where T: Add<Right, Output = T> + AddAssign<Right> {}
impl<T, Right> ClosedSub<Right> for T where T: Sub<Right, Output = T> + SubAssign<Right> {}
impl<T, Right> ClosedMul<Right> for T where T: Mul<Right, Output = T> + MulAssign<Right> {}
impl<T, Right> ClosedDiv<Right> for T where T: Div<Right, Output = T> + DivAssign<Right> {}
impl<T> ClosedNeg for T where T: Neg<Output = T> {}
