mod dense;
mod sparse;

pub use dense::DenseMultilinearExtension;
pub use sparse::SparseMultilinearExtension;

use ark_std::fmt::Debug;
use ark_std::hash::Hash;
use ark_std::ops::{Add, AddAssign, Index, Neg, SubAssign};
use ark_std::vec::Vec;

use ark_ff::{Field, Zero};

use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use ark_std::rand::Rng;

/// This trait describes an interface for the multilinear extension
/// of an array.
/// The latter is a multilinear polynomial represented in terms of its evaluations over
/// the domain {0,1}^`num_vars` (i.e. the Boolean hypercube).
///
/// Index represents a point, which is a vector in {0,1}^`num_vars` in little endian form. For example, `0b1011` represents `P(1,1,0,1)`
pub trait MultilinearExtension<F: Field>:
    Sized
    + Clone
    + Debug
    + Hash
    + PartialEq
    + Eq
    + Add
    + Neg
    + Zero
    + CanonicalSerialize
    + CanonicalDeserialize
    + for<'a> AddAssign<&'a Self>
    + for<'a> AddAssign<(F, &'a Self)>
    + for<'a> SubAssign<&'a Self>
    + Index<usize>
{
    /// Returns the number of variables in `self`
    fn num_vars(&self) -> usize;

    /// Evaluates `self` at the given the vector `point` in slice.
    /// If the number of variables does not match, return `None`.
    fn evaluate(&self, point: &[F]) -> Option<F>;

    /// Outputs an `l`-variate multilinear extension where value of evaluations are sampled uniformly at random.
    fn rand<R: Rng>(num_vars: usize, rng: &mut R) -> Self;

    /// Relabel the point by swapping `k` scalars from positions `a..a+k` to positions `b..b+k`,
    /// and from position `b..b+k` to position `a..a+k` in vector.
    ///
    /// This function turns `P(x_1,...,x_a,...,x_{a+k - 1},...,x_b,...,x_{b+k - 1},...,x_n)`
    /// to `P(x_1,...,x_b,...,x_{b+k - 1},...,x_a,...,x_{a+k - 1},...,x_n)`
    fn relabel(&self, a: usize, b: usize, k: usize) -> Self;

    /// Reduce the number of variables of `self` by fixing the `partial_point.len()` variables at `partial_point`.
    fn fix_variables(&self, partial_point: &[F]) -> Self;

    /// Returns a list of evaluations over the domain, which is the boolean hypercube.
    fn to_evaluations(&self) -> Vec<F>;
}

/// swap the bits of `x` from position `a..a+n` to `b..b+n` and from `b..b+n` to `a..a+n` in little endian order
pub(crate) fn swap_bits(x: usize, a: usize, b: usize, n: usize) -> usize {
    let a_bits = (x >> a) & ((1usize << n) - 1);
    let b_bits = (x >> b) & ((1usize << n) - 1);
    let local_xor_mask = a_bits ^ b_bits;
    let global_xor_mask = (local_xor_mask << a) | (local_xor_mask << b);
    x ^ global_xor_mask
}
