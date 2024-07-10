//! Multiply-accumulate (MAC) trait and implementations
//! It's useful to define our own MAC trait as it's the main primitive we use
//! in matrix products, and defining it ourselves means we can define an
//! implementation that does not require cloning, which should prove useful
//! when defining sparse matrices per blocks (eg BSR, BSC)

use std::ops::{AddAssign, Mul};

/// Trait for types that have a multiply-accumulate operation, as required
/// in dot products and matrix products.
///
/// This trait is automatically implemented for numeric types that are `Copy`,
/// however the implementation is open for more complex types, to allow them
/// to provide the most performant implementation. For instance, we could have
/// a default implementation for numeric types that are `Clone`, but it would
/// make possibly unnecessary copies.
pub trait MulAcc<A = Self, B = A> {
    /// Multiply and accumulate in this variable, formally `*self += a * b`.
    fn mul_acc(&mut self, a: &A, b: &B);
}

/// Default for types which supports `mul_add`
impl<N, A, B> MulAcc<A, B> for N
where
    for<'x> &'x A: Mul<&'x B, Output = N>,
    N: AddAssign<N>,
{
    fn mul_acc(&mut self, a: &A, b: &B) {
        self.add_assign(a * b);
    }
}

#[cfg(test)]
mod tests {
    use super::MulAcc;

    #[test]
    fn mul_acc_f64() {
        let mut a = 1f64;
        let b = 2.;
        let c = 3.;
        a.mul_acc(&b, &c);
        assert_eq!(a, 7.);
    }

    #[derive(Debug, Copy, Clone, Default)]
    struct Wrapped<T: Default + Copy + std::fmt::Debug>(T);

    impl MulAcc<Wrapped<i8>, Wrapped<i16>> for Wrapped<i32> {
        fn mul_acc(&mut self, a: &Wrapped<i8>, b: &Wrapped<i16>) {
            self.0 = self.0 + a.0 as i32 * b.0 as i32;
        }
    }

    #[test]
    fn mul_acc_mixed_param_sizes() {
        let mut a = Wrapped::<i32>(0x40000007i32);
        let b = Wrapped::<i8>(0x20i8);
        let c = Wrapped::<i16>(0x3000i16);
        a.mul_acc(&b, &c);
        assert_eq!(a.0, 0x40060007i32);
    }
}
