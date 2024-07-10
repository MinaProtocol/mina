use std::fmt::Debug;
///! Abstraction over types of indices
///!
///! Our sparse matrices can use any integer type for its indices among
///! `u16, u32, u64, usize, i16, i32, i64, isize`.
///!
///! By default, sprs matrices will use `usize`, but it can be useful to switch
///! to another index type to reduce the memory usage of sparse matrices, of for
///! compatibility purposes when calling into an existing library through FFI.
use std::ops::AddAssign;

use num_traits::int::PrimInt;

/// A sparse matrix index
///
/// This is a convenience trait to enable using various integer sizes for sparse
/// matrix indices.
pub trait SpIndex:
    Debug + PrimInt + AddAssign<Self> + Default + Send + Sync
{
    /// Convert to usize.
    ///
    /// # Panics
    ///
    /// If the integer cannot be represented as an `usize`, eg negative numbers.
    fn index(self) -> usize;

    /// Try convert to usize.
    fn try_index(self) -> Option<usize>;

    /// Convert to usize without checking for overflows.
    fn index_unchecked(self) -> usize;

    /// Convert from usize.
    ///
    /// # Panics
    ///
    /// If the input overflows the index type.
    fn from_usize(ind: usize) -> Self;

    /// Try convert from usize.
    fn try_from_usize(ind: usize) -> Option<Self>;

    /// Convert from usize without checking for overflows.
    fn from_usize_unchecked(ind: usize) -> Self;
}

impl SpIndex for usize {
    #[inline(always)]
    fn index(self) -> usize {
        self
    }

    #[inline(always)]
    fn try_index(self) -> Option<usize> {
        Some(self)
    }

    #[inline(always)]
    fn index_unchecked(self) -> usize {
        self
    }

    #[inline(always)]
    #[allow(clippy::wrong_self_convention)]
    fn from_usize(ind: usize) -> Self {
        ind
    }

    #[inline(always)]
    fn try_from_usize(ind: usize) -> Option<Self> {
        Some(ind)
    }

    #[inline(always)]
    #[allow(clippy::wrong_self_convention)]
    fn from_usize_unchecked(ind: usize) -> Self {
        ind
    }
}

macro_rules! sp_index_impl {
    ($int: ident) => {
        impl SpIndex for $int {
            #[inline(always)]
            fn index(self) -> usize {
                self.try_index().unwrap_or_else(|| {
                    panic!("Failed to convert {} to usize", self)
                })
            }

            #[inline(always)]
            fn try_index(self) -> Option<usize> {
                num_traits::cast(self)
            }

            #[inline(always)]
            fn index_unchecked(self) -> usize {
                debug_assert!(self.try_index().is_some());
                self as usize
            }

            #[inline(always)]
            fn from_usize(ind: usize) -> Self {
                Self::try_from_usize(ind).unwrap_or_else(|| {
                    panic!("Failed to convert {} to index type", ind)
                })
            }

            #[inline(always)]
            fn try_from_usize(ind: usize) -> Option<Self> {
                num_traits::cast(ind)
            }

            #[inline(always)]
            fn from_usize_unchecked(ind: usize) -> Self {
                debug_assert!(Self::try_from_usize(ind).is_some());
                ind as Self
            }
        }
    };
}

sp_index_impl!(isize);
sp_index_impl!(i64);
sp_index_impl!(i32);
sp_index_impl!(i16);
sp_index_impl!(u64);
sp_index_impl!(u32);
sp_index_impl!(u16);

#[cfg(test)]
mod test {
    use super::SpIndex;

    #[test]
    #[should_panic]
    fn overflow_u16() {
        let b: u16 = u16::from_usize(131072); // 2^17
        println!("{}", b);
    }

    #[test]
    #[should_panic]
    fn negative_i16() {
        let b: i16 = -1;
        let a = b.index();
        println!("{}", a);
    }
}
