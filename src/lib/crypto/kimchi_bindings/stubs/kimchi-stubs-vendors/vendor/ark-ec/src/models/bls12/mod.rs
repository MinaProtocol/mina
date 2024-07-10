use crate::{
    models::{ModelParameters, SWModelParameters},
    PairingEngine,
};
use ark_ff::fields::{
    fp12_2over3over2::{Fp12, Fp12Parameters},
    fp2::Fp2Parameters,
    fp6_3over2::Fp6Parameters,
    BitIteratorBE, Field, Fp2, PrimeField, SquareRootField,
};
use core::marker::PhantomData;
use num_traits::{One, Zero};

#[cfg(feature = "parallel")]
use ark_ff::{Fp12ParamsWrapper, Fp2ParamsWrapper, QuadExtField};
#[cfg(feature = "parallel")]
use ark_std::cfg_iter;
#[cfg(feature = "parallel")]
use core::slice::Iter;
#[cfg(feature = "parallel")]
use rayon::iter::{IndexedParallelIterator, IntoParallelRefIterator, ParallelIterator};

/// A particular BLS12 group can have G2 being either a multiplicative or a
/// divisive twist.
pub enum TwistType {
    M,
    D,
}

pub trait Bls12Parameters: 'static {
    /// Parameterizes the BLS12 family.
    const X: &'static [u64];
    /// Is `Self::X` negative?
    const X_IS_NEGATIVE: bool;
    /// What kind of twist is this?
    const TWIST_TYPE: TwistType;

    type Fp: PrimeField + SquareRootField + Into<<Self::Fp as PrimeField>::BigInt>;
    type Fp2Params: Fp2Parameters<Fp = Self::Fp>;
    type Fp6Params: Fp6Parameters<Fp2Params = Self::Fp2Params>;
    type Fp12Params: Fp12Parameters<Fp6Params = Self::Fp6Params>;
    type G1Parameters: SWModelParameters<BaseField = Self::Fp>;
    type G2Parameters: SWModelParameters<
        BaseField = Fp2<Self::Fp2Params>,
        ScalarField = <Self::G1Parameters as ModelParameters>::ScalarField,
    >;
}

pub mod g1;
pub mod g2;

pub use self::{
    g1::{G1Affine, G1Prepared, G1Projective},
    g2::{G2Affine, G2Prepared, G2Projective},
};

#[derive(Derivative)]
#[derivative(Copy, Clone, PartialEq, Eq, Debug, Hash)]
pub struct Bls12<P: Bls12Parameters>(PhantomData<fn() -> P>);

impl<P: Bls12Parameters> Bls12<P> {
    // Evaluate the line function at point p.
    fn ell(f: &mut Fp12<P::Fp12Params>, coeffs: &g2::EllCoeff<Fp2<P::Fp2Params>>, p: &G1Affine<P>) {
        let mut c0 = coeffs.0;
        let mut c1 = coeffs.1;
        let mut c2 = coeffs.2;

        match P::TWIST_TYPE {
            TwistType::M => {
                c2.mul_assign_by_fp(&p.y);
                c1.mul_assign_by_fp(&p.x);
                f.mul_by_014(&c0, &c1, &c2);
            }
            TwistType::D => {
                c0.mul_assign_by_fp(&p.y);
                c1.mul_assign_by_fp(&p.x);
                f.mul_by_034(&c0, &c1, &c2);
            }
        }
    }

    // Exponentiates `f` by `Self::X`, and stores the result in `result`.
    fn exp_by_x(f: &Fp12<P::Fp12Params>, result: &mut Fp12<P::Fp12Params>) {
        *result = f.cyclotomic_exp(P::X);
        if P::X_IS_NEGATIVE {
            result.conjugate();
        }
    }
}

impl<P: Bls12Parameters> PairingEngine for Bls12<P> {
    type Fr = <P::G1Parameters as ModelParameters>::ScalarField;
    type G1Projective = G1Projective<P>;
    type G1Affine = G1Affine<P>;
    type G1Prepared = G1Prepared<P>;
    type G2Projective = G2Projective<P>;
    type G2Affine = G2Affine<P>;
    type G2Prepared = G2Prepared<P>;
    type Fq = P::Fp;
    type Fqe = Fp2<P::Fp2Params>;
    type Fqk = Fp12<P::Fp12Params>;

    #[cfg(not(feature = "parallel"))]
    fn miller_loop<'a, I>(i: I) -> Self::Fqk
    where
        I: IntoIterator<Item = &'a (Self::G1Prepared, Self::G2Prepared)>,
    {
        let mut pairs = vec![];
        for (p, q) in i {
            if !p.is_zero() && !q.is_zero() {
                pairs.push((p, q.ell_coeffs.iter()));
            }
        }
        let mut f = Self::Fqk::one();
        for i in BitIteratorBE::new(P::X).skip(1) {
            f.square_in_place();
            for (p, ref mut coeffs) in &mut pairs {
                Self::ell(&mut f, coeffs.next().unwrap(), &p.0);
            }
            if i {
                for &mut (p, ref mut coeffs) in &mut pairs {
                    Self::ell(&mut f, coeffs.next().unwrap(), &p.0);
                }
            }
        }
        if P::X_IS_NEGATIVE {
            f.conjugate();
        }
        f
    }

    #[cfg(feature = "parallel")]
    fn miller_loop<'a, I>(i: I) -> Self::Fqk
    where
        I: IntoIterator<Item = &'a (Self::G1Prepared, Self::G2Prepared)>,
    {
        let mut pairs = vec![];
        for (p, q) in i {
            if !p.is_zero() && !q.is_zero() {
                pairs.push((p, q.ell_coeffs.iter()));
            }
        }

        let mut f_vec = vec![];
        for _ in 0..pairs.len() {
            f_vec.push(Self::Fqk::one());
        }

        let a = |p: &&G1Prepared<P>,
                 coeffs: &Iter<
            '_,
            (
                QuadExtField<Fp2ParamsWrapper<<P as Bls12Parameters>::Fp2Params>>,
                QuadExtField<Fp2ParamsWrapper<<P as Bls12Parameters>::Fp2Params>>,
                QuadExtField<Fp2ParamsWrapper<<P as Bls12Parameters>::Fp2Params>>,
            ),
        >,
                 mut f: QuadExtField<Fp12ParamsWrapper<<P as Bls12Parameters>::Fp12Params>>|
         -> QuadExtField<Fp12ParamsWrapper<<P as Bls12Parameters>::Fp12Params>> {
            let coeffs = coeffs.as_slice();
            let mut j = 0;
            for i in BitIteratorBE::new(P::X).skip(1) {
                f.square_in_place();
                Self::ell(&mut f, &coeffs[j], &p.0);
                j += 1;
                if i {
                    Self::ell(&mut f, &coeffs[j], &p.0);
                    j += 1;
                }
            }
            f
        };

        let mut products = vec![];
        cfg_iter!(pairs)
            .zip(f_vec)
            .map(|(p, f)| a(&p.0, &p.1, f))
            .collect_into_vec(&mut products);

        let mut f = Self::Fqk::one();
        for ff in products {
            f *= ff;
        }
        if P::X_IS_NEGATIVE {
            f.conjugate();
        }
        f
    }

    fn final_exponentiation(f: &Self::Fqk) -> Option<Self::Fqk> {
        // Computing the final exponentation following
        // https://eprint.iacr.org/2020/875
        // Adapted from the implementation in https://github.com/ConsenSys/gurvy/pull/29

        // f1 = r.conjugate() = f^(p^6)
        let mut f1 = *f;
        f1.conjugate();

        f.inverse().map(|mut f2| {
            // f2 = f^(-1);
            // r = f^(p^6 - 1)
            let mut r = f1 * &f2;

            // f2 = f^(p^6 - 1)
            f2 = r;
            // r = f^((p^6 - 1)(p^2))
            r.frobenius_map(2);

            // r = f^((p^6 - 1)(p^2) + (p^6 - 1))
            // r = f^((p^6 - 1)(p^2 + 1))
            r *= &f2;

            // Hard part of the final exponentation:
            // t[0].CyclotomicSquare(&result)
            let mut y0 = r.cyclotomic_square();
            // t[1].Expt(&result)
            let mut y1 = Fp12::zero();
            Self::exp_by_x(&r, &mut y1);
            // t[2].InverseUnitary(&result)
            let mut y2 = r;
            y2.conjugate();
            // t[1].Mul(&t[1], &t[2])
            y1 *= &y2;
            // t[2].Expt(&t[1])
            Self::exp_by_x(&y1, &mut y2);
            // t[1].InverseUnitary(&t[1])
            y1.conjugate();
            // t[1].Mul(&t[1], &t[2])
            y1 *= &y2;
            // t[2].Expt(&t[1])
            Self::exp_by_x(&y1, &mut y2);
            // t[1].Frobenius(&t[1])
            y1.frobenius_map(1);
            // t[1].Mul(&t[1], &t[2])
            y1 *= &y2;
            // result.Mul(&result, &t[0])
            r *= &y0;
            // t[0].Expt(&t[1])
            Self::exp_by_x(&y1, &mut y0);
            // t[2].Expt(&t[0])
            Self::exp_by_x(&y0, &mut y2);
            // t[0].FrobeniusSquare(&t[1])
            y0 = y1;
            y0.frobenius_map(2);
            // t[1].InverseUnitary(&t[1])
            y1.conjugate();
            // t[1].Mul(&t[1], &t[2])
            y1 *= &y2;
            // t[1].Mul(&t[1], &t[0])
            y1 *= &y0;
            // result.Mul(&result, &t[1])
            r *= &y1;
            r
        })
    }
}
