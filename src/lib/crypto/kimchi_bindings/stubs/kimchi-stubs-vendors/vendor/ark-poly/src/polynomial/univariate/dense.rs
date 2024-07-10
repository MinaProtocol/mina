//! A dense univariate polynomial represented in coefficient form.
use crate::univariate::DenseOrSparsePolynomial;
use crate::{univariate::SparsePolynomial, Polynomial, UVPolynomial};
use crate::{EvaluationDomain, Evaluations, GeneralEvaluationDomain};
use ark_ff::{FftField, Field, Zero};
use ark_serialize::*;
use ark_std::rand::Rng;
use ark_std::{
    fmt,
    ops::{Add, AddAssign, Deref, DerefMut, Div, Mul, Neg, Sub, SubAssign},
    vec::Vec,
};

#[cfg(feature = "parallel")]
use ark_std::cmp::max;
#[cfg(feature = "parallel")]
use rayon::prelude::*;

/// Stores a polynomial in coefficient form.
#[derive(Clone, PartialEq, Eq, Hash, Default, CanonicalSerialize, CanonicalDeserialize)]
pub struct DensePolynomial<F: Field> {
    /// The coefficient of `x^i` is stored at location `i` in `self.coeffs`.
    pub coeffs: Vec<F>,
}

impl<F: Field> Polynomial<F> for DensePolynomial<F> {
    type Point = F;

    /// Returns the total degree of the polynomial
    fn degree(&self) -> usize {
        if self.is_zero() {
            0
        } else {
            assert!(self.coeffs.last().map_or(false, |coeff| !coeff.is_zero()));
            self.coeffs.len() - 1
        }
    }

    /// Evaluates `self` at the given `point` in `Self::Point`.
    fn evaluate(&self, point: &F) -> F {
        if self.is_zero() {
            return F::zero();
        } else if point.is_zero() {
            return self.coeffs[0];
        }
        self.internal_evaluate(point)
    }
}

#[cfg(feature = "parallel")]
// Set some minimum number of field elements to be worked on per thread
// to avoid per-thread costs dominating parallel execution time.
const MIN_ELEMENTS_PER_THREAD: usize = 16;

impl<F: Field> DensePolynomial<F> {
    #[inline]
    // Horner's method for polynomial evaluation
    fn horner_evaluate(poly_coeffs: &[F], point: &F) -> F {
        poly_coeffs
            .iter()
            .rfold(F::zero(), move |result, coeff| result * point + coeff)
    }

    #[cfg(not(feature = "parallel"))]
    fn internal_evaluate(&self, point: &F) -> F {
        Self::horner_evaluate(&self.coeffs, point)
    }

    #[cfg(feature = "parallel")]
    fn internal_evaluate(&self, point: &F) -> F {
        // Horners method - parallel method
        // compute the number of threads we will be using.
        let num_cpus_available = rayon::current_num_threads();
        let num_coeffs = self.coeffs.len();
        let num_elem_per_thread = max(num_coeffs / num_cpus_available, MIN_ELEMENTS_PER_THREAD);

        // run Horners method on each thread as follows:
        // 1) Split up the coefficients across each thread evenly.
        // 2) Do polynomial evaluation via horner's method for the thread's coefficeints
        // 3) Scale the result point^{thread coefficient start index}
        // Then obtain the final polynomial evaluation by summing each threads result.
        let result = self
            .coeffs
            .par_chunks(num_elem_per_thread)
            .enumerate()
            .map(|(i, chunk)| {
                let mut thread_result = Self::horner_evaluate(&chunk, point);
                thread_result *= point.pow(&[(i * num_elem_per_thread) as u64]);
                thread_result
            })
            .sum();
        result
    }
}

impl<F: Field> UVPolynomial<F> for DensePolynomial<F> {
    /// Constructs a new polynomial from a list of coefficients.
    fn from_coefficients_slice(coeffs: &[F]) -> Self {
        Self::from_coefficients_vec(coeffs.to_vec())
    }

    /// Constructs a new polynomial from a list of coefficients.
    fn from_coefficients_vec(coeffs: Vec<F>) -> Self {
        let mut result = Self { coeffs };
        // While there are zeros at the end of the coefficient vector, pop them off.
        result.truncate_leading_zeros();
        // Check that either the coefficients vec is empty or that the last coeff is
        // non-zero.
        assert!(result.coeffs.last().map_or(true, |coeff| !coeff.is_zero()));
        result
    }

    /// Returns the coefficients of `self`
    fn coeffs(&self) -> &[F] {
        &self.coeffs
    }

    /// Outputs a univariate polynomial of degree `d` where
    /// each coefficient is sampled uniformly at random.
    fn rand<R: Rng>(d: usize, rng: &mut R) -> Self {
        let mut random_coeffs = Vec::new();
        for _ in 0..=d {
            random_coeffs.push(F::rand(rng));
        }
        Self::from_coefficients_vec(random_coeffs)
    }
}

impl<F: FftField> DensePolynomial<F> {
    /// Multiply `self` by the vanishing polynomial for the domain `domain`.
    /// Returns the result of the multiplication.
    pub fn mul_by_vanishing_poly<D: EvaluationDomain<F>>(&self, domain: D) -> DensePolynomial<F> {
        let mut shifted = vec![F::zero(); domain.size()];
        shifted.extend_from_slice(&self.coeffs);
        cfg_iter_mut!(shifted)
            .zip(&self.coeffs)
            .for_each(|(s, c)| *s -= c);
        DensePolynomial::from_coefficients_vec(shifted)
    }

    /// Divide `self` by the vanishing polynomial for the domain `domain`.
    /// Returns the quotient and remainder of the division.
    pub fn divide_by_vanishing_poly<D: EvaluationDomain<F>>(
        &self,
        domain: D,
    ) -> Option<(DensePolynomial<F>, DensePolynomial<F>)> {
        let self_poly = DenseOrSparsePolynomial::from(self);
        let vanishing_poly = DenseOrSparsePolynomial::from(domain.vanishing_polynomial());
        self_poly.divide_with_q_and_r(&vanishing_poly)
    }
}

impl<F: Field> DensePolynomial<F> {
    fn truncate_leading_zeros(&mut self) {
        while self.coeffs.last().map_or(false, |c| c.is_zero()) {
            self.coeffs.pop();
        }
    }

    /// Perform a naive n^2 multiplication of `self` by `other`.
    pub fn naive_mul(&self, other: &Self) -> Self {
        if self.is_zero() || other.is_zero() {
            DensePolynomial::zero()
        } else {
            let mut result = vec![F::zero(); self.degree() + other.degree() + 1];
            for (i, self_coeff) in self.coeffs.iter().enumerate() {
                for (j, other_coeff) in other.coeffs.iter().enumerate() {
                    result[i + j] += &(*self_coeff * other_coeff);
                }
            }
            DensePolynomial::from_coefficients_vec(result)
        }
    }
}

impl<F: FftField> DensePolynomial<F> {
    /// Evaluate `self` over `domain`.
    pub fn evaluate_over_domain_by_ref<D: EvaluationDomain<F>>(
        &self,
        domain: D,
    ) -> Evaluations<F, D> {
        let poly: DenseOrSparsePolynomial<'_, F> = self.into();
        DenseOrSparsePolynomial::<F>::evaluate_over_domain(poly, domain)
    }

    /// Evaluate `self` over `domain`.
    pub fn evaluate_over_domain<D: EvaluationDomain<F>>(self, domain: D) -> Evaluations<F, D> {
        let poly: DenseOrSparsePolynomial<'_, F> = self.into();
        DenseOrSparsePolynomial::<F>::evaluate_over_domain(poly, domain)
    }
}

impl<F: Field> fmt::Debug for DensePolynomial<F> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        for (i, coeff) in self.coeffs.iter().enumerate().filter(|(_, c)| !c.is_zero()) {
            if i == 0 {
                write!(f, "\n{:?}", coeff)?;
            } else if i == 1 {
                write!(f, " + \n{:?} * x", coeff)?;
            } else {
                write!(f, " + \n{:?} * x^{}", coeff, i)?;
            }
        }
        Ok(())
    }
}

impl<F: Field> Deref for DensePolynomial<F> {
    type Target = [F];

    fn deref(&self) -> &[F] {
        &self.coeffs
    }
}

impl<F: Field> DerefMut for DensePolynomial<F> {
    fn deref_mut(&mut self) -> &mut [F] {
        &mut self.coeffs
    }
}

impl<F: Field> Add for DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    fn add(self, other: DensePolynomial<F>) -> Self {
        &self + &other
    }
}

impl<'a, 'b, F: Field> Add<&'a DensePolynomial<F>> for &'b DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    fn add(self, other: &'a DensePolynomial<F>) -> DensePolynomial<F> {
        let mut result = if self.is_zero() {
            other.clone()
        } else if other.is_zero() {
            self.clone()
        } else if self.degree() >= other.degree() {
            let mut result = self.clone();
            result
                .coeffs
                .iter_mut()
                .zip(&other.coeffs)
                .for_each(|(a, b)| {
                    *a += b;
                });
            result
        } else {
            let mut result = other.clone();
            result
                .coeffs
                .iter_mut()
                .zip(&self.coeffs)
                .for_each(|(a, b)| {
                    *a += b;
                });
            result
        };
        result.truncate_leading_zeros();
        result
    }
}

impl<'a, 'b, F: Field> Add<&'a SparsePolynomial<F>> for &'b DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    #[inline]
    fn add(self, other: &'a SparsePolynomial<F>) -> DensePolynomial<F> {
        let result = if self.is_zero() {
            other.clone().into()
        } else if other.is_zero() {
            self.clone()
        } else {
            let mut result = self.clone();
            // If `other` has higher degree than `self`, create a dense vector
            // storing the upper coefficients of the addition
            let mut upper_coeffs = match other.degree() > result.degree() {
                true => vec![F::zero(); other.degree() - result.degree()],
                false => Vec::new(),
            };
            for (pow, coeff) in other.iter() {
                if *pow <= result.degree() {
                    result.coeffs[*pow] += coeff;
                } else {
                    upper_coeffs[*pow - result.degree() - 1] = *coeff;
                }
            }
            result.coeffs.extend(upper_coeffs);
            result
        };
        result
    }
}

impl<'a, 'b, F: Field> AddAssign<&'a DensePolynomial<F>> for DensePolynomial<F> {
    fn add_assign(&mut self, other: &'a DensePolynomial<F>) {
        if self.is_zero() {
            self.coeffs.truncate(0);
            self.coeffs.extend_from_slice(&other.coeffs);
        } else if other.is_zero() {
        } else if self.degree() >= other.degree() {
            self.coeffs
                .iter_mut()
                .zip(&other.coeffs)
                .for_each(|(a, b)| {
                    *a += b;
                });
        } else {
            // Add the necessary number of zero coefficients.
            self.coeffs.resize(other.coeffs.len(), F::zero());
            self.coeffs
                .iter_mut()
                .zip(&other.coeffs)
                .for_each(|(a, b)| {
                    *a += b;
                });
            self.truncate_leading_zeros();
        }
    }
}

impl<'a, 'b, F: Field> AddAssign<(F, &'a DensePolynomial<F>)> for DensePolynomial<F> {
    fn add_assign(&mut self, (f, other): (F, &'a DensePolynomial<F>)) {
        if self.is_zero() {
            self.coeffs.truncate(0);
            self.coeffs.extend_from_slice(&other.coeffs);
            self.coeffs.iter_mut().for_each(|c| *c *= &f);
            return;
        } else if other.is_zero() {
            return;
        } else if self.degree() >= other.degree() {
        } else {
            // Add the necessary number of zero coefficients.
            self.coeffs.resize(other.coeffs.len(), F::zero());
        }
        self.coeffs
            .iter_mut()
            .zip(&other.coeffs)
            .for_each(|(a, b)| {
                *a += &(f * b);
            });
        // If the leading coefficient ends up being zero, pop it off.
        // This can happen if they were the same degree, or if a
        // polynomial's coefficients were constructed with leading zeros.
        self.truncate_leading_zeros();
    }
}

impl<'a, F: Field> AddAssign<&'a SparsePolynomial<F>> for DensePolynomial<F> {
    #[inline]
    fn add_assign(&mut self, other: &'a SparsePolynomial<F>) {
        if self.is_zero() {
            self.coeffs.truncate(0);
            self.coeffs.resize(other.degree() + 1, F::zero());

            for (i, coeff) in other.iter() {
                self.coeffs[*i] = *coeff;
            }
            return;
        } else if other.is_zero() {
            return;
        } else {
            // If `other` has higher degree than `self`, create a dense vector
            // storing the upper coefficients of the addition
            let mut upper_coeffs = match other.degree() > self.degree() {
                true => vec![F::zero(); other.degree() - self.degree()],
                false => Vec::new(),
            };
            for (pow, coeff) in other.iter() {
                if *pow <= self.degree() {
                    self.coeffs[*pow] += coeff;
                } else {
                    upper_coeffs[*pow - self.degree() - 1] = *coeff;
                }
            }
            self.coeffs.extend(upper_coeffs);
        }
    }
}

impl<F: Field> Neg for DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    #[inline]
    fn neg(mut self) -> DensePolynomial<F> {
        self.coeffs.iter_mut().for_each(|coeff| {
            *coeff = -*coeff;
        });
        self
    }
}

impl<'a, 'b, F: Field> Sub<&'a DensePolynomial<F>> for &'b DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    #[inline]
    fn sub(self, other: &'a DensePolynomial<F>) -> DensePolynomial<F> {
        let mut result = if self.is_zero() {
            let mut result = other.clone();
            result.coeffs.iter_mut().for_each(|c| *c = -(*c));
            result
        } else if other.is_zero() {
            self.clone()
        } else if self.degree() >= other.degree() {
            let mut result = self.clone();
            result
                .coeffs
                .iter_mut()
                .zip(&other.coeffs)
                .for_each(|(a, b)| *a -= b);
            result
        } else {
            let mut result = self.clone();
            result.coeffs.resize(other.coeffs.len(), F::zero());
            result
                .coeffs
                .iter_mut()
                .zip(&other.coeffs)
                .for_each(|(a, b)| *a -= b);
            result
        };
        result.truncate_leading_zeros();
        result
    }
}

impl<'a, 'b, F: Field> Sub<&'a SparsePolynomial<F>> for &'b DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    #[inline]
    fn sub(self, other: &'a SparsePolynomial<F>) -> DensePolynomial<F> {
        let result = if self.is_zero() {
            let result = other.clone();
            result.neg().into()
        } else if other.is_zero() {
            self.clone()
        } else {
            let mut result = self.clone();
            // If `other` has higher degree than `self`, create a dense vector
            // storing the upper coefficients of the subtraction
            let mut upper_coeffs = match other.degree() > result.degree() {
                true => vec![F::zero(); other.degree() - result.degree()],
                false => Vec::new(),
            };
            for (pow, coeff) in other.iter() {
                if *pow <= result.degree() {
                    result.coeffs[*pow] -= coeff;
                } else {
                    upper_coeffs[*pow - result.degree() - 1] = -*coeff;
                }
            }
            result.coeffs.extend(upper_coeffs);
            result
        };
        result
    }
}

impl<'a, 'b, F: Field> SubAssign<&'a DensePolynomial<F>> for DensePolynomial<F> {
    #[inline]
    fn sub_assign(&mut self, other: &'a DensePolynomial<F>) {
        if self.is_zero() {
            self.coeffs.resize(other.coeffs.len(), F::zero());
        } else if other.is_zero() {
            return;
        } else if self.degree() >= other.degree() {
        } else {
            // Add the necessary number of zero coefficients.
            self.coeffs.resize(other.coeffs.len(), F::zero());
        }
        self.coeffs
            .iter_mut()
            .zip(&other.coeffs)
            .for_each(|(a, b)| {
                *a -= b;
            });
        // If the leading coefficient ends up being zero, pop it off.
        // This can happen if they were the same degree, or if other's
        // coefficients were constructed with leading zeros.
        self.truncate_leading_zeros();
    }
}

impl<'a, F: Field> SubAssign<&'a SparsePolynomial<F>> for DensePolynomial<F> {
    #[inline]
    fn sub_assign(&mut self, other: &'a SparsePolynomial<F>) {
        if self.is_zero() {
            self.coeffs.truncate(0);
            self.coeffs.resize(other.degree() + 1, F::zero());

            for (i, coeff) in other.iter() {
                self.coeffs[*i] = (*coeff).neg();
            }
            return;
        } else if other.is_zero() {
            return;
        } else {
            // If `other` has higher degree than `self`, create a dense vector
            // storing the upper coefficients of the subtraction
            let mut upper_coeffs = match other.degree() > self.degree() {
                true => vec![F::zero(); other.degree() - self.degree()],
                false => Vec::new(),
            };
            for (pow, coeff) in other.iter() {
                if *pow <= self.degree() {
                    self.coeffs[*pow] -= coeff;
                } else {
                    upper_coeffs[*pow - self.degree() - 1] = -*coeff;
                }
            }
            self.coeffs.extend(upper_coeffs);
        }
    }
}

impl<'a, 'b, F: Field> Div<&'a DensePolynomial<F>> for &'b DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    #[inline]
    fn div(self, divisor: &'a DensePolynomial<F>) -> DensePolynomial<F> {
        let a = DenseOrSparsePolynomial::from(self);
        let b = DenseOrSparsePolynomial::from(divisor);
        a.divide_with_q_and_r(&b).expect("division failed").0
    }
}

impl<'a, 'b, F: Field> Mul<F> for &'b DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    #[inline]
    fn mul(self, elem: F) -> DensePolynomial<F> {
        if self.is_zero() || elem.is_zero() {
            DensePolynomial::zero()
        } else {
            let mut result = self.clone();
            cfg_iter_mut!(result).for_each(|e| {
                *e *= elem;
            });
            result
        }
    }
}

/// Performs O(nlogn) multiplication of polynomials if F is smooth.
impl<'a, 'b, F: FftField> Mul<&'a DensePolynomial<F>> for &'b DensePolynomial<F> {
    type Output = DensePolynomial<F>;

    #[inline]
    fn mul(self, other: &'a DensePolynomial<F>) -> DensePolynomial<F> {
        if self.is_zero() || other.is_zero() {
            DensePolynomial::zero()
        } else {
            let domain = GeneralEvaluationDomain::new(self.coeffs.len() + other.coeffs.len())
                .expect("field is not smooth enough to construct domain");
            let mut self_evals = self.evaluate_over_domain_by_ref(domain);
            let other_evals = other.evaluate_over_domain_by_ref(domain);
            self_evals *= &other_evals;
            self_evals.interpolate()
        }
    }
}

impl<F: Field> Zero for DensePolynomial<F> {
    /// Returns the zero polynomial.
    fn zero() -> Self {
        Self { coeffs: Vec::new() }
    }

    /// Checks if the given polynomial is zero.
    fn is_zero(&self) -> bool {
        self.coeffs.is_empty() || self.coeffs.iter().all(|coeff| coeff.is_zero())
    }
}

#[cfg(test)]
mod tests {
    use crate::polynomial::univariate::*;
    use crate::{EvaluationDomain, GeneralEvaluationDomain};
    use ark_ff::{Field, One, UniformRand, Zero};
    use ark_std::{rand::Rng, test_rng};
    use ark_test_curves::bls12_381::Fr;

    fn rand_sparse_poly<R: Rng>(degree: usize, rng: &mut R) -> SparsePolynomial<Fr> {
        // Initialize coeffs so that its guaranteed to have a x^{degree} term
        let mut coeffs = vec![(degree, Fr::rand(rng))];
        for i in 0..degree {
            if !rng.gen_bool(0.8) {
                coeffs.push((i, Fr::rand(rng)));
            }
        }
        SparsePolynomial::from_coefficients_vec(coeffs)
    }

    #[test]
    fn double_polynomials_random() {
        let rng = &mut test_rng();
        for degree in 0..70 {
            let p = DensePolynomial::<Fr>::rand(degree, rng);
            let p_double = &p + &p;
            let p_quad = &p_double + &p_double;
            assert_eq!(&(&(&p + &p) + &p) + &p, p_quad);
        }
    }

    #[test]
    fn add_polynomials() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let p1 = DensePolynomial::<Fr>::rand(a_degree, rng);
                let p2 = DensePolynomial::<Fr>::rand(b_degree, rng);
                let res1 = &p1 + &p2;
                let res2 = &p2 + &p1;
                assert_eq!(res1, res2);
            }
        }
    }

    #[test]
    fn add_sparse_polynomials() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let p1 = DensePolynomial::<Fr>::rand(a_degree, rng);
                let p2 = rand_sparse_poly(b_degree, rng);
                let res = &p1 + &p2;
                assert_eq!(res, &p1 + &Into::<DensePolynomial<Fr>>::into(p2));
            }
        }
    }

    #[test]
    fn add_assign_sparse_polynomials() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let p1 = DensePolynomial::<Fr>::rand(a_degree, rng);
                let p2 = rand_sparse_poly(b_degree, rng);

                let mut res = p1.clone();
                res += &p2;
                assert_eq!(res, &p1 + &Into::<DensePolynomial<Fr>>::into(p2));
            }
        }
    }

    #[test]
    fn add_polynomials_with_mul() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let mut p1 = DensePolynomial::rand(a_degree, rng);
                let p2 = DensePolynomial::rand(b_degree, rng);
                let f = Fr::rand(rng);
                let f_p2 = DensePolynomial::from_coefficients_vec(
                    p2.coeffs.iter().map(|c| f * c).collect(),
                );
                let res2 = &f_p2 + &p1;
                p1 += (f, &p2);
                let res1 = p1;
                assert_eq!(res1, res2);
            }
        }
    }

    #[test]
    fn sub_polynomials() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let p1 = DensePolynomial::<Fr>::rand(a_degree, rng);
                let p2 = DensePolynomial::<Fr>::rand(b_degree, rng);
                let res1 = &p1 - &p2;
                let res2 = &p2 - &p1;
                assert_eq!(&res1 + &p2, p1);
                assert_eq!(res1, -res2);
            }
        }
    }

    #[test]
    fn sub_sparse_polynomials() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let p1 = DensePolynomial::<Fr>::rand(a_degree, rng);
                let p2 = rand_sparse_poly(b_degree, rng);
                let res = &p1 - &p2;
                assert_eq!(res, &p1 - &Into::<DensePolynomial<Fr>>::into(p2));
            }
        }
    }

    #[test]
    fn sub_assign_sparse_polynomials() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let p1 = DensePolynomial::<Fr>::rand(a_degree, rng);
                let p2 = rand_sparse_poly(b_degree, rng);

                let mut res = p1.clone();
                res -= &p2;
                assert_eq!(res, &p1 - &Into::<DensePolynomial<Fr>>::into(p2));
            }
        }
    }

    #[test]
    fn polynomial_additive_identity() {
        // Test adding polynomials with its negative equals 0
        let mut rng = test_rng();
        for degree in 0..70 {
            let poly = DensePolynomial::<Fr>::rand(degree, &mut rng);
            let neg = -poly.clone();
            let result = poly + neg;
            assert!(result.is_zero());
            assert_eq!(result.degree(), 0);

            // Test with SubAssign trait
            let poly = DensePolynomial::<Fr>::rand(degree, &mut rng);
            let mut result = poly.clone();
            result -= &poly;
            assert!(result.is_zero());
            assert_eq!(result.degree(), 0);
        }
    }

    #[test]
    fn divide_polynomials_fixed() {
        let dividend = DensePolynomial::from_coefficients_slice(&[
            "4".parse().unwrap(),
            "8".parse().unwrap(),
            "5".parse().unwrap(),
            "1".parse().unwrap(),
        ]);
        let divisor = DensePolynomial::from_coefficients_slice(&[Fr::one(), Fr::one()]); // Construct a monic linear polynomial.
        let result = &dividend / &divisor;
        let expected_result = DensePolynomial::from_coefficients_slice(&[
            "4".parse().unwrap(),
            "4".parse().unwrap(),
            "1".parse().unwrap(),
        ]);
        assert_eq!(expected_result, result);
    }

    #[test]
    fn divide_polynomials_random() {
        let rng = &mut test_rng();

        for a_degree in 0..50 {
            for b_degree in 0..50 {
                let dividend = DensePolynomial::<Fr>::rand(a_degree, rng);
                let divisor = DensePolynomial::<Fr>::rand(b_degree, rng);
                if let Some((quotient, remainder)) = DenseOrSparsePolynomial::divide_with_q_and_r(
                    &(&dividend).into(),
                    &(&divisor).into(),
                ) {
                    assert_eq!(dividend, &(&divisor * &quotient) + &remainder)
                }
            }
        }
    }

    #[test]
    fn evaluate_polynomials() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            let p = DensePolynomial::rand(a_degree, rng);
            let point: Fr = Fr::rand(rng);
            let mut total = Fr::zero();
            for (i, coeff) in p.coeffs.iter().enumerate() {
                total += &(point.pow(&[i as u64]) * coeff);
            }
            assert_eq!(p.evaluate(&point), total);
        }
    }

    #[test]
    fn mul_random_element() {
        let rng = &mut test_rng();
        for degree in 0..70 {
            let a = DensePolynomial::<Fr>::rand(degree, rng);
            let e = Fr::rand(rng);
            assert_eq!(
                &a * e,
                a.naive_mul(&DensePolynomial::from_coefficients_slice(&[e]))
            )
        }
    }

    #[test]
    fn mul_polynomials_random() {
        let rng = &mut test_rng();
        for a_degree in 0..70 {
            for b_degree in 0..70 {
                let a = DensePolynomial::<Fr>::rand(a_degree, rng);
                let b = DensePolynomial::<Fr>::rand(b_degree, rng);
                assert_eq!(&a * &b, a.naive_mul(&b))
            }
        }
    }

    #[test]
    fn mul_by_vanishing_poly() {
        let rng = &mut test_rng();
        for size in 1..10 {
            let domain = GeneralEvaluationDomain::new(1 << size).unwrap();
            for degree in 0..70 {
                let p = DensePolynomial::<Fr>::rand(degree, rng);
                let ans1 = p.mul_by_vanishing_poly(domain);
                let ans2 = &p * &domain.vanishing_polynomial().into();
                assert_eq!(ans1, ans2);
            }
        }
    }

    #[test]
    fn test_leading_zero() {
        let n = 10;
        let rand_poly = DensePolynomial::rand(n, &mut test_rng());
        let coefficients = rand_poly.coeffs.clone();
        let leading_coefficient: Fr = coefficients[n];

        let negative_leading_coefficient = -leading_coefficient;
        let inverse_leading_coefficient = leading_coefficient.inverse().unwrap();

        let mut inverse_coefficients = coefficients.clone();
        inverse_coefficients[n] = inverse_leading_coefficient;

        let mut negative_coefficients = coefficients;
        negative_coefficients[n] = negative_leading_coefficient;

        let negative_poly = DensePolynomial::from_coefficients_vec(negative_coefficients);
        let inverse_poly = DensePolynomial::from_coefficients_vec(inverse_coefficients);

        let x = &inverse_poly * &rand_poly;
        assert_eq!(x.degree(), 2 * n);
        assert!(!x.coeffs.last().unwrap().is_zero());

        let y = &negative_poly + &rand_poly;
        assert_eq!(y.degree(), n - 1);
        assert!(!y.coeffs.last().unwrap().is_zero());
    }
}
