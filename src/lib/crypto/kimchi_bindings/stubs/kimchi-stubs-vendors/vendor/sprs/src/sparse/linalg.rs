use crate::{DenseVector, DenseVectorMut};
///! Sparse linear algebra
///!
///! This module contains solvers for sparse linear systems. Currently
///! there are solver for sparse triangular systems and symmetric systems.
use num_traits::Num;

pub mod etree;
pub mod ordering;
pub mod trisolve;

pub use self::ordering::reverse_cuthill_mckee;

/// Diagonal solve
pub fn diag_solve<'a, N, V1, V2>(diag: V1, mut x: V2)
where
    N: 'a + Clone + Num + std::ops::DivAssign,
    for<'r> N: std::ops::DivAssign<&'r N>,
    V1: DenseVector<Scalar = N>,
    V2: DenseVectorMut + DenseVector<Scalar = N>,
{
    let n = x.dim();
    assert_eq!(diag.dim(), n);
    for i in 0..n {
        *x.index_mut(i) /= diag.index(i);
    }
}
