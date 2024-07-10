use num_complex::Complex;
use num_traits::cast::NumCast;
use std::fmt;
use std::fmt::Display;
use std::str::SplitWhitespace;

use crate::io::IoError::BadMatrixMarketFile;
use crate::num_kinds::Pattern;

pub struct Displayable<T>(T);

impl<'a> Display for Displayable<&'a Pattern> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // write nothing for pattern
        write!(f, "")
    }
}

pub trait MatrixMarketDisplay
where
    Self: Sized,
{
    fn mm_display(&self) -> Displayable<&Self> {
        Displayable(self)
    }
}

impl<T> MatrixMarketDisplay for T
where
    for<'a> Displayable<&'a T>: Display,
{
    fn mm_display(&self) -> Displayable<&Self> {
        Displayable(self)
    }
}

macro_rules! default_matrixmarket_display_impl {
    ($t: ty) => {
        impl Display for Displayable<$t> {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, "{}", self.0)
            }
        }
        impl Display for Displayable<&$t> {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, "{}", self.0)
            }
        }
    };
}

macro_rules! complex_matrixmarket_display_impl {
    ($t: ty) => {
        impl Display for Displayable<Complex<$t>> {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, "{} {}", self.0.re, self.0.im)
            }
        }
        impl Display for Displayable<&Complex<$t>> {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, "{} {}", self.0.re, self.0.im)
            }
        }
    };
}

default_matrixmarket_display_impl!(i8);
default_matrixmarket_display_impl!(u8);
default_matrixmarket_display_impl!(i16);
default_matrixmarket_display_impl!(u16);
default_matrixmarket_display_impl!(i32);
default_matrixmarket_display_impl!(u32);
default_matrixmarket_display_impl!(i64);
default_matrixmarket_display_impl!(u64);
default_matrixmarket_display_impl!(isize);
default_matrixmarket_display_impl!(usize);
default_matrixmarket_display_impl!(f32);
default_matrixmarket_display_impl!(f64);

complex_matrixmarket_display_impl!(f64);
complex_matrixmarket_display_impl!(f32);

pub trait MatrixMarketRead: Sized {
    fn mm_read(r: &mut SplitWhitespace) -> Result<Self, crate::io::IoError>;
}
impl MatrixMarketRead for Pattern {
    fn mm_read(_: &mut SplitWhitespace) -> Result<Self, crate::io::IoError> {
        Ok(Pattern {})
    }
}

macro_rules! matrixmarket_read_impl {
    (Complex<$t:ty>) => {
        impl MatrixMarketRead for Complex<$t> {
            fn mm_read(
                r: &mut SplitWhitespace,
            ) -> Result<Self, crate::io::IoError> {
                let re = r.next().ok_or(BadMatrixMarketFile).and_then(|s| {
                    s.parse::<$t>().or(Err(BadMatrixMarketFile))
                })?;
                let im = r.next().ok_or(BadMatrixMarketFile).and_then(|s| {
                    s.parse::<$t>().or(Err(BadMatrixMarketFile))
                })?;
                Ok(Complex::<$t>::new(re, im))
            }
        }
    };
    ($t: ty) => {
        impl MatrixMarketRead for $t {
            fn mm_read(
                r: &mut SplitWhitespace,
            ) -> Result<Self, crate::io::IoError> {
                let val =
                    r.next().ok_or(BadMatrixMarketFile).and_then(|s| {
                        s.parse::<$t>().or(Err(BadMatrixMarketFile))
                    })?;
                NumCast::from(val).ok_or_else(|| BadMatrixMarketFile)
            }
        }
    };
}

matrixmarket_read_impl!(i8);
matrixmarket_read_impl!(u8);
matrixmarket_read_impl!(i16);
matrixmarket_read_impl!(u16);
matrixmarket_read_impl!(i32);
matrixmarket_read_impl!(u32);
matrixmarket_read_impl!(i64);
matrixmarket_read_impl!(u64);
matrixmarket_read_impl!(isize);
matrixmarket_read_impl!(usize);
matrixmarket_read_impl!(f32);
matrixmarket_read_impl!(f64);
matrixmarket_read_impl!(Complex<f64>);
matrixmarket_read_impl!(Complex<f32>);

pub trait MatrixMarketConjugate
where
    Self: Sized,
{
    fn mm_conj(&self) -> Option<Self>;
}
impl MatrixMarketConjugate for Pattern {
    fn mm_conj(&self) -> Option<Self> {
        None
    }
}

macro_rules! matrixmarket_conjugate_impl {
    (Complex<$t:ty>) => {
        impl MatrixMarketConjugate for Complex<$t> {
            fn mm_conj(&self) -> Option<Self> {
                Some(self.conj())
            }
        }
    };
    ($t: ty) => {
        impl MatrixMarketConjugate for $t {
            fn mm_conj(&self) -> Option<Self> {
                None
            }
        }
    };
}

matrixmarket_conjugate_impl!(i8);
matrixmarket_conjugate_impl!(u8);
matrixmarket_conjugate_impl!(i16);
matrixmarket_conjugate_impl!(u16);
matrixmarket_conjugate_impl!(i32);
matrixmarket_conjugate_impl!(u32);
matrixmarket_conjugate_impl!(i64);
matrixmarket_conjugate_impl!(u64);
matrixmarket_conjugate_impl!(isize);
matrixmarket_conjugate_impl!(usize);
matrixmarket_conjugate_impl!(f32);
matrixmarket_conjugate_impl!(f64);
matrixmarket_conjugate_impl!(Complex<f64>);
matrixmarket_conjugate_impl!(Complex<f32>);
