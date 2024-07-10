#[cfg(feature = "decimal")]
use decimal::d128;
use std::cmp::{Ordering, PartialOrd};

/// A set where every two elements have an infimum (i.e. greatest lower bound).
pub trait MeetSemilattice: Sized {
    /// Returns the meet (aka. infimum) of two values.
    fn meet(&self, other: &Self) -> Self;
}

/// A set where every two elements have a supremum (i.e. smallest upper bound).
pub trait JoinSemilattice: Sized {
    /// Returns the join (aka. supremum) of two values.
    fn join(&self, other: &Self) -> Self;
}

/// Partially orderable sets where every two elements have a supremum and infimum.
pub trait Lattice: MeetSemilattice + JoinSemilattice + PartialOrd {
    /// Returns the infimum and the supremum simultaneously.
    #[inline]
    fn meet_join(&self, other: &Self) -> (Self, Self) {
        (self.meet(other), self.join(other))
    }

    /// Return the minimum of `self` and `other` if they are comparable.
    #[inline]
    fn partial_min<'a>(&'a self, other: &'a Self) -> Option<&'a Self> {
        if let Some(ord) = self.partial_cmp(other) {
            match ord {
                Ordering::Greater => Some(other),
                _ => Some(self),
            }
        } else {
            None
        }
    }

    /// Return the maximum of `self` and `other` if they are comparable.
    #[inline]
    fn partial_max<'a>(&'a self, other: &'a Self) -> Option<&'a Self> {
        if let Some(ord) = self.partial_cmp(other) {
            match ord {
                Ordering::Less => Some(other),
                _ => Some(self),
            }
        } else {
            None
        }
    }

    /// Sorts two values in increasing order using a partial ordering.
    #[inline]
    fn partial_sort2<'a>(&'a self, other: &'a Self) -> Option<(&'a Self, &'a Self)> {
        if let Some(ord) = self.partial_cmp(other) {
            match ord {
                Ordering::Less => Some((self, other)),
                _ => Some((other, self)),
            }
        } else {
            None
        }
    }

    /// Clamp `value` between `min` and `max`. Returns `None` if `value` is not comparable to
    /// `min` or `max`.
    #[inline]
    fn partial_clamp<'a>(&'a self, min: &'a Self, max: &'a Self) -> Option<&'a Self> {
        if let (Some(cmp_min), Some(cmp_max)) = (self.partial_cmp(min), self.partial_cmp(max)) {
            if cmp_min == Ordering::Less {
                Some(min)
            } else if cmp_max == Ordering::Greater {
                Some(max)
            } else {
                Some(self)
            }
        } else {
            None
        }
    }
}

macro_rules! impl_lattice(
    ($($T:ident),*) => {$(
        impl MeetSemilattice for $T {
            #[inline]
            fn meet(&self, other: &Self) -> Self {
                if *self <= *other {
                    *self
                }
                else {
                    *other
                }
            }
        }

        impl JoinSemilattice for $T {
            #[inline]
            fn join(&self, other: &Self) -> Self {
                if *self >= *other {
                    *self
                }
                else {
                    *other
                }
            }
        }

        impl Lattice for $T {
            #[inline]
            fn meet_join(&self, other: &Self) -> (Self, Self) {
                if *self >= *other {
                    (*other, *self)
                }
                else {
                    (*self, *other)
                }
            }
        }
    )*}
);

impl_lattice!(u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize, f32, f64);
#[cfg(feature = "decimal")]
impl_lattice!(d128);

impl<N: MeetSemilattice> MeetSemilattice for num_complex::Complex<N> {
    #[inline]
    fn meet(&self, other: &Self) -> Self {
        Self {
            re: self.re.meet(&other.re),
            im: self.im.meet(&other.im),
        }
    }
}

impl<N: JoinSemilattice> JoinSemilattice for num_complex::Complex<N> {
    #[inline]
    fn join(&self, other: &Self) -> Self {
        Self {
            re: self.re.join(&other.re),
            im: self.im.join(&other.im),
        }
    }
}
