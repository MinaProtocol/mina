//! Trait to be able to know at runtime if a generic scalar is an integer, a float
//! or a complex.

use num_complex::{Complex32, Complex64};

use std::{
    fmt,
    ops::{Add, Neg},
};
/// the type for Pattern data, it's special which contains no data
#[derive(Debug, Copy, Clone, PartialEq, Eq, Default)]
pub struct Pattern;

impl Add for Pattern {
    type Output = Pattern;
    fn add(self, _other: Pattern) -> Pattern {
        Pattern {}
    }
}
impl Neg for Pattern {
    type Output = Pattern;
    fn neg(self) -> Pattern {
        Pattern {}
    }
}

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum NumKind {
    Integer,
    Float,
    Complex,
    Pattern,
}

impl fmt::Display for NumKind {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::Integer => write!(f, "integer"),
            Self::Float => write!(f, "real"),
            Self::Complex => write!(f, "complex"),
            Self::Pattern => write!(f, "pattern"),
        }
    }
}

pub trait PrimitiveKind {
    /// Informs whether a generic primitive type contains an integer,
    /// a float or a complex
    fn num_kind() -> NumKind;
}
impl PrimitiveKind for Pattern {
    fn num_kind() -> NumKind {
        NumKind::Pattern
    }
}

macro_rules! integer_prim_kind_impl {
    ($prim: ty) => {
        impl PrimitiveKind for $prim {
            fn num_kind() -> NumKind {
                NumKind::Integer
            }
        }
    };
}

integer_prim_kind_impl!(i8);
integer_prim_kind_impl!(u8);
integer_prim_kind_impl!(i16);
integer_prim_kind_impl!(u16);
integer_prim_kind_impl!(i32);
integer_prim_kind_impl!(u32);
integer_prim_kind_impl!(i64);
integer_prim_kind_impl!(u64);
integer_prim_kind_impl!(isize);
integer_prim_kind_impl!(usize);

macro_rules! float_prim_kind_impl {
    ($prim: ty) => {
        impl PrimitiveKind for $prim {
            fn num_kind() -> NumKind {
                NumKind::Float
            }
        }
    };
}

float_prim_kind_impl!(f32);
float_prim_kind_impl!(f64);

macro_rules! complex_prim_kind_impl {
    ($prim: ty) => {
        impl PrimitiveKind for $prim {
            fn num_kind() -> NumKind {
                NumKind::Complex
            }
        }
    };
}

complex_prim_kind_impl!(Complex32);
complex_prim_kind_impl!(Complex64);
