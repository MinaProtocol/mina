//! This module contains a `GeneralEvaluationDomain` for
//! performing various kinds of polynomial arithmetic on top of
//! a FFT-friendly finite field.
//!
//! It is a wrapper around specific implementations of `EvaluationDomain` that
//! automatically chooses the most efficient implementation
//! depending on the number of coefficients and the two-adicity of the prime.

pub use crate::domain::utils::Elements;
use crate::domain::{
    DomainCoeff, EvaluationDomain, MixedRadixEvaluationDomain, Radix2EvaluationDomain,
};
use ark_ff::{FftField, FftParameters};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize, SerializationError};
use ark_std::{
    io::{Read, Write},
    vec::Vec,
};

/// Defines a domain over which finite field (I)FFTs can be performed.
/// Generally tries to build a radix-2 domain and falls back to a mixed-radix
/// domain if the radix-2 multiplicative subgroup is too small.
#[derive(Copy, Clone, Hash, Eq, PartialEq, Debug)]
pub enum GeneralEvaluationDomain<F: FftField> {
    /// Radix-2 domain
    Radix2(Radix2EvaluationDomain<F>),
    /// Mixed-radix domain
    MixedRadix(MixedRadixEvaluationDomain<F>),
}

macro_rules! map {
    ($self:expr, $f1:ident $(, $x:expr)*) => {
        match $self {
            Self::Radix2(domain) => EvaluationDomain::$f1(domain, $($x)*),
            Self::MixedRadix(domain) => EvaluationDomain::$f1(domain, $($x)*),
        }
    }
}

impl<F: FftField> CanonicalSerialize for GeneralEvaluationDomain<F> {
    fn serialize<W: Write>(&self, mut writer: W) -> Result<(), SerializationError> {
        let type_id = match self {
            GeneralEvaluationDomain::Radix2(_) => 0u8,
            GeneralEvaluationDomain::MixedRadix(_) => 1u8,
        };
        type_id.serialize(&mut writer)?;

        match self {
            GeneralEvaluationDomain::Radix2(domain) => domain.serialize(&mut writer),
            GeneralEvaluationDomain::MixedRadix(domain) => domain.serialize(&mut writer),
        }
    }

    fn serialized_size(&self) -> usize {
        let type_id = match self {
            GeneralEvaluationDomain::Radix2(_) => 0u8,
            GeneralEvaluationDomain::MixedRadix(_) => 1u8,
        };

        type_id.serialized_size()
            + match self {
                GeneralEvaluationDomain::Radix2(domain) => domain.serialized_size(),
                GeneralEvaluationDomain::MixedRadix(domain) => domain.serialized_size(),
            }
    }

    fn serialize_uncompressed<W: Write>(&self, mut writer: W) -> Result<(), SerializationError> {
        let type_id = match self {
            GeneralEvaluationDomain::Radix2(_) => 0u8,
            GeneralEvaluationDomain::MixedRadix(_) => 1u8,
        };
        type_id.serialize_uncompressed(&mut writer)?;

        match self {
            GeneralEvaluationDomain::Radix2(domain) => domain.serialize_uncompressed(&mut writer),
            GeneralEvaluationDomain::MixedRadix(domain) => {
                domain.serialize_uncompressed(&mut writer)
            }
        }
    }

    fn serialize_unchecked<W: Write>(&self, mut writer: W) -> Result<(), SerializationError> {
        let type_id = match self {
            GeneralEvaluationDomain::Radix2(_) => 0u8,
            GeneralEvaluationDomain::MixedRadix(_) => 1u8,
        };
        type_id.serialize_unchecked(&mut writer)?;

        match self {
            GeneralEvaluationDomain::Radix2(domain) => domain.serialize_unchecked(&mut writer),
            GeneralEvaluationDomain::MixedRadix(domain) => domain.serialize_unchecked(&mut writer),
        }
    }

    fn uncompressed_size(&self) -> usize {
        let type_id = match self {
            GeneralEvaluationDomain::Radix2(_) => 0u8,
            GeneralEvaluationDomain::MixedRadix(_) => 1u8,
        };

        type_id.uncompressed_size()
            + match self {
                GeneralEvaluationDomain::Radix2(domain) => domain.uncompressed_size(),
                GeneralEvaluationDomain::MixedRadix(domain) => domain.uncompressed_size(),
            }
    }
}

impl<F: FftField> CanonicalDeserialize for GeneralEvaluationDomain<F> {
    fn deserialize<R: Read>(mut reader: R) -> Result<Self, SerializationError> {
        let type_id = u8::deserialize(&mut reader)?;

        if type_id == 0u8 {
            Ok(Self::Radix2(Radix2EvaluationDomain::<F>::deserialize(
                &mut reader,
            )?))
        } else if type_id == 1u8 {
            Ok(Self::MixedRadix(
                MixedRadixEvaluationDomain::<F>::deserialize(&mut reader)?,
            ))
        } else {
            Err(SerializationError::InvalidData)
        }
    }

    fn deserialize_uncompressed<R: Read>(mut reader: R) -> Result<Self, SerializationError> {
        let type_id = u8::deserialize_uncompressed(&mut reader)?;

        if type_id == 0u8 {
            Ok(Self::Radix2(
                Radix2EvaluationDomain::<F>::deserialize_uncompressed(&mut reader)?,
            ))
        } else if type_id == 1u8 {
            Ok(Self::MixedRadix(
                MixedRadixEvaluationDomain::<F>::deserialize_uncompressed(&mut reader)?,
            ))
        } else {
            Err(SerializationError::InvalidData)
        }
    }

    fn deserialize_unchecked<R: Read>(mut reader: R) -> Result<Self, SerializationError> {
        let type_id = u8::deserialize_unchecked(&mut reader)?;

        if type_id == 0u8 {
            Ok(Self::Radix2(
                Radix2EvaluationDomain::<F>::deserialize_unchecked(&mut reader)?,
            ))
        } else if type_id == 1u8 {
            Ok(Self::MixedRadix(
                MixedRadixEvaluationDomain::<F>::deserialize_unchecked(&mut reader)?,
            ))
        } else {
            Err(SerializationError::InvalidData)
        }
    }
}

impl<F: FftField> EvaluationDomain<F> for GeneralEvaluationDomain<F> {
    type Elements = GeneralElements<F>;

    /// Construct a domain that is large enough for evaluations of a polynomial
    /// having `num_coeffs` coefficients.
    ///
    /// If the field specifies a small subgroup for a mixed-radix FFT and
    /// the radix-2 FFT cannot be constructed, this method tries
    /// constructing a mixed-radix FFT instead.
    fn new(num_coeffs: usize) -> Option<Self> {
        let domain = Radix2EvaluationDomain::new(num_coeffs);
        if let Some(domain) = domain {
            return Some(GeneralEvaluationDomain::Radix2(domain));
        }

        if F::FftParams::SMALL_SUBGROUP_BASE.is_some() {
            return Some(GeneralEvaluationDomain::MixedRadix(
                MixedRadixEvaluationDomain::new(num_coeffs)?,
            ));
        }

        None
    }

    fn compute_size_of_domain(num_coeffs: usize) -> Option<usize> {
        let domain_size = Radix2EvaluationDomain::<F>::compute_size_of_domain(num_coeffs);
        if let Some(domain_size) = domain_size {
            return Some(domain_size);
        }

        if F::FftParams::SMALL_SUBGROUP_BASE.is_some() {
            return Some(MixedRadixEvaluationDomain::<F>::compute_size_of_domain(
                num_coeffs,
            )?);
        }

        None
    }

    #[inline]
    fn size(&self) -> usize {
        map!(self, size)
    }

    #[inline]
    fn fft_in_place<T: DomainCoeff<F>>(&self, coeffs: &mut Vec<T>) {
        map!(self, fft_in_place, coeffs)
    }

    #[inline]
    fn ifft_in_place<T: DomainCoeff<F>>(&self, evals: &mut Vec<T>) {
        map!(self, ifft_in_place, evals)
    }

    #[inline]
    fn coset_fft_in_place<T: DomainCoeff<F>>(&self, coeffs: &mut Vec<T>) {
        map!(self, coset_fft_in_place, coeffs)
    }

    #[inline]
    fn coset_ifft_in_place<T: DomainCoeff<F>>(&self, evals: &mut Vec<T>) {
        map!(self, coset_ifft_in_place, evals)
    }

    #[inline]
    fn evaluate_all_lagrange_coefficients(&self, tau: F) -> Vec<F> {
        map!(self, evaluate_all_lagrange_coefficients, tau)
    }

    #[inline]
    fn vanishing_polynomial(&self) -> crate::univariate::SparsePolynomial<F> {
        map!(self, vanishing_polynomial)
    }

    #[inline]
    fn evaluate_vanishing_polynomial(&self, tau: F) -> F {
        map!(self, evaluate_vanishing_polynomial, tau)
    }

    /// Returns the `i`-th element of the domain.
    fn element(&self, i: usize) -> F {
        map!(self, element, i)
    }

    /// Return an iterator over the elements of the domain.
    fn elements(&self) -> GeneralElements<F> {
        GeneralElements(map!(self, elements))
    }
}

/// A generalized version of an iterator over the elements of a domain.
pub struct GeneralElements<F: FftField>(Elements<F>);

impl<F: FftField> Iterator for GeneralElements<F> {
    type Item = F;

    #[inline]
    fn next(&mut self) -> Option<F> {
        self.0.next()
    }
}

#[cfg(test)]
mod tests {
    use crate::polynomial::Polynomial;
    use crate::{EvaluationDomain, GeneralEvaluationDomain};
    use ark_ff::Zero;
    use ark_std::rand::Rng;
    use ark_std::test_rng;
    use ark_test_curves::bls12_381::Fr;
    use ark_test_curves::bn384_small_two_adicity::Fr as BNFr;

    #[test]
    fn vanishing_polynomial_evaluation() {
        let rng = &mut test_rng();
        for coeffs in 0..10 {
            let domain = GeneralEvaluationDomain::<Fr>::new(coeffs).unwrap();
            let z = domain.vanishing_polynomial();
            for _ in 0..100 {
                let point = rng.gen();
                assert_eq!(
                    z.evaluate(&point),
                    domain.evaluate_vanishing_polynomial(point)
                )
            }
        }

        for coeffs in 15..17 {
            let domain = GeneralEvaluationDomain::<BNFr>::new(coeffs).unwrap();
            let z = domain.vanishing_polynomial();
            for _ in 0..100 {
                let point = rng.gen();
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
            let domain = GeneralEvaluationDomain::<Fr>::new(coeffs).unwrap();
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
            let domain = GeneralEvaluationDomain::<Fr>::new(size).unwrap();
            let domain_size = domain.size();
            assert_eq!(domain_size, domain.elements().count());
        }
    }
}
