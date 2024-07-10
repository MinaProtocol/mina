use num::{FromPrimitive, Num, NumAssign, One, Signed, Zero};
use std::any::Any;
use std::fmt::{Debug, Display};
use std::ops::Neg;
use std::{f32, f64};

use crate::general::{Field, JoinSemilattice, MeetSemilattice, RealField, SubsetOf, SupersetOf};

#[cfg(not(feature = "std"))]
use num::Float;
//#[cfg(feature = "decimal")]
//use decimal::d128;

#[allow(missing_docs)]

/// Trait shared by all complex fields and its subfields (like real numbers).
///
/// Complex numbers are equipped with functions that are commonly used on complex numbers and reals.
/// The results of those functions only have to be approximately equal to the actual theoretical values.
// FIXME: SubsetOf should be removed when specialization will be supported by rustc. This will
// allow a blanket impl: impl<T: Clone> SubsetOf<T> for T { ... }
// NOTE: make all types debuggable/'static/Any ? This seems essential for any kind of generic programming.
pub trait ComplexField:
    SubsetOf<Self>
    + SupersetOf<f64>
    + Field
    + Copy
    + Num
    + NumAssign
    + FromPrimitive
    + Neg<Output = Self>
    + MeetSemilattice
    + JoinSemilattice
//    + RelativeEq<Epsilon = Self>
//    + UlpsEq<Epsilon = Self>
    + Send
    + Sync
    + Any
    + 'static
    + Debug
    + Display
{
    /// Type of the coefficients of a complex number.
    type RealField: RealField;

    /// Builds a pure-real complex number from the given value.
    fn from_real(re: Self::RealField) -> Self;

    /// The real part of this complex number.
    fn real(self) -> Self::RealField;

    /// The imaginary part of this complex number.
    fn imaginary(self) -> Self::RealField;

    /// The modulus of this complex number.
    fn modulus(self) -> Self::RealField;

    /// The squared modulus of this complex number.
    fn modulus_squared(self) -> Self::RealField;

    /// The argument of this complex number.
    fn argument(self) -> Self::RealField;

    /// The sum of the absolute value of this complex number's real and imaginary part.
    fn norm1(self) -> Self::RealField;

    /// Multiplies this complex number by `factor`.
    fn scale(self, factor: Self::RealField) -> Self;

    /// Divides this complex number by `factor`.
    fn unscale(self, factor: Self::RealField) -> Self;

    /// The polar form of this complex number: (modulus, arg)
    fn to_polar(self) -> (Self::RealField, Self::RealField) {
        (self.modulus(), self.argument())
    }

    /// The exponential form of this complex number: (modulus, e^{i arg})
    fn to_exp(self) -> (Self::RealField, Self) {
        let m = self.modulus();

        if !m.is_zero() {
            (m, self.unscale(m))
        } else {
            (Self::RealField::zero(), Self::one())
        }
    }

    /// The exponential part of this complex number: `self / self.modulus()`
    fn signum(self) -> Self {
        self.to_exp().1
    }


    fn floor(self) -> Self;
    fn ceil(self) -> Self;
    fn round(self) -> Self;
    fn trunc(self) -> Self;
    fn fract(self) -> Self;
    fn mul_add(self, a: Self, b: Self) -> Self;

    /// The absolute value of this complex number: `self / self.signum()`.
    ///
    /// This is equivalent to `self.modulus()`.
    fn abs(self) -> Self::RealField;

    /// Computes (self.conjugate() * self + other.conjugate() * other).sqrt()
    fn hypot(self, other: Self) -> Self::RealField;

    fn recip(self) -> Self;
    fn conjugate(self) -> Self;
    fn sin(self) -> Self;
    fn cos(self) -> Self;
    fn sin_cos(self) -> (Self, Self);
    #[inline]
    fn sinh_cosh(self) -> (Self, Self) {
        (self.sinh(), self.cosh())
    }
    fn tan(self) -> Self;
    fn asin(self) -> Self;
    fn acos(self) -> Self;
    fn atan(self) -> Self;
    fn sinh(self) -> Self;
    fn cosh(self) -> Self;
    fn tanh(self) -> Self;
    fn asinh(self) -> Self;
    fn acosh(self) -> Self;
    fn atanh(self) -> Self;

    fn is_finite(&self) -> bool;

    /// Cardinal sine
    #[inline]
    fn sinc(self) -> Self {
        if self.is_zero() {
            Self::one()
        } else {
            self.sin() / self
        }
    }

    #[inline]
    fn sinhc(self) -> Self {
        if self.is_zero() {
            Self::one()
        } else {
            self.sinh() / self
        }
    }

    /// Cardinal cos
    #[inline]
    fn cosc(self) -> Self {
        if self.is_zero() {
            Self::one()
        } else {
            self.cos() / self
        }
    }

    #[inline]
    fn coshc(self) -> Self {
        if self.is_zero() {
            Self::one()
        } else {
            self.cosh() / self
        }
    }

    fn log(self, base: Self::RealField) -> Self;
    fn log2(self) -> Self;
    fn log10(self) -> Self;
    fn ln(self) -> Self;
    fn ln_1p(self) -> Self;
    fn sqrt(self) -> Self;
    fn try_sqrt(self) -> Option<Self>;
    fn exp(self) -> Self;
    fn exp2(self) -> Self;
    fn exp_m1(self) -> Self;
    fn powi(self, n: i32) -> Self;
    fn powf(self, n: Self::RealField) -> Self;
    fn powc(self, n: Self) -> Self;
    fn cbrt(self) -> Self;
}

macro_rules! impl_complex(
    ($($T:ty, $M:ident, $libm: ident);*) => ($(
        impl ComplexField for $T {
            type RealField = $T;

            #[inline]
            fn from_real(re: Self::RealField) -> Self {
                re
            }

            #[inline]
            fn real(self) -> Self::RealField {
                self
            }

            #[inline]
            fn imaginary(self) -> Self::RealField {
                Self::zero()
            }

            #[inline]
            fn norm1(self) -> Self::RealField {
                $libm::abs(self)
            }

            #[inline]
            fn modulus(self) -> Self::RealField {
                $libm::abs(self)
            }

            #[inline]
            fn modulus_squared(self) -> Self::RealField {
                self * self
            }

            #[inline]
            fn argument(self) -> Self::RealField {
                if self >= Self::zero() {
                    Self::zero()
                } else {
                    Self::pi()
                }
            }

            #[inline]
            fn to_exp(self) -> (Self, Self) {
                if self >= Self::zero() {
                    (self, Self::one())
                } else {
                    (-self, -Self::one())
                }
            }

            #[inline]
            fn recip(self) -> Self {
                $M::recip(self)
            }

            #[inline]
            fn conjugate(self) -> Self {
                self
            }

            #[inline]
            fn scale(self, factor: Self::RealField) -> Self {
                self * factor
            }

            #[inline]
            fn unscale(self, factor: Self::RealField) -> Self {
                self / factor
            }

            #[inline]
            fn floor(self) -> Self {
                $libm::floor(self)
            }

            #[inline]
            fn ceil(self) -> Self {
                $libm::ceil(self)
            }

            #[inline]
            fn round(self) -> Self {
                $libm::round(self)
            }

            #[inline]
            fn trunc(self) -> Self {
                $libm::trunc(self)
            }

            #[inline]
            fn fract(self) -> Self {
                $libm::fract(self)
            }

            #[inline]
            fn abs(self) -> Self {
                $libm::abs(self)
            }

            #[inline]
            fn signum(self) -> Self {
                Signed::signum(&self)
            }

            #[inline]
            fn mul_add(self, a: Self, b: Self) -> Self {
                $libm::mul_add(self, a, b)
            }

            #[cfg(feature = "std")]
            #[inline]
            fn powi(self, n: i32) -> Self {
                self.powi(n)
            }

            #[cfg(not(feature = "std"))]
            #[inline]
            fn powi(self, n: i32) -> Self {
                // FIXME: is there a more accurate solution?
                $libm::powf(self, n as $T)
            }

            #[inline]
            fn powf(self, n: Self) -> Self {
                $libm::powf(self, n)
            }

            #[inline]
            fn powc(self, n: Self) -> Self {
                // Same as powf.
                $libm::powf(self, n)
            }

            #[inline]
            fn sqrt(self) -> Self {
                $libm::sqrt(self)
            }

            #[inline]
            fn try_sqrt(self) -> Option<Self> {
                if self >= Self::zero() {
                    Some($libm::sqrt(self))
                } else {
                    None
                }
            }

            #[inline]
            fn exp(self) -> Self {
                $libm::exp(self)
            }

            #[inline]
            fn exp2(self) -> Self {
                $libm::exp2(self)
            }


            #[inline]
            fn exp_m1(self) -> Self {
                $libm::exp_m1(self)
            }

            #[inline]
            fn ln_1p(self) -> Self {
                $libm::ln_1p(self)
            }

            #[inline]
            fn ln(self) -> Self {
                $libm::ln(self)
            }

            #[inline]
            fn log(self, base: Self) -> Self {
                $libm::log(self, base)
            }

            #[inline]
            fn log2(self) -> Self {
                $libm::log2(self)
            }

            #[inline]
            fn log10(self) -> Self {
                $libm::log10(self)
            }

            #[inline]
            fn cbrt(self) -> Self {
                $libm::cbrt(self)
            }

            #[inline]
            fn hypot(self, other: Self) -> Self::RealField {
                $libm::hypot(self, other)
            }

            #[inline]
            fn sin(self) -> Self {
                $libm::sin(self)
            }

            #[inline]
            fn cos(self) -> Self {
                $libm::cos(self)
            }

            #[inline]
            fn tan(self) -> Self {
                $libm::tan(self)
            }

            #[inline]
            fn asin(self) -> Self {
                $libm::asin(self)
            }

            #[inline]
            fn acos(self) -> Self {
                $libm::acos(self)
            }

            #[inline]
            fn atan(self) -> Self {
                $libm::atan(self)
            }

            #[inline]
            fn sin_cos(self) -> (Self, Self) {
                $libm::sin_cos(self)
            }

//            #[inline]
//            fn exp_m1(self) -> Self {
//                $libm::exp_m1(self)
//            }
//
//            #[inline]
//            fn ln_1p(self) -> Self {
//                $libm::ln_1p(self)
//            }
//
            #[inline]
            fn sinh(self) -> Self {
                $libm::sinh(self)
            }

            #[inline]
            fn cosh(self) -> Self {
                $libm::cosh(self)
            }

            #[inline]
            fn tanh(self) -> Self {
                $libm::tanh(self)
            }

            #[inline]
            fn asinh(self) -> Self {
                $libm::asinh(self)
            }

            #[inline]
            fn acosh(self) -> Self {
                $libm::acosh(self)
            }

            #[inline]
            fn atanh(self) -> Self {
                $libm::atanh(self)
            }

            #[inline]
            fn is_finite(&self) -> bool {
                $M::is_finite(*self)
            }
        }
    )*)
);

#[cfg(not(feature = "std"))]
impl_complex!(
    f32, f32, Float;
    f64, f64, Float
);

#[cfg(feature = "std")]
impl_complex!(
    f32,f32,f32;
    f64,f64,f64
);

//#[cfg(feature = "decimal")]
//impl_real!(d128, d128, d128);

impl<N: RealField> ComplexField for num_complex::Complex<N> {
    type RealField = N;

    #[inline]
    fn from_real(re: Self::RealField) -> Self {
        Self::new(re, Self::RealField::zero())
    }

    #[inline]
    fn real(self) -> Self::RealField {
        self.re
    }

    #[inline]
    fn imaginary(self) -> Self::RealField {
        self.im
    }

    #[inline]
    fn argument(self) -> Self::RealField {
        self.im.atan2(self.re)
    }

    #[inline]
    fn modulus(self) -> Self::RealField {
        self.re.hypot(self.im)
    }

    #[inline]
    fn modulus_squared(self) -> Self::RealField {
        self.re * self.re + self.im * self.im
    }

    #[inline]
    fn norm1(self) -> Self::RealField {
        self.re.abs() + self.im.abs()
    }

    #[inline]
    fn recip(self) -> Self {
        Self::one() / self
    }

    #[inline]
    fn conjugate(self) -> Self {
        self.conj()
    }

    #[inline]
    fn scale(self, factor: Self::RealField) -> Self {
        self * factor
    }

    #[inline]
    fn unscale(self, factor: Self::RealField) -> Self {
        self / factor
    }

    #[inline]
    fn floor(self) -> Self {
        Self::new(self.re.floor(), self.im.floor())
    }

    #[inline]
    fn ceil(self) -> Self {
        Self::new(self.re.ceil(), self.im.ceil())
    }

    #[inline]
    fn round(self) -> Self {
        Self::new(self.re.round(), self.im.round())
    }

    #[inline]
    fn trunc(self) -> Self {
        Self::new(self.re.trunc(), self.im.trunc())
    }

    #[inline]
    fn fract(self) -> Self {
        Self::new(self.re.fract(), self.im.fract())
    }

    #[inline]
    fn mul_add(self, a: Self, b: Self) -> Self {
        self * a + b
    }

    #[inline]
    fn abs(self) -> Self::RealField {
        self.modulus()
    }

    #[inline]
    fn exp2(self) -> Self {
        let _2 = N::one() + N::one();
        num_complex::Complex::new(_2, N::zero()).powc(self)
    }

    #[inline]
    fn exp_m1(self) -> Self {
        self.exp() - Self::one()
    }

    #[inline]
    fn ln_1p(self) -> Self {
        (Self::one() + self).ln()
    }

    #[inline]
    fn log2(self) -> Self {
        let _2 = N::one() + N::one();
        self.log(_2)
    }

    #[inline]
    fn log10(self) -> Self {
        let _10 = N::from_subset(&10.0f64);
        self.log(_10)
    }

    #[inline]
    fn cbrt(self) -> Self {
        let one_third = N::from_subset(&(1.0 / 3.0));
        self.powf(one_third)
    }

    #[inline]
    fn powi(self, n: i32) -> Self {
        // FIXME: is there a more accurate solution?
        let n = N::from_subset(&(n as f64));
        self.powf(n)
    }

    #[inline]
    fn is_finite(&self) -> bool {
        self.re.is_finite() && self.im.is_finite()
    }

    /*
     *
     *
     * Unfortunately we are forced to copy-paste all
     * those impls from https://github.com/rust-num/num-complex/blob/master/src/lib.rs
     * to avoid requiring `std`.
     *
     *
     */
    /// Computes `e^(self)`, where `e` is the base of the natural logarithm.
    #[inline]
    fn exp(self) -> Self {
        // formula: e^(a + bi) = e^a (cos(b) + i*sin(b))
        // = from_polar(e^a, b)
        complex_from_polar(self.re.exp(), self.im)
    }

    /// Computes the principal value of natural logarithm of `self`.
    ///
    /// This function has one branch cut:
    ///
    /// * `(-∞, 0]`, continuous from above.
    ///
    /// The branch satisfies `-π ≤ arg(ln(z)) ≤ π`.
    #[inline]
    fn ln(self) -> Self {
        // formula: ln(z) = ln|z| + i*arg(z)
        let (r, theta) = self.to_polar();
        Self::new(r.ln(), theta)
    }

    /// Computes the principal value of the square root of `self`.
    ///
    /// This function has one branch cut:
    ///
    /// * `(-∞, 0)`, continuous from above.
    ///
    /// The branch satisfies `-π/2 ≤ arg(sqrt(z)) ≤ π/2`.
    #[inline]
    fn sqrt(self) -> Self {
        // formula: sqrt(r e^(it)) = sqrt(r) e^(it/2)
        let two = N::one() + N::one();
        let (r, theta) = self.to_polar();
        complex_from_polar(r.sqrt(), theta / two)
    }

    #[inline]
    fn try_sqrt(self) -> Option<Self> {
        Some(self.sqrt())
    }

    #[inline]
    fn hypot(self, b: Self) -> Self::RealField {
        (self.modulus_squared() + b.modulus_squared()).sqrt()
    }

    /// Raises `self` to a floating point power.
    #[inline]
    fn powf(self, exp: Self::RealField) -> Self {
        // formula: x^y = (ρ e^(i θ))^y = ρ^y e^(i θ y)
        // = from_polar(ρ^y, θ y)
        let (r, theta) = self.to_polar();
        complex_from_polar(r.powf(exp), theta * exp)
    }

    /// Returns the logarithm of `self` with respect to an arbitrary base.
    #[inline]
    fn log(self, base: N) -> Self {
        // formula: log_y(x) = log_y(ρ e^(i θ))
        // = log_y(ρ) + log_y(e^(i θ)) = log_y(ρ) + ln(e^(i θ)) / ln(y)
        // = log_y(ρ) + i θ / ln(y)
        let (r, theta) = self.to_polar();
        Self::new(r.log(base), theta / base.ln())
    }

    /// Raises `self` to a complex power.
    #[inline]
    fn powc(self, exp: Self) -> Self {
        // formula: x^y = (a + i b)^(c + i d)
        // = (ρ e^(i θ))^c (ρ e^(i θ))^(i d)
        //    where ρ=|x| and θ=arg(x)
        // = ρ^c e^(−d θ) e^(i c θ) ρ^(i d)
        // = p^c e^(−d θ) (cos(c θ)
        //   + i sin(c θ)) (cos(d ln(ρ)) + i sin(d ln(ρ)))
        // = p^c e^(−d θ) (
        //   cos(c θ) cos(d ln(ρ)) − sin(c θ) sin(d ln(ρ))
        //   + i(cos(c θ) sin(d ln(ρ)) + sin(c θ) cos(d ln(ρ))))
        // = p^c e^(−d θ) (cos(c θ + d ln(ρ)) + i sin(c θ + d ln(ρ)))
        // = from_polar(p^c e^(−d θ), c θ + d ln(ρ))
        let (r, theta) = self.to_polar();
        complex_from_polar(
            r.powf(exp.re) * (-exp.im * theta).exp(),
            exp.re * theta + exp.im * r.ln(),
        )
    }

    /*
    /// Raises a floating point number to the complex power `self`.
    #[inline]
    fn expf(&self, base: T) -> Self {
        // formula: x^(a+bi) = x^a x^bi = x^a e^(b ln(x) i)
        // = from_polar(x^a, b ln(x))
        Self::from_polar(&base.powf(self.re), &(self.im * base.ln()))
    }
    */

    /// Computes the sine of `self`.
    #[inline]
    fn sin(self) -> Self {
        // formula: sin(a + bi) = sin(a)cosh(b) + i*cos(a)sinh(b)
        Self::new(
            self.re.sin() * self.im.cosh(),
            self.re.cos() * self.im.sinh(),
        )
    }

    /// Computes the cosine of `self`.
    #[inline]
    fn cos(self) -> Self {
        // formula: cos(a + bi) = cos(a)cosh(b) - i*sin(a)sinh(b)
        Self::new(
            self.re.cos() * self.im.cosh(),
            -self.re.sin() * self.im.sinh(),
        )
    }

    #[inline]
    fn sin_cos(self) -> (Self, Self) {
        let (rsin, rcos) = self.re.sin_cos();
        let (isinh, icosh) = self.im.sinh_cosh();
        let sin = Self::new(rsin * icosh, rcos * isinh);
        let cos = Self::new(rcos * icosh, -rsin * isinh);

        (sin, cos)
    }

    /// Computes the tangent of `self`.
    #[inline]
    fn tan(self) -> Self {
        // formula: tan(a + bi) = (sin(2a) + i*sinh(2b))/(cos(2a) + cosh(2b))
        let (two_re, two_im) = (self.re + self.re, self.im + self.im);
        Self::new(two_re.sin(), two_im.sinh()).unscale(two_re.cos() + two_im.cosh())
    }

    /// Computes the principal value of the inverse sine of `self`.
    ///
    /// This function has two branch cuts:
    ///
    /// * `(-∞, -1)`, continuous from above.
    /// * `(1, ∞)`, continuous from below.
    ///
    /// The branch satisfies `-π/2 ≤ Re(asin(z)) ≤ π/2`.
    #[inline]
    fn asin(self) -> Self {
        // formula: arcsin(z) = -i ln(sqrt(1-z^2) + iz)
        let i = Self::i();
        -i * ((Self::one() - self * self).sqrt() + i * self).ln()
    }

    /// Computes the principal value of the inverse cosine of `self`.
    ///
    /// This function has two branch cuts:
    ///
    /// * `(-∞, -1)`, continuous from above.
    /// * `(1, ∞)`, continuous from below.
    ///
    /// The branch satisfies `0 ≤ Re(acos(z)) ≤ π`.
    #[inline]
    fn acos(self) -> Self {
        // formula: arccos(z) = -i ln(i sqrt(1-z^2) + z)
        let i = Self::i();
        -i * (i * (Self::one() - self * self).sqrt() + self).ln()
    }

    /// Computes the principal value of the inverse tangent of `self`.
    ///
    /// This function has two branch cuts:
    ///
    /// * `(-∞i, -i]`, continuous from the left.
    /// * `[i, ∞i)`, continuous from the right.
    ///
    /// The branch satisfies `-π/2 ≤ Re(atan(z)) ≤ π/2`.
    #[inline]
    fn atan(self) -> Self {
        // formula: arctan(z) = (ln(1+iz) - ln(1-iz))/(2i)
        let i = Self::i();
        let one = Self::one();
        let two = one + one;

        if self == i {
            return Self::new(N::zero(), N::one() / N::zero());
        } else if self == -i {
            return Self::new(N::zero(), -N::one() / N::zero());
        }

        ((one + i * self).ln() - (one - i * self).ln()) / (two * i)
    }

    /// Computes the hyperbolic sine of `self`.
    #[inline]
    fn sinh(self) -> Self {
        // formula: sinh(a + bi) = sinh(a)cos(b) + i*cosh(a)sin(b)
        Self::new(
            self.re.sinh() * self.im.cos(),
            self.re.cosh() * self.im.sin(),
        )
    }

    /// Computes the hyperbolic cosine of `self`.
    #[inline]
    fn cosh(self) -> Self {
        // formula: cosh(a + bi) = cosh(a)cos(b) + i*sinh(a)sin(b)
        Self::new(
            self.re.cosh() * self.im.cos(),
            self.re.sinh() * self.im.sin(),
        )
    }

    #[inline]
    fn sinh_cosh(self) -> (Self, Self) {
        let (rsinh, rcosh) = self.re.sinh_cosh();
        let (isin, icos) = self.im.sin_cos();
        let sin = Self::new(rsinh * icos, rcosh * isin);
        let cos = Self::new(rcosh * icos, rsinh * isin);

        (sin, cos)
    }

    /// Computes the hyperbolic tangent of `self`.
    #[inline]
    fn tanh(self) -> Self {
        // formula: tanh(a + bi) = (sinh(2a) + i*sin(2b))/(cosh(2a) + cos(2b))
        let (two_re, two_im) = (self.re + self.re, self.im + self.im);
        Self::new(two_re.sinh(), two_im.sin()).unscale(two_re.cosh() + two_im.cos())
    }

    /// Computes the principal value of inverse hyperbolic sine of `self`.
    ///
    /// This function has two branch cuts:
    ///
    /// * `(-∞i, -i)`, continuous from the left.
    /// * `(i, ∞i)`, continuous from the right.
    ///
    /// The branch satisfies `-π/2 ≤ Im(asinh(z)) ≤ π/2`.
    #[inline]
    fn asinh(self) -> Self {
        // formula: arcsinh(z) = ln(z + sqrt(1+z^2))
        let one = Self::one();
        (self + (one + self * self).sqrt()).ln()
    }

    /// Computes the principal value of inverse hyperbolic cosine of `self`.
    ///
    /// This function has one branch cut:
    ///
    /// * `(-∞, 1)`, continuous from above.
    ///
    /// The branch satisfies `-π ≤ Im(acosh(z)) ≤ π` and `0 ≤ Re(acosh(z)) < ∞`.
    #[inline]
    fn acosh(self) -> Self {
        // formula: arccosh(z) = 2 ln(sqrt((z+1)/2) + sqrt((z-1)/2))
        let one = Self::one();
        let two = one + one;
        two * (((self + one) / two).sqrt() + ((self - one) / two).sqrt()).ln()
    }

    /// Computes the principal value of inverse hyperbolic tangent of `self`.
    ///
    /// This function has two branch cuts:
    ///
    /// * `(-∞, -1]`, continuous from above.
    /// * `[1, ∞)`, continuous from below.
    ///
    /// The branch satisfies `-π/2 ≤ Im(atanh(z)) ≤ π/2`.
    #[inline]
    fn atanh(self) -> Self {
        // formula: arctanh(z) = (ln(1+z) - ln(1-z))/2
        let one = Self::one();
        let two = one + one;
        if self == one {
            return Self::new(N::one() / N::zero(), N::zero());
        } else if self == -one {
            return Self::new(-N::one() / N::zero(), N::zero());
        }
        ((one + self).ln() - (one - self).ln()) / two
    }
}

#[inline]
fn complex_from_polar<N: RealField>(r: N, theta: N) -> num_complex::Complex<N> {
    num_complex::Complex::new(r * theta.cos(), r * theta.sin())
}
