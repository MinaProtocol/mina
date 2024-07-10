//! A univariate polynomial represented in evaluations form.

use crate::univariate::DensePolynomial;
use crate::{EvaluationDomain, GeneralEvaluationDomain, UVPolynomial};
use ark_ff::{batch_inversion, FftField};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize, SerializationError};
use ark_std::{
    io::{Read, Write},
    ops::{Add, AddAssign, Div, DivAssign, Index, Mul, MulAssign, Sub, SubAssign},
    vec::Vec,
};

#[cfg(feature = "parallel")]
use rayon::prelude::*;

/// Stores a UV polynomial in evaluation form.
#[derive(Clone, PartialEq, Eq, Hash, Debug, CanonicalSerialize, CanonicalDeserialize)]
pub struct Evaluations<F: FftField, D: EvaluationDomain<F> = GeneralEvaluationDomain<F>> {
    /// The evaluations of a polynomial over the domain `D`
    pub evals: Vec<F>,
    #[doc(hidden)]
    domain: D,
}

impl<F: FftField, D: EvaluationDomain<F>> Evaluations<F, D> {
    /// Construct `Self` from evaluations and a domain.
    pub fn from_vec_and_domain(evals: Vec<F>, domain: D) -> Self {
        Self { evals, domain }
    }

    /// Interpolate a polynomial from a list of evaluations
    pub fn interpolate_by_ref(&self) -> DensePolynomial<F> {
        DensePolynomial::from_coefficients_vec(self.domain.ifft(&self.evals))
    }

    /// Interpolate a polynomial from a list of evaluations
    pub fn interpolate(self) -> DensePolynomial<F> {
        let Self { mut evals, domain } = self;
        domain.ifft_in_place(&mut evals);
        DensePolynomial::from_coefficients_vec(evals)
    }

    /// Return the domain `self` is defined over
    pub fn domain(&self) -> D {
        self.domain
    }
}

impl<F: FftField, D: EvaluationDomain<F>> Index<usize> for Evaluations<F, D> {
    type Output = F;

    fn index(&self, index: usize) -> &F {
        &self.evals[index]
    }
}

impl<'a, 'b, F: FftField, D: EvaluationDomain<F>> Mul<&'a Evaluations<F, D>>
    for &'b Evaluations<F, D>
{
    type Output = Evaluations<F, D>;

    #[inline]
    fn mul(self, other: &'a Evaluations<F, D>) -> Evaluations<F, D> {
        let mut result = self.clone();
        result *= other;
        result
    }
}

impl<'a, F: FftField, D: EvaluationDomain<F>> MulAssign<&'a Evaluations<F, D>>
    for Evaluations<F, D>
{
    #[inline]
    fn mul_assign(&mut self, other: &'a Evaluations<F, D>) {
        assert_eq!(self.domain, other.domain, "domains are unequal");
        ark_std::cfg_iter_mut!(self.evals)
            .zip(&other.evals)
            .for_each(|(a, b)| *a *= b);
    }
}

impl<'a, 'b, F: FftField, D: EvaluationDomain<F>> Add<&'a Evaluations<F, D>>
    for &'b Evaluations<F, D>
{
    type Output = Evaluations<F, D>;

    #[inline]
    fn add(self, other: &'a Evaluations<F, D>) -> Evaluations<F, D> {
        let mut result = self.clone();
        result += other;
        result
    }
}

impl<'a, F: FftField, D: EvaluationDomain<F>> AddAssign<&'a Evaluations<F, D>>
    for Evaluations<F, D>
{
    #[inline]
    fn add_assign(&mut self, other: &'a Evaluations<F, D>) {
        assert_eq!(self.domain, other.domain, "domains are unequal");
        ark_std::cfg_iter_mut!(self.evals)
            .zip(&other.evals)
            .for_each(|(a, b)| *a += b);
    }
}

impl<'a, 'b, F: FftField, D: EvaluationDomain<F>> Sub<&'a Evaluations<F, D>>
    for &'b Evaluations<F, D>
{
    type Output = Evaluations<F, D>;

    #[inline]
    fn sub(self, other: &'a Evaluations<F, D>) -> Evaluations<F, D> {
        let mut result = self.clone();
        result -= other;
        result
    }
}

impl<'a, F: FftField, D: EvaluationDomain<F>> SubAssign<&'a Evaluations<F, D>>
    for Evaluations<F, D>
{
    #[inline]
    fn sub_assign(&mut self, other: &'a Evaluations<F, D>) {
        assert_eq!(self.domain, other.domain, "domains are unequal");
        ark_std::cfg_iter_mut!(self.evals)
            .zip(&other.evals)
            .for_each(|(a, b)| *a -= b);
    }
}

impl<'a, 'b, F: FftField, D: EvaluationDomain<F>> Div<&'a Evaluations<F, D>>
    for &'b Evaluations<F, D>
{
    type Output = Evaluations<F, D>;

    #[inline]
    fn div(self, other: &'a Evaluations<F, D>) -> Evaluations<F, D> {
        let mut result = self.clone();
        result /= other;
        result
    }
}

impl<'a, F: FftField, D: EvaluationDomain<F>> DivAssign<&'a Evaluations<F, D>>
    for Evaluations<F, D>
{
    #[inline]
    fn div_assign(&mut self, other: &'a Evaluations<F, D>) {
        assert_eq!(self.domain, other.domain, "domains are unequal");
        let mut other_copy = other.clone();
        batch_inversion(other_copy.evals.as_mut_slice());
        ark_std::cfg_iter_mut!(self.evals)
            .zip(&other_copy.evals)
            .for_each(|(a, b)| *a *= b);
    }
}
