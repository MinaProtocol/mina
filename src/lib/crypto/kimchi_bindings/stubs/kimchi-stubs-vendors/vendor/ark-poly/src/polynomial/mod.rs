//! Modules for working with univariate or multivariate polynomials.
use ark_ff::{Field, Zero};
use ark_serialize::*;
use ark_std::rand::Rng;
use ark_std::{
    fmt::Debug,
    hash::Hash,
    ops::{Add, AddAssign, Neg, SubAssign},
    vec::Vec,
};

pub mod multivariate;
pub mod univariate;

/// Describes the common interface for univariate and multivariate polynomials
pub trait Polynomial<F: Field>:
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
{
    /// The type of evaluation points for this polynomial.
    type Point: Sized + Clone + Ord + Debug + Sync + Hash;

    /// Returns the total degree of the polynomial
    fn degree(&self) -> usize;

    /// Evaluates `self` at the given `point` in `Self::Point`.
    fn evaluate(&self, point: &Self::Point) -> F;
}

/// Describes the interface for univariate polynomials
pub trait UVPolynomial<F: Field>: Polynomial<F, Point = F> {
    /// Constructs a new polynomial from a list of coefficients.
    fn from_coefficients_slice(coeffs: &[F]) -> Self;

    /// Constructs a new polynomial from a list of coefficients.
    fn from_coefficients_vec(coeffs: Vec<F>) -> Self;

    /// Returns the coefficients of `self`
    fn coeffs(&self) -> &[F];

    /// Returns a univariate polynomial of degree `d` where each
    /// coefficient is sampled uniformly at random.
    fn rand<R: Rng>(d: usize, rng: &mut R) -> Self;
}

/// Describes the interface for multivariate polynomials
pub trait MVPolynomial<F: Field>: Polynomial<F> {
    /// The type of the terms of `self`
    type Term: multivariate::Term;

    /// Constructs a new polynomial from a list of tuples of the form `(Self::Term, coeff)`
    fn from_coefficients_slice(num_vars: usize, terms: &[(F, Self::Term)]) -> Self {
        Self::from_coefficients_vec(num_vars, terms.to_vec())
    }

    /// Constructs a new polynomial from a list of tuples of the form `(Self::Term, coeff)`
    fn from_coefficients_vec(num_vars: usize, terms: Vec<(F, Self::Term)>) -> Self;

    /// Returns the terms of a `self` as a list of tuples of the form `(Self::Term, coeff)`
    fn terms(&self) -> &[(F, Self::Term)];

    /// Returns the number of variables in `self`
    fn num_vars(&self) -> usize;

    /// Outputs an `l`-variate polynomial which is the sum of `l` `d`-degree univariate
    /// polynomials where each coefficient is sampled uniformly at random.
    fn rand<R: Rng>(d: usize, num_vars: usize, rng: &mut R) -> Self;
}
