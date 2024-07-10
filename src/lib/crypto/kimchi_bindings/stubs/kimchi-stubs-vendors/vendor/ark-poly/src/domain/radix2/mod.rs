//! This module defines `Radix2EvaluationDomain`, an `EvaluationDomain`
//! for performing various kinds of polynomial arithmetic on top of
//! fields that are FFT-friendly. `Radix2EvaluationDomain` supports
//! FFTs of size at most `2^F::TWO_ADICITY`.

pub use crate::domain::utils::Elements;
use crate::domain::{DomainCoeff, EvaluationDomain};
use ark_ff::{FftField, FftParameters};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize, SerializationError};
use ark_std::{
    convert::TryFrom,
    fmt,
    io::{Read, Write},
    vec::Vec,
};

mod fft;

/// Defines a domain over which finite field (I)FFTs can be performed. Works
/// only for fields that have a large multiplicative subgroup of size that is
/// a power-of-2.
#[derive(Copy, Clone, Hash, Eq, PartialEq, CanonicalSerialize, CanonicalDeserialize)]
pub struct Radix2EvaluationDomain<F: FftField> {
    /// The size of the domain.
    pub size: u64,
    /// `log_2(self.size)`.
    pub log_size_of_group: u32,
    /// Size of the domain as a field element.
    pub size_as_field_element: F,
    /// Inverse of the size in the field.
    pub size_inv: F,
    /// A generator of the subgroup.
    pub group_gen: F,
    /// Inverse of the generator of the subgroup.
    pub group_gen_inv: F,
    /// Multiplicative generator of the finite field.
    pub generator_inv: F,
}

impl<F: FftField> fmt::Debug for Radix2EvaluationDomain<F> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Radix-2 multiplicative subgroup of size {}", self.size)
    }
}

impl<F: FftField> EvaluationDomain<F> for Radix2EvaluationDomain<F> {
    type Elements = Elements<F>;

    /// Construct a domain that is large enough for evaluations of a polynomial
    /// having `num_coeffs` coefficients.
    fn new(num_coeffs: usize) -> Option<Self> {
        // Compute the size of our evaluation domain
        let size = if num_coeffs.is_power_of_two() {
            num_coeffs as u64
        } else {
            num_coeffs.next_power_of_two() as u64
        };
        let log_size_of_group = size.trailing_zeros();

        // libfqfft uses > https://github.com/scipr-lab/libfqfft/blob/e0183b2cef7d4c5deb21a6eaf3fe3b586d738fe0/libfqfft/evaluation_domain/domains/basic_radix2_domain.tcc#L33
        if log_size_of_group > F::FftParams::TWO_ADICITY {
            return None;
        }

        // Compute the generator for the multiplicative subgroup.
        // It should be the 2^(log_size_of_group) root of unity.
        let group_gen = F::get_root_of_unity(usize::try_from(size).unwrap())?;
        // Check that it is indeed the 2^(log_size_of_group) root of unity.
        debug_assert_eq!(group_gen.pow([size]), F::one());
        let size_as_field_element = F::from(size);
        let size_inv = size_as_field_element.inverse()?;

        Some(Radix2EvaluationDomain {
            size,
            log_size_of_group,
            size_as_field_element,
            size_inv,
            group_gen,
            group_gen_inv: group_gen.inverse()?,
            generator_inv: F::multiplicative_generator().inverse()?,
        })
    }

    fn compute_size_of_domain(num_coeffs: usize) -> Option<usize> {
        let size = num_coeffs.next_power_of_two();
        if size.trailing_zeros() > F::FftParams::TWO_ADICITY {
            None
        } else {
            Some(size)
        }
    }

    #[inline]
    fn size(&self) -> usize {
        usize::try_from(self.size).unwrap()
    }

    #[inline]
    fn fft_in_place<T: DomainCoeff<F>>(&self, coeffs: &mut Vec<T>) {
        coeffs.resize(self.size(), T::zero());
        self.in_order_fft_in_place(&mut *coeffs)
    }

    #[inline]
    fn ifft_in_place<T: DomainCoeff<F>>(&self, evals: &mut Vec<T>) {
        evals.resize(self.size(), T::zero());
        self.in_order_ifft_in_place(&mut *evals);
    }

    #[inline]
    fn coset_ifft_in_place<T: DomainCoeff<F>>(&self, evals: &mut Vec<T>) {
        evals.resize(self.size(), T::zero());
        self.in_order_coset_ifft_in_place(&mut *evals);
    }

    fn evaluate_all_lagrange_coefficients(&self, tau: F) -> Vec<F> {
        // Evaluate all Lagrange polynomials at tau to get the lagrange coefficients.
        // Define the following as
        // - H: The coset we are in, with generator g and offset h
        // - m: The size of the coset H
        // - Z_H: The vanishing polynomial for H. Z_H(x) = prod_{i in m} (x - hg^i) = x^m - h^m
        // - v_i: A sequence of values, where v_0 = 1/(m * h^(m-1)), and v_{i + 1} = g * v_i
        //
        // We then compute L_{i,H}(tau) as `L_{i,H}(tau) = Z_H(tau) * v_i / (tau - h g^i)`
        //
        // However, if tau in H, both the numerator and denominator equal 0
        // when i corresponds to the value tau equals, and the coefficient is 0 everywhere else.
        // We handle this case separately, and we can easily detect by checking if the vanishing poly is 0.
        let size = self.size();
        // TODO: Make this use the vanishing polynomial
        let z_h_at_tau = tau.pow(&[self.size]) - F::one();
        let domain_offset = F::one();
        if z_h_at_tau.is_zero() {
            // In this case, we know that tau = hg^i, for some value i.
            // Then i-th lagrange coefficient in this case is then simply 1,
            // and all other lagrange coefficients are 0.
            // Thus we find i by brute force.
            let mut u = vec![F::zero(); size];
            let mut omega_i = domain_offset;
            for u_i in u.iter_mut().take(size) {
                if omega_i == tau {
                    *u_i = F::one();
                    break;
                }
                omega_i *= &self.group_gen;
            }
            u
        } else {
            // In this case we have to compute `Z_H(tau) * v_i / (tau - h g^i)`
            // for i in 0..size
            // We actually compute this by computing (Z_H(tau) * v_i)^{-1} * (tau - h g^i)
            // and then batch inverting to get the correct lagrange coefficients.
            // We let `l_i = (Z_H(tau) * v_i)^-1` and `r_i = tau - h g^i`
            // Notice that since Z_H(tau) is i-independent,
            // and v_i = g * v_{i-1}, it follows that
            // l_i = g^-1 * l_{i-1}
            // TODO: consider caching the computation of l_i to save N multiplications
            use ark_ff::fields::batch_inversion;

            // v_0_inv = m * h^(m-1)
            let v_0_inv = F::from(self.size) * domain_offset.pow(&[self.size - 1]);
            let mut l_i = z_h_at_tau.inverse().unwrap() * v_0_inv;
            let mut negative_cur_elem = -domain_offset;
            let mut lagrange_coefficients_inverse = vec![F::zero(); size];
            for i in 0..size {
                let r_i = tau + negative_cur_elem;
                lagrange_coefficients_inverse[i] = l_i * r_i;
                // Increment l_i and negative_cur_elem
                l_i *= &self.group_gen_inv;
                negative_cur_elem *= &self.group_gen;
            }

            // Invert the lagrange coefficients inverse, to get the actual coefficients,
            // and return these
            batch_inversion(lagrange_coefficients_inverse.as_mut_slice());
            lagrange_coefficients_inverse
        }
    }

    fn vanishing_polynomial(&self) -> crate::univariate::SparsePolynomial<F> {
        let coeffs = vec![(0, -F::one()), (self.size(), F::one())];
        crate::univariate::SparsePolynomial::from_coefficients_vec(coeffs)
    }

    /// This evaluates the vanishing polynomial for this domain at tau.
    /// For multiplicative subgroups, this polynomial is `z(X) = X^self.size -
    /// 1`.
    fn evaluate_vanishing_polynomial(&self, tau: F) -> F {
        tau.pow(&[self.size]) - F::one()
    }

    /// Returns the `i`-th element of the domain, where elements are ordered by
    /// their power of the generator which they correspond to.
    /// e.g. the `i`-th element is g^i
    fn element(&self, i: usize) -> F {
        // TODO: Consider precomputed exponentiation tables if we need this to be faster.
        self.group_gen.pow(&[i as u64])
    }

    /// Return an iterator over the elements of the domain.
    fn elements(&self) -> Elements<F> {
        Elements {
            cur_elem: F::one(),
            cur_pow: 0,
            size: self.size,
            group_gen: self.group_gen,
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::domain::Vec;
    use crate::polynomial::{univariate::*, Polynomial, UVPolynomial};
    use crate::{EvaluationDomain, Radix2EvaluationDomain};
    use ark_ff::{FftField, Field, One, UniformRand, Zero};
    use ark_std::rand::Rng;
    use ark_std::test_rng;
    use ark_test_curves::bls12_381::Fr;

    #[test]
    fn vanishing_polynomial_evaluation() {
        let rng = &mut test_rng();
        for coeffs in 0..10 {
            let domain = Radix2EvaluationDomain::<Fr>::new(coeffs).unwrap();
            let z = domain.vanishing_polynomial();
            for _ in 0..100 {
                let point: Fr = rng.gen();
                assert_eq!(
                    z.evaluate(&point),
                    domain.evaluate_vanishing_polynomial(point)
                )
            }
        }
    }

    #[test]
    fn vanishing_polynomial_vanishes_on_domain() {
        for coeffs in 0..1000 {
            let domain = Radix2EvaluationDomain::<Fr>::new(coeffs).unwrap();
            let z = domain.vanishing_polynomial();
            for point in domain.elements() {
                assert!(z.evaluate(&point).is_zero())
            }
        }
    }

    #[test]
    fn size_of_elements() {
        for coeffs in 1..10 {
            let size = 1 << coeffs;
            let domain = Radix2EvaluationDomain::<Fr>::new(size).unwrap();
            let domain_size = domain.size();
            assert_eq!(domain_size, domain.elements().count());
        }
    }

    #[test]
    fn elements_contents() {
        for coeffs in 1..10 {
            let size = 1 << coeffs;
            let domain = Radix2EvaluationDomain::<Fr>::new(size).unwrap();
            for (i, element) in domain.elements().enumerate() {
                assert_eq!(element, domain.group_gen.pow([i as u64]));
            }
        }
    }

    /// Test that lagrange interpolation for a random polynomial at a random point works.
    #[test]
    fn non_systematic_lagrange_coefficients_test() {
        for domain_dim in 1..10 {
            let domain_size = 1 << domain_dim;
            let domain = Radix2EvaluationDomain::<Fr>::new(domain_size).unwrap();
            // Get random pt + lagrange coefficients
            let rand_pt = Fr::rand(&mut test_rng());
            let lagrange_coeffs = domain.evaluate_all_lagrange_coefficients(rand_pt);

            // Sample the random polynomial, evaluate it over the domain and the random point.
            let rand_poly = DensePolynomial::<Fr>::rand(domain_size - 1, &mut test_rng());
            let poly_evals = domain.fft(rand_poly.coeffs());
            let actual_eval = rand_poly.evaluate(&rand_pt);

            // Do lagrange interpolation, and compare against the actual evaluation
            let mut interpolated_eval = Fr::zero();
            for i in 0..domain_size {
                interpolated_eval += lagrange_coeffs[i] * poly_evals[i];
            }
            assert_eq!(actual_eval, interpolated_eval);
        }
    }

    /// Test that lagrange coefficients for a point in the domain is correct
    #[test]
    fn systematic_lagrange_coefficients_test() {
        // This runs in time O(N^2) in the domain size, so keep the domain dimension low.
        // We generate lagrange coefficients for each element in the domain.
        for domain_dim in 1..5 {
            let domain_size = 1 << domain_dim;
            let domain = Radix2EvaluationDomain::<Fr>::new(domain_size).unwrap();
            let all_domain_elements: Vec<Fr> = domain.elements().collect();
            for i in 0..domain_size {
                let lagrange_coeffs =
                    domain.evaluate_all_lagrange_coefficients(all_domain_elements[i]);
                for j in 0..domain_size {
                    // Lagrange coefficient for the evaluation point, which should be 1
                    if i == j {
                        assert_eq!(lagrange_coeffs[j], Fr::one());
                    } else {
                        assert_eq!(lagrange_coeffs[j], Fr::zero());
                    }
                }
            }
        }
    }

    #[test]
    fn test_fft_correctness() {
        // Tests that the ffts output the correct result.
        // This assumes a correct polynomial evaluation at point procedure.
        // It tests consistency of FFT/IFFT, and coset_fft/coset_ifft,
        // along with testing that each individual evaluation is correct.

        // Runs in time O(degree^2)
        let log_degree = 5;
        let degree = 1 << log_degree;
        let rand_poly = DensePolynomial::<Fr>::rand(degree - 1, &mut test_rng());

        for log_domain_size in log_degree..(log_degree + 2) {
            let domain_size = 1 << log_domain_size;
            let domain = Radix2EvaluationDomain::<Fr>::new(domain_size).unwrap();
            let poly_evals = domain.fft(&rand_poly.coeffs);
            let poly_coset_evals = domain.coset_fft(&rand_poly.coeffs);
            for (i, x) in domain.elements().enumerate() {
                let coset_x = Fr::multiplicative_generator() * x;

                assert_eq!(poly_evals[i], rand_poly.evaluate(&x));
                assert_eq!(poly_coset_evals[i], rand_poly.evaluate(&coset_x));
            }

            let rand_poly_from_subgroup =
                DensePolynomial::from_coefficients_vec(domain.ifft(&poly_evals));
            let rand_poly_from_coset =
                DensePolynomial::from_coefficients_vec(domain.coset_ifft(&poly_coset_evals));

            assert_eq!(
                rand_poly, rand_poly_from_subgroup,
                "degree = {}, domain size = {}",
                degree, domain_size
            );
            assert_eq!(
                rand_poly, rand_poly_from_coset,
                "degree = {}, domain size = {}",
                degree, domain_size
            );
        }
    }

    #[test]
    fn test_roots_of_unity() {
        // Tests that the roots of unity result is the same as domain.elements()
        let max_degree = 10;
        for log_domain_size in 0..max_degree {
            let domain_size = 1 << log_domain_size;
            let domain = Radix2EvaluationDomain::<Fr>::new(domain_size).unwrap();
            let actual_roots = domain.roots_of_unity(domain.group_gen);
            for &value in &actual_roots {
                assert!(domain.evaluate_vanishing_polynomial(value).is_zero());
            }
            let expected_roots_elements = domain.elements();
            for (expected, &actual) in expected_roots_elements.zip(&actual_roots) {
                assert_eq!(expected, actual);
            }
            assert_eq!(actual_roots.len(), domain_size / 2);
        }
    }

    #[test]
    #[cfg(feature = "parallel")]
    fn parallel_fft_consistency() {
        use ark_std::{test_rng, vec::Vec};
        use ark_test_curves::bls12_381::Fr;

        // This implements the Cooley-Turkey FFT, derived from libfqfft
        // The libfqfft implementation uses pseudocode from [CLRS 2n Ed, pp. 864].
        fn serial_radix2_fft(a: &mut [Fr], omega: Fr, log_n: u32) {
            use ark_std::convert::TryFrom;
            let n = u32::try_from(a.len())
                .expect("cannot perform FFTs larger on vectors of len > (1 << 32)");
            assert_eq!(n, 1 << log_n);

            // swap coefficients in place
            for k in 0..n {
                let rk = crate::domain::utils::bitreverse(k, log_n);
                if k < rk {
                    a.swap(rk as usize, k as usize);
                }
            }

            let mut m = 1;
            for _i in 1..=log_n {
                // w_m is 2^i-th root of unity
                let w_m = omega.pow(&[(n / (2 * m)) as u64]);

                let mut k = 0;
                while k < n {
                    // w = w_m^j at the start of every loop iteration
                    let mut w = Fr::one();
                    for j in 0..m {
                        let mut t = a[(k + j + m) as usize];
                        t *= w;
                        let mut tmp = a[(k + j) as usize];
                        tmp -= t;
                        a[(k + j + m) as usize] = tmp;
                        a[(k + j) as usize] += t;
                        w *= &w_m;
                    }

                    k += 2 * m;
                }

                m *= 2;
            }
        }

        fn serial_radix2_ifft(a: &mut [Fr], omega: Fr, log_n: u32) {
            serial_radix2_fft(a, omega.inverse().unwrap(), log_n);
            let domain_size_inv = Fr::from(a.len() as u64).inverse().unwrap();
            for coeff in a.iter_mut() {
                *coeff *= Fr::from(domain_size_inv);
            }
        }

        fn serial_radix2_coset_fft(a: &mut [Fr], omega: Fr, log_n: u32) {
            let coset_shift = Fr::multiplicative_generator();
            let mut cur_pow = Fr::one();
            for coeff in a.iter_mut() {
                *coeff *= cur_pow;
                cur_pow *= coset_shift;
            }
            serial_radix2_fft(a, omega, log_n);
        }

        fn serial_radix2_coset_ifft(a: &mut [Fr], omega: Fr, log_n: u32) {
            serial_radix2_ifft(a, omega, log_n);
            let coset_shift = Fr::multiplicative_generator().inverse().unwrap();
            let mut cur_pow = Fr::one();
            for coeff in a.iter_mut() {
                *coeff *= cur_pow;
                cur_pow *= coset_shift;
            }
        }

        fn test_consistency<R: Rng>(rng: &mut R, max_coeffs: u32) {
            for _ in 0..5 {
                for log_d in 0..max_coeffs {
                    let d = 1 << log_d;

                    let expected_poly = (0..d).map(|_| Fr::rand(rng)).collect::<Vec<_>>();
                    let mut expected_vec = expected_poly.clone();
                    let mut actual_vec = expected_vec.clone();

                    let domain = Radix2EvaluationDomain::new(d).unwrap();

                    serial_radix2_fft(&mut expected_vec, domain.group_gen, log_d);
                    domain.fft_in_place(&mut actual_vec);
                    assert_eq!(expected_vec, actual_vec);

                    serial_radix2_ifft(&mut expected_vec, domain.group_gen, log_d);
                    domain.ifft_in_place(&mut actual_vec);
                    assert_eq!(expected_vec, actual_vec);
                    assert_eq!(expected_vec, expected_poly);

                    serial_radix2_coset_fft(&mut expected_vec, domain.group_gen, log_d);
                    domain.coset_fft_in_place(&mut actual_vec);
                    assert_eq!(expected_vec, actual_vec);

                    serial_radix2_coset_ifft(&mut expected_vec, domain.group_gen, log_d);
                    domain.coset_ifft_in_place(&mut actual_vec);
                    assert_eq!(expected_vec, actual_vec);
                }
            }
        }

        let rng = &mut test_rng();

        test_consistency(rng, 10);
    }
}
