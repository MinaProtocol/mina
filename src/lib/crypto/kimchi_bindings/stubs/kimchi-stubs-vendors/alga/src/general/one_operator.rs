#[cfg(feature = "decimal")]
use decimal::d128;
use num::Num;
use num_complex::Complex;
use std::ops::{Add, Mul};

use approx::RelativeEq;

use crate::general::{Additive, ClosedNeg, Identity, Multiplicative, Operator, TwoSidedInverse};

/// A magma is an algebraic structure which consists of a set equipped with a binary operation, ∘,
/// which must be closed.
///
/// # Closed binary operation
///
/// ~~~notrust
/// a, b ∈ Self ⇒ a ∘ b ∈ Self
/// ~~~
pub trait AbstractMagma<O: Operator>: Sized + Clone {
    /// Performs an operation.
    fn operate(&self, right: &Self) -> Self;

    /// Performs specific operation.
    #[inline]
    fn op(&self, _: O, lhs: &Self) -> Self {
        self.operate(lhs)
    }
}

/// A quasigroup is a magma which that has the **divisibility property** (or Latin square property).
/// *A set with a closed binary operation with the divisibility property.*
///
/// Divisibility is a weak form of right and left invertibility.
///
/// # Divisibility or Latin square property
///
/// ```notrust
/// ∀ a, b ∈ Self, ∃! r, l ∈ Self such that l ∘ a = b and a ∘ r = b
/// ```
///
/// The solution to these equations can be written as
///
/// ```notrust
/// r = a \ b and l = b / a
/// ```
///
/// where "\" and "/" are respectively the **left** and **right** division.
pub trait AbstractQuasigroup<O: Operator>:
    PartialEq + AbstractMagma<O> + TwoSidedInverse<O>
{
    /// Returns `true` if latin squareness holds for the given arguments. Approximate
    /// equality is used for verifications.
    ///
    /// ```notrust
    /// a ~= a / b ∘ b && a ~= a ∘ b / b
    /// ```
    fn prop_inv_is_latin_square_approx(args: (Self, Self)) -> bool
    where
        Self: RelativeEq,
    {
        let (a, b) = args;
        relative_eq!(a, a.operate(&b.two_sided_inverse()).operate(&b))
            && relative_eq!(a, a.operate(&b.operate(&b.two_sided_inverse())))

        // TODO: pseudo inverse?
    }

    /// Returns `true` if latin squareness holds for the given arguments.
    ///
    /// ```notrust
    /// a == a / b * b && a == a * b / b
    /// ```
    fn prop_inv_is_latin_square(args: (Self, Self)) -> bool
    where
        Self: Eq,
    {
        let (a, b) = args;
        a == a.operate(&b.two_sided_inverse()).operate(&b)
            && a == a.operate(&b.operate(&b.two_sided_inverse()))

        // TODO: pseudo inverse?
    }
}

/// Implements the quasigroup trait for types provided.
/// # Examples
///
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # use alga::general::{AbstractMagma, AbstractQuasigroup, Additive, TwoSidedInverse};
/// # fn main() {}
/// #[derive(PartialEq, Clone)]
/// struct Wrapper<T>(T);
///
/// impl<T: AbstractMagma<Additive>> AbstractMagma<Additive> for Wrapper<T> {
///     fn operate(&self, right: &Self) -> Self {
///         Wrapper(self.0.operate(&right.0))
///     }
/// }
///
/// impl<T: TwoSidedInverse<Additive>> TwoSidedInverse<Additive> for Wrapper<T> {
///     fn two_sided_inverse(&self) -> Self {
///         Wrapper(self.0.two_sided_inverse())
///     }
/// }
///
/// impl_quasigroup!(<Additive> for Wrapper<T> where T: AbstractQuasigroup<Additive>);
/// ```
macro_rules! impl_quasigroup(
    (<$M:ty> for $($T:tt)+) => {
        impl_marker!($crate::general::AbstractQuasigroup<$M>; $($T)+);
    }
);

/// A semigroup is a quasigroup that is **associative**.
///
/// *A semigroup is a set equipped with a closed associative binary operation and that has the divisibility property.*
///
/// # Associativity
///
/// ~~~notrust
/// ∀ a, b, c ∈ Self, (a ∘ b) ∘ c = a ∘ (b ∘ c)
/// ~~~
pub trait AbstractSemigroup<O: Operator>: PartialEq + AbstractMagma<O> {
    /// Returns `true` if associativity holds for the given arguments. Approximate equality is used
    /// for verifications.
    fn prop_is_associative_approx(args: (Self, Self, Self)) -> bool
    where
        Self: RelativeEq,
    {
        let (a, b, c) = args;
        relative_eq!(a.operate(&b).operate(&c), a.operate(&b.operate(&c)))
    }

    /// Returns `true` if associativity holds for the given arguments.
    fn prop_is_associative(args: (Self, Self, Self)) -> bool
    where
        Self: Eq,
    {
        let (a, b, c) = args;
        a.operate(&b).operate(&c) == a.operate(&b.operate(&c))
    }
}

/// Implements the semigroup trait for types provided.
/// # Examples
///
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # use alga::general::{AbstractMagma, AbstractSemigroup, Additive};
/// # fn main() {}
/// #[derive(PartialEq, Clone)]
/// struct Wrapper<T>(T);
///
/// impl<T: AbstractMagma<Additive>> AbstractMagma<Additive> for Wrapper<T> {
///     fn operate(&self, right: &Self) -> Self {
///         Wrapper(self.0.operate(&right.0))
///     }
/// }
///
/// impl_semigroup!(<Additive> for Wrapper<T> where T: AbstractSemigroup<Additive>);
/// ```
macro_rules! impl_semigroup(
    (<$M:ty> for $($T:tt)+) => {
        impl_marker!($crate::general::AbstractSemigroup<$M>; $($T)+);
    }
);

/// A loop is a quasigroup with an unique **identity element**, e.
///
/// *A set equipped with a closed binary operation possessing the divisibility property
/// and a unique identity element.*
///
/// # Identity element
///
/// ~~~notrust
/// ∃! e ∈ Self, ∀ a ∈ Self, ∃ r, l ∈ Self such that l ∘ a = a ∘ r = e.
/// ~~~
///
/// The left inverse `r` and right inverse `l` are not required to be equal.
///
/// This property follows from
///
/// ~~~notrust
/// ∀ a ∈ Self, ∃ e ∈ Self, such that e ∘ a = a ∘ e = a.
/// ~~~
pub trait AbstractLoop<O: Operator>: AbstractQuasigroup<O> + Identity<O> {}

/// Implements the loop trait for types provided.
/// # Examples
///
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # use alga::general::{AbstractMagma, AbstractLoop, Additive, TwoSidedInverse, Identity};
/// # fn main() {}
/// #[derive(PartialEq, Clone)]
/// struct Wrapper<T>(T);
///
/// impl<T: AbstractMagma<Additive>> AbstractMagma<Additive> for Wrapper<T> {
///     fn operate(&self, right: &Self) -> Self {
///         Wrapper(self.0.operate(&right.0))
///     }
/// }
///
/// impl<T: TwoSidedInverse<Additive>> TwoSidedInverse<Additive> for Wrapper<T> {
///     fn two_sided_inverse(&self) -> Self {
///         Wrapper(self.0.two_sided_inverse())
///     }
/// }
///
/// impl<T: Identity<Additive>> Identity<Additive> for Wrapper<T> {
///     fn identity() -> Self {
///         Wrapper(T::identity())
///     }
/// }
///
/// impl_loop!(<Additive> for Wrapper<T> where T: AbstractLoop<Additive>);
/// ```
macro_rules! impl_loop(
    (<$M:ty> for $($T:tt)+) => {
        impl_quasigroup!(<$M> for $($T)+);
        impl_marker!($crate::general::AbstractLoop<$M>; $($T)+);
    }
);

/// A monoid is a semigroup equipped with an identity element, e.
///
/// *A set equipped with a closed associative binary operation with the divisibility property and
/// an identity element.*
///
/// # Identity element
///
/// ~~~notrust
/// ∃ e ∈ Self, ∀ a ∈ Self, e ∘ a = a ∘ e = a
/// ~~~
pub trait AbstractMonoid<O: Operator>: AbstractSemigroup<O> + Identity<O> {
    /// Checks whether operating with the identity element is a no-op for the given
    /// argument. Approximate equality is used for verifications.
    fn prop_operating_identity_element_is_noop_approx(args: (Self,)) -> bool
    where
        Self: RelativeEq,
    {
        let (a,) = args;
        relative_eq!(a.operate(&Self::identity()), a)
            && relative_eq!(Self::identity().operate(&a), a)
    }

    /// Checks whether operating with the identity element is a no-op for the given
    /// argument.
    fn prop_operating_identity_element_is_noop(args: (Self,)) -> bool
    where
        Self: Eq,
    {
        let (a,) = args;
        a.operate(&Self::identity()) == a && Self::identity().operate(&a) == a
    }
}

/// Implements the monoid trait for types provided.
/// # Examples
///
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # use alga::general::{AbstractMagma, AbstractMonoid, Additive, Identity};
/// # fn main() {}
/// #[derive(PartialEq, Clone)]
/// struct Wrapper<T>(T);
///
/// impl<T: AbstractMagma<Additive>> AbstractMagma<Additive> for Wrapper<T> {
///     fn operate(&self, right: &Self) -> Self {
///         Wrapper(self.0.operate(&right.0))
///     }
/// }
///
/// impl<T: Identity<Additive>> Identity<Additive> for Wrapper<T> {
///     fn identity() -> Self {
///         Wrapper(T::identity())
///     }
/// }
///
/// impl_monoid!(<Additive> for Wrapper<T> where T: AbstractMonoid<Additive>);
/// ```
macro_rules! impl_monoid(
    (<$M:ty> for $($T:tt)+) => {
        impl_semigroup!(<$M> for $($T)+);
        impl_marker!($crate::general::AbstractMonoid<$M>; $($T)+);
    }
);

/// A group is a loop and a monoid  at the same time.
///
/// *A groups is a set with a closed associative binary operation with the divisibility property and an identity element.*
pub trait AbstractGroup<O: Operator>: AbstractLoop<O> + AbstractMonoid<O> {}

/// Implements the group trait for types provided.
/// # Examples
///
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # use alga::general::{AbstractMagma, AbstractGroup, Additive, TwoSidedInverse, Identity};
/// # fn main() {}
/// #[derive(PartialEq, Clone)]
/// struct Wrapper<T>(T);
///
/// impl<T: AbstractMagma<Additive>> AbstractMagma<Additive> for Wrapper<T> {
///     fn operate(&self, right: &Self) -> Self {
///         Wrapper(self.0.operate(&right.0))
///     }
/// }
///
/// impl<T: TwoSidedInverse<Additive>> TwoSidedInverse<Additive> for Wrapper<T> {
///     fn two_sided_inverse(&self) -> Self {
///         Wrapper(self.0.two_sided_inverse())
///     }
/// }
///
/// impl<T: Identity<Additive>> Identity<Additive> for Wrapper<T> {
///     fn identity() -> Self {
///         Wrapper(T::identity())
///     }
/// }
///
/// impl_group!(<Additive> for Wrapper<T> where T: AbstractGroup<Additive>);
/// ```
macro_rules! impl_group(
    (<$M:ty> for $($T:tt)+) => {
        impl_monoid!(<$M> for $($T)+);
        impl_marker!($crate::general::AbstractQuasigroup<$M>; $($T)+);
        impl_marker!($crate::general::AbstractLoop<$M>; $($T)+);
        impl_marker!($crate::general::AbstractGroup<$M>; $($T)+);
    }
);

/// An Abelian group is a **commutative** group.
///
/// *An commutative group is a set with a closed commutative and associative binary operation with the divisibility property and an identity element.*
///
/// # Commutativity
///
/// ```notrust
/// ∀ a, b ∈ Self, a ∘ b = b ∘ a
/// ```
pub trait AbstractGroupAbelian<O: Operator>: AbstractGroup<O> {
    /// Returns `true` if the operator is commutative for the given argument tuple. Approximate
    /// equality is used for verifications.
    fn prop_is_commutative_approx(args: (Self, Self)) -> bool
    where
        Self: RelativeEq,
    {
        let (a, b) = args;
        relative_eq!(a.operate(&b), b.operate(&a))
    }

    /// Returns `true` if the operator is commutative for the given argument tuple.
    fn prop_is_commutative(args: (Self, Self)) -> bool
    where
        Self: Eq,
    {
        let (a, b) = args;
        a.operate(&b) == b.operate(&a)
    }
}

/// Implements the Abelian group trait for types provided.
/// # Examples
///
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # use alga::general::{AbstractMagma, AbstractGroupAbelian, Additive, TwoSidedInverse, Identity};
/// # fn main() {}
/// #[derive(PartialEq, Clone)]
/// struct Wrapper<T>(T);
///
/// impl<T: AbstractMagma<Additive>> AbstractMagma<Additive> for Wrapper<T> {
///     fn operate(&self, right: &Self) -> Self {
///         Wrapper(self.0.operate(&right.0))
///     }
/// }
///
/// impl<T: TwoSidedInverse<Additive>> TwoSidedInverse<Additive> for Wrapper<T> {
///     fn two_sided_inverse(&self) -> Self {
///         Wrapper(self.0.two_sided_inverse())
///     }
/// }
///
/// impl<T: Identity<Additive>> Identity<Additive> for Wrapper<T> {
///     fn identity() -> Self {
///         Wrapper(T::identity())
///     }
/// }
///
/// impl_abelian!(<Additive> for Wrapper<T> where T: AbstractGroupAbelian<Additive>);
/// ```
macro_rules! impl_abelian(
    (<$M:ty> for $($T:tt)+) => {
        impl_group!(<$M> for $($T)+);
        impl_marker!($crate::general::AbstractGroupAbelian<$M>; $($T)+);
    }
);

/*
 *
 *
 * Implementations.
 *
 *
 *
 */
macro_rules! impl_magma(
    ($M:ty; $op: ident; $($T:ty),* $(,)*) => {
        $(impl AbstractMagma<$M> for $T {
            #[inline]
            fn operate(&self, lhs: &Self) -> Self {
                self.$op(*lhs)
            }
        })*
    }
);

impl_magma!(Additive; add; u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize, f32, f64);
#[cfg(feature = "decimal")]
impl_magma!(Additive; add; d128);
impl_magma!(Multiplicative; mul; u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize, f32, f64);
#[cfg(feature = "decimal")]
impl_magma!(Multiplicative; mul; d128);

impl_monoid!(<Additive> for u8; u16; u32; u64; u128; usize);
impl_monoid!(<Multiplicative> for u8; u16; u32; u64; u128; usize);

impl<N: AbstractMagma<Additive>> AbstractMagma<Additive> for Complex<N> {
    #[inline]
    fn operate(&self, lhs: &Self) -> Self {
        Complex {
            re: self.re.operate(&lhs.re),
            im: self.im.operate(&lhs.im),
        }
    }
}

impl<N: Num + Clone> AbstractMagma<Multiplicative> for Complex<N> {
    #[inline]
    fn operate(&self, lhs: &Self) -> Self {
        self * lhs
    }
}

impl_abelian!(<Multiplicative> for Complex<N> where N: Num + Clone + ClosedNeg);
impl_abelian!(<Additive> for Complex<N> where N: AbstractGroupAbelian<Additive>);
