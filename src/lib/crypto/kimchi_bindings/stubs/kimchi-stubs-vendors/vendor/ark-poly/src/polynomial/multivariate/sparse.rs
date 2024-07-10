//! A sparse multivariate polynomial represented in coefficient form.
use crate::{
    multivariate::{SparseTerm, Term},
    MVPolynomial, Polynomial,
};
use ark_ff::{Field, Zero};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize, SerializationError};
use ark_std::rand::Rng;
use ark_std::{
    cmp::Ordering,
    fmt,
    io::{Read, Write},
    ops::{Add, AddAssign, Neg, Sub, SubAssign},
    vec::Vec,
};

#[cfg(feature = "parallel")]
use rayon::prelude::*;

/// Stores a sparse multivariate polynomial in coefficient form.
#[derive(Derivative, CanonicalSerialize, CanonicalDeserialize)]
#[derivative(Clone, PartialEq, Eq, Hash, Default)]
pub struct SparsePolynomial<F: Field, T: Term> {
    /// The number of variables the polynomial supports
    #[derivative(PartialEq = "ignore")]
    pub num_vars: usize,
    /// List of each term along with its coefficient
    pub terms: Vec<(F, T)>,
}

impl<F: Field, T: Term> SparsePolynomial<F, T> {
    fn remove_zeros(&mut self) {
        self.terms.retain(|(c, _)| !c.is_zero());
    }
}

impl<F: Field> Polynomial<F> for SparsePolynomial<F, SparseTerm> {
    type Point = Vec<F>;

    /// Returns the total degree of the polynomial
    fn degree(&self) -> usize {
        self.terms
            .iter()
            .map(|(_, term)| term.degree())
            .max()
            .unwrap_or(0)
    }

    /// Evaluates `self` at the given `point` in `Self::Point`.
    fn evaluate(&self, point: &Vec<F>) -> F {
        assert!(point.len() >= self.num_vars, "Invalid evaluation domain");
        if self.is_zero() {
            return F::zero();
        }
        cfg_into_iter!(&self.terms)
            .map(|(coeff, term)| *coeff * term.evaluate(point))
            .sum()
    }
}

impl<F: Field> MVPolynomial<F> for SparsePolynomial<F, SparseTerm> {
    /// Returns the number of variables in `self`
    fn num_vars(&self) -> usize {
        self.num_vars
    }

    /// Outputs an `l`-variate polynomial which is the sum of `l` `d`-degree
    /// univariate polynomials where each coefficient is sampled uniformly at random.
    fn rand<R: Rng>(d: usize, l: usize, rng: &mut R) -> Self {
        let mut random_terms = Vec::new();
        random_terms.push((F::rand(rng), SparseTerm::new(vec![])));
        for var in 0..l {
            for deg in 1..=d {
                random_terms.push((F::rand(rng), SparseTerm::new(vec![(var, deg)])));
            }
        }
        Self::from_coefficients_vec(l, random_terms)
    }

    type Term = SparseTerm;

    /// Constructs a new polynomial from a list of tuples of the form `(coeff, Self::Term)`
    fn from_coefficients_vec(num_vars: usize, mut terms: Vec<(F, SparseTerm)>) -> Self {
        // Ensure that terms are in ascending order.
        terms.sort_by(|(_, t1), (_, t2)| t1.cmp(t2));
        // If any terms are duplicated, add them together
        let mut terms_dedup: Vec<(F, SparseTerm)> = Vec::new();
        for term in terms {
            if let Some(prev) = terms_dedup.last_mut() {
                if prev.1 == term.1 {
                    *prev = (prev.0 + term.0, prev.1.clone());
                    continue;
                }
            };
            // Assert correct number of indeterminates
            assert!(
                term.1.iter().all(|(var, _)| *var < num_vars),
                "Invalid number of indeterminates"
            );
            terms_dedup.push(term);
        }
        let mut result = Self {
            num_vars,
            terms: terms_dedup,
        };
        // Remove any terms with zero coefficients
        result.remove_zeros();
        result
    }

    /// Returns the terms of a `self` as a list of tuples of the form `(coeff, Self::Term)`
    fn terms(&self) -> &[(F, Self::Term)] {
        self.terms.as_slice()
    }
}

impl<F: Field, T: Term> Add for SparsePolynomial<F, T> {
    type Output = SparsePolynomial<F, T>;

    fn add(self, other: SparsePolynomial<F, T>) -> Self {
        &self + &other
    }
}

impl<'a, 'b, F: Field, T: Term> Add<&'a SparsePolynomial<F, T>> for &'b SparsePolynomial<F, T> {
    type Output = SparsePolynomial<F, T>;

    fn add(self, other: &'a SparsePolynomial<F, T>) -> SparsePolynomial<F, T> {
        let mut result = Vec::new();
        let mut cur_iter = self.terms.iter().peekable();
        let mut other_iter = other.terms.iter().peekable();
        // Since both polynomials are sorted, iterate over them in ascending order,
        // combining any common terms
        loop {
            // Peek at iterators to decide which to take from
            let which = match (cur_iter.peek(), other_iter.peek()) {
                (Some(cur), Some(other)) => Some((cur.1).cmp(&other.1)),
                (Some(_), None) => Some(Ordering::Less),
                (None, Some(_)) => Some(Ordering::Greater),
                (None, None) => None,
            };
            // Push the smallest element to the `result` coefficient vec
            let smallest = match which {
                Some(Ordering::Less) => cur_iter.next().unwrap().clone(),
                Some(Ordering::Equal) => {
                    let other = other_iter.next().unwrap();
                    let cur = cur_iter.next().unwrap();
                    (cur.0 + other.0, cur.1.clone())
                }
                Some(Ordering::Greater) => other_iter.next().unwrap().clone(),
                None => break,
            };
            result.push(smallest);
        }
        // Remove any zero terms
        result.retain(|(c, _)| !c.is_zero());
        SparsePolynomial {
            num_vars: core::cmp::max(self.num_vars, other.num_vars),
            terms: result,
        }
    }
}

impl<'a, 'b, F: Field, T: Term> AddAssign<&'a SparsePolynomial<F, T>> for SparsePolynomial<F, T> {
    fn add_assign(&mut self, other: &'a SparsePolynomial<F, T>) {
        *self = &*self + other;
    }
}

impl<'a, 'b, F: Field, T: Term> AddAssign<(F, &'a SparsePolynomial<F, T>)>
    for SparsePolynomial<F, T>
{
    fn add_assign(&mut self, (f, other): (F, &'a SparsePolynomial<F, T>)) {
        let other = Self {
            num_vars: other.num_vars,
            terms: other
                .terms
                .iter()
                .map(|(coeff, term)| (*coeff * &f, term.clone()))
                .collect(),
        };
        // Note the call to `Add` will remove also any duplicates
        *self = &*self + &other;
    }
}

impl<F: Field, T: Term> Neg for SparsePolynomial<F, T> {
    type Output = SparsePolynomial<F, T>;

    #[inline]
    fn neg(mut self) -> SparsePolynomial<F, T> {
        for coeff in &mut self.terms {
            (*coeff).0 = -coeff.0;
        }
        self
    }
}

impl<'a, 'b, F: Field, T: Term> Sub<&'a SparsePolynomial<F, T>> for &'b SparsePolynomial<F, T> {
    type Output = SparsePolynomial<F, T>;

    #[inline]
    fn sub(self, other: &'a SparsePolynomial<F, T>) -> SparsePolynomial<F, T> {
        let neg_other = other.clone().neg();
        self + &neg_other
    }
}

impl<'a, 'b, F: Field, T: Term> SubAssign<&'a SparsePolynomial<F, T>> for SparsePolynomial<F, T> {
    #[inline]
    fn sub_assign(&mut self, other: &'a SparsePolynomial<F, T>) {
        *self = &*self - other;
    }
}

impl<F: Field, T: Term> fmt::Debug for SparsePolynomial<F, T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        for (coeff, term) in self.terms.iter().filter(|(c, _)| !c.is_zero()) {
            if term.is_constant() {
                write!(f, "\n{:?}", coeff)?;
            } else {
                write!(f, "\n{:?} {:?}", coeff, term)?;
            }
        }
        Ok(())
    }
}

impl<F: Field, T: Term> Zero for SparsePolynomial<F, T> {
    /// Returns the zero polynomial.
    fn zero() -> Self {
        Self {
            num_vars: 0,
            terms: Vec::new(),
        }
    }

    /// Checks if the given polynomial is zero.
    fn is_zero(&self) -> bool {
        self.terms.is_empty() || self.terms.iter().all(|(c, _)| c.is_zero())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_ff::{Field, UniformRand, Zero};
    use ark_std::test_rng;
    use ark_test_curves::bls12_381::Fr;

    // TODO: Make tests generic over term type

    /// Generate random `l`-variate polynomial of maximum individual degree `d`
    fn rand_poly<R: Rng>(l: usize, d: usize, rng: &mut R) -> SparsePolynomial<Fr, SparseTerm> {
        let mut random_terms = Vec::new();
        let num_terms = rng.gen_range(1..1000);
        // For each term, randomly select up to `l` variables with degree
        // in [1,d] and random coefficient
        random_terms.push((Fr::rand(rng), SparseTerm::new(vec![])));
        for _ in 1..num_terms {
            let term = (0..l)
                .map(|i| {
                    if rng.gen_bool(0.5) {
                        Some((i, rng.gen_range(1..(d + 1))))
                    } else {
                        None
                    }
                })
                .filter(|t| t.is_some())
                .map(|t| t.unwrap())
                .collect();
            let coeff = Fr::rand(rng);
            random_terms.push((coeff, SparseTerm::new(term)));
        }
        SparsePolynomial::from_coefficients_slice(l, &random_terms)
    }

    /// Perform a naive n^2 multiplication of `self` by `other`.
    fn naive_mul(
        cur: &SparsePolynomial<Fr, SparseTerm>,
        other: &SparsePolynomial<Fr, SparseTerm>,
    ) -> SparsePolynomial<Fr, SparseTerm> {
        if cur.is_zero() || other.is_zero() {
            SparsePolynomial::zero()
        } else {
            let mut result_terms = Vec::new();
            for (cur_coeff, cur_term) in cur.terms.iter() {
                for (other_coeff, other_term) in other.terms.iter() {
                    let mut term = cur_term.0.clone();
                    term.extend(other_term.0.clone());
                    result_terms.push((*cur_coeff * *other_coeff, SparseTerm::new(term)));
                }
            }
            SparsePolynomial::from_coefficients_slice(cur.num_vars, result_terms.as_slice())
        }
    }

    #[test]
    fn add_polynomials() {
        let rng = &mut test_rng();
        let max_degree = 10;
        for a_var_count in 1..20 {
            for b_var_count in 1..20 {
                let p1 = rand_poly(a_var_count, max_degree, rng);
                let p2 = rand_poly(b_var_count, max_degree, rng);
                let res1 = &p1 + &p2;
                let res2 = &p2 + &p1;
                assert_eq!(res1, res2);
            }
        }
    }

    #[test]
    fn sub_polynomials() {
        let rng = &mut test_rng();
        let max_degree = 10;
        for a_var_count in 1..20 {
            for b_var_count in 1..20 {
                let p1 = rand_poly(a_var_count, max_degree, rng);
                let p2 = rand_poly(b_var_count, max_degree, rng);
                let res1 = &p1 - &p2;
                let res2 = &p2 - &p1;
                assert_eq!(&res1 + &p2, p1);
                assert_eq!(res1, -res2);
            }
        }
    }

    #[test]
    fn evaluate_polynomials() {
        let rng = &mut test_rng();
        let max_degree = 10;
        for var_count in 1..20 {
            let p = rand_poly(var_count, max_degree, rng);
            let mut point = Vec::with_capacity(var_count);
            for _ in 0..var_count {
                point.push(Fr::rand(rng));
            }
            let mut total = Fr::zero();
            for (coeff, term) in p.terms.iter() {
                let mut summand = *coeff;
                for var in term.iter() {
                    let eval = point.get(var.0).unwrap();
                    summand *= eval.pow(&[var.1 as u64]);
                }
                total += summand;
            }
            assert_eq!(p.evaluate(&point), total);
        }
    }

    #[test]
    fn add_and_evaluate_polynomials() {
        let rng = &mut test_rng();
        let max_degree = 10;
        for a_var_count in 1..20 {
            for b_var_count in 1..20 {
                let p1 = rand_poly(a_var_count, max_degree, rng);
                let p2 = rand_poly(b_var_count, max_degree, rng);
                let mut point = Vec::new();
                for _ in 0..core::cmp::max(a_var_count, b_var_count) {
                    point.push(Fr::rand(rng));
                }
                // Evaluate both polynomials at a given point
                let eval1 = p1.evaluate(&point);
                let eval2 = p2.evaluate(&point);
                // Add polynomials
                let sum = &p1 + &p2;
                // Evaluate result at same point
                let eval3 = sum.evaluate(&point);
                assert_eq!(eval1 + eval2, eval3);
            }
        }
    }

    #[test]
    /// This is just to make sure naive_mul works as expected
    fn mul_polynomials_fixed() {
        let a = SparsePolynomial::from_coefficients_slice(
            4,
            &[
                ("2".parse().unwrap(), SparseTerm(vec![])),
                ("4".parse().unwrap(), SparseTerm(vec![(0, 1), (1, 2)])),
                ("8".parse().unwrap(), SparseTerm(vec![(0, 1), (0, 1)])),
                ("1".parse().unwrap(), SparseTerm(vec![(3, 0)])),
            ],
        );
        let b = SparsePolynomial::from_coefficients_slice(
            4,
            &[
                ("1".parse().unwrap(), SparseTerm(vec![(0, 1), (1, 2)])),
                ("2".parse().unwrap(), SparseTerm(vec![(2, 1)])),
                ("1".parse().unwrap(), SparseTerm(vec![(3, 1)])),
            ],
        );
        let result = naive_mul(&a, &b);
        let expected = SparsePolynomial::from_coefficients_slice(
            4,
            &[
                ("3".parse().unwrap(), SparseTerm(vec![(0, 1), (1, 2)])),
                ("6".parse().unwrap(), SparseTerm(vec![(2, 1)])),
                ("3".parse().unwrap(), SparseTerm(vec![(3, 1)])),
                ("4".parse().unwrap(), SparseTerm(vec![(0, 2), (1, 4)])),
                (
                    "8".parse().unwrap(),
                    SparseTerm(vec![(0, 1), (1, 2), (2, 1)]),
                ),
                (
                    "4".parse().unwrap(),
                    SparseTerm(vec![(0, 1), (1, 2), (3, 1)]),
                ),
                ("8".parse().unwrap(), SparseTerm(vec![(0, 3), (1, 2)])),
                ("16".parse().unwrap(), SparseTerm(vec![(0, 2), (2, 1)])),
                ("8".parse().unwrap(), SparseTerm(vec![(0, 2), (3, 1)])),
            ],
        );
        assert_eq!(expected, result);
    }
}
