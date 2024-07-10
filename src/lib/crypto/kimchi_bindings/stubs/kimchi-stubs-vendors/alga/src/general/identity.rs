#[cfg(feature = "decimal")]
use decimal::d128;
use std::cmp::{Ordering, PartialOrd};
use std::fmt;
use std::marker::PhantomData;
use std::ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign};

use num::{Num, One, Zero};

use num_complex::Complex;

use approx::{AbsDiffEq, RelativeEq, UlpsEq};

use crate::general::{
    AbstractGroup, AbstractGroupAbelian, AbstractLoop, AbstractMagma, AbstractMonoid,
    AbstractQuasigroup, AbstractSemigroup, Additive, JoinSemilattice, Lattice, MeetSemilattice,
    Multiplicative, Operator, SubsetOf, TwoSidedInverse,
};

/// A type that is equipped with identity.
pub trait Identity<O: Operator> {
    /// The identity element.
    fn identity() -> Self;

    /// Specific identity.
    #[inline]
    fn id(_: O) -> Self
    where
        Self: Sized,
    {
        Self::identity()
    }
}

impl_ident!(Additive; 0; u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize);
impl_ident!(Additive; 0.; f32, f64);
#[cfg(feature = "decimal")]
impl_ident!(Additive; d128!(0.); d128);
impl_ident!(Multiplicative; 1; u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize);
impl_ident!(Multiplicative; 1.; f32, f64);
#[cfg(feature = "decimal")]
impl_ident!(Multiplicative; d128!(1.); d128);

impl<N: Identity<Additive>> Identity<Additive> for Complex<N> {
    #[inline]
    fn identity() -> Self {
        Complex {
            re: N::identity(),
            im: N::identity(),
        }
    }
}

impl<N: Num + Clone> Identity<Multiplicative> for Complex<N> {
    #[inline]
    fn identity() -> Self {
        Complex::new(N::one(), N::zero())
    }
}

/// The universal identity element wrt. a given operator, usually noted `Id` with a
/// context-dependent subscript.
///
/// By default, it is the multiplicative identity element. It represents the degenerate set
/// containing only the identity element of any group-like structure.  It has no dimension known at
/// compile-time. All its operations are no-ops.
#[repr(C)]
#[derive(Debug)]
pub struct Id<O: Operator = Multiplicative> {
    _op: PhantomData<O>,
}

impl<O: Operator> Id<O> {
    /// Creates a new identity element.
    #[inline]
    pub fn new() -> Id<O> {
        Id { _op: PhantomData }
    }
}

impl<O: Operator> Copy for Id<O> {}

impl<O: Operator> Clone for Id<O> {
    #[inline]
    fn clone(&self) -> Id<O> {
        Id::new()
    }
}

impl<O: Operator> fmt::Display for Id<O> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Identity element")
    }
}

impl<O: Operator> PartialEq for Id<O> {
    #[inline]
    fn eq(&self, _: &Id<O>) -> bool {
        true
    }
}

impl<O: Operator> Eq for Id<O> {}

impl<O: Operator> PartialOrd for Id<O> {
    #[inline]
    fn partial_cmp(&self, _: &Id<O>) -> Option<Ordering> {
        Some(Ordering::Equal)
    }
}

impl<O: Operator> Identity<O> for Id<O> {
    #[inline]
    fn identity() -> Id<O> {
        Id::new()
    }
}

impl<O: Operator> AbsDiffEq for Id<O> {
    type Epsilon = Id<O>;

    #[inline]
    fn default_epsilon() -> Self::Epsilon {
        Id::new()
    }

    #[inline]
    fn abs_diff_eq(&self, _: &Self, _: Self::Epsilon) -> bool {
        true
    }
}

impl<O: Operator> RelativeEq for Id<O> {
    #[inline]
    fn default_max_relative() -> Self::Epsilon {
        Id::new()
    }

    #[inline]
    fn relative_eq(&self, _: &Self, _: Self::Epsilon, _: Self::Epsilon) -> bool {
        true
    }
}

impl<O: Operator> UlpsEq for Id<O> {
    #[inline]
    fn default_max_ulps() -> u32 {
        0
    }

    #[inline]
    fn ulps_eq(&self, _: &Self, _: Self::Epsilon, _: u32) -> bool {
        true
    }
}

/*
 *
 * Algebraic structures.
 *
 */
impl Mul<Id> for Id {
    type Output = Id;

    fn mul(self, _: Id) -> Id {
        self
    }
}

impl MulAssign<Id> for Id {
    fn mul_assign(&mut self, _: Id) {
        // no-op
    }
}

impl Div<Id> for Id {
    type Output = Id;

    fn div(self, _: Id) -> Id {
        self
    }
}

impl DivAssign<Id> for Id {
    fn div_assign(&mut self, _: Id) {
        // no-op
    }
}

impl Add<Id<Additive>> for Id<Additive> {
    type Output = Id<Additive>;

    fn add(self, _: Id<Additive>) -> Id<Additive> {
        self
    }
}

impl AddAssign<Id<Additive>> for Id<Additive> {
    fn add_assign(&mut self, _: Id<Additive>) {
        // no-op
    }
}

impl<O: Operator> AbstractMagma<O> for Id<O> {
    #[inline]
    fn operate(&self, _: &Self) -> Id<O> {
        Id::new()
    }
}

impl<O: Operator> TwoSidedInverse<O> for Id<O> {
    #[inline]
    fn two_sided_inverse(&self) -> Self {
        Id::new()
    }

    #[inline]
    fn two_sided_inverse_mut(&mut self) {
        // no-op
    }
}

impl<O: Operator> AbstractSemigroup<O> for Id<O> {}
impl<O: Operator> AbstractQuasigroup<O> for Id<O> {}
impl<O: Operator> AbstractMonoid<O> for Id<O> {}
impl<O: Operator> AbstractLoop<O> for Id<O> {}
impl<O: Operator> AbstractGroup<O> for Id<O> {}
impl<O: Operator> AbstractGroupAbelian<O> for Id<O> {}

impl One for Id {
    #[inline]
    fn one() -> Id {
        Id::new()
    }
}

impl Zero for Id<Additive> {
    #[inline]
    fn zero() -> Id<Additive> {
        Id::new()
    }

    #[inline]
    fn is_zero(&self) -> bool {
        true
    }
}

/*
 *
 * Conversions.
 *
 */
impl<O: Operator, T: PartialEq + Identity<O>> SubsetOf<T> for Id<O> {
    #[inline]
    fn to_superset(&self) -> T {
        T::identity()
    }

    #[inline]
    fn is_in_subset(t: &T) -> bool {
        *t == T::identity()
    }

    #[inline]
    unsafe fn from_superset_unchecked(_: &T) -> Self {
        Id::new()
    }
}

impl<O: Operator> MeetSemilattice for Id<O> {
    #[inline]
    fn meet(&self, _: &Self) -> Self {
        Id::new()
    }
}

impl<O: Operator> JoinSemilattice for Id<O> {
    #[inline]
    fn join(&self, _: &Self) -> Self {
        Id::new()
    }
}

impl<O: Operator> Lattice for Id<O> {}
