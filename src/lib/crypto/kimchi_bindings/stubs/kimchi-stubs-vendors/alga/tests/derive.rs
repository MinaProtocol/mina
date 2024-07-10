extern crate alga;
#[macro_use]
extern crate alga_derive;
extern crate approx;
extern crate quickcheck;

use alga::general::{AbstractMagma, Additive, Identity, Multiplicative, TwoSidedInverse, Field};

use approx::{AbsDiffEq, RelativeEq, UlpsEq};

use quickcheck::{Arbitrary, Gen};
use num_traits::{Zero, One};
use std::ops::{Add, AddAssign, Sub, SubAssign, Neg, Mul, MulAssign, Div, DivAssign};

#[derive(Alga, Clone, PartialEq, Debug)]
#[alga_traits(Field(Additive, Multiplicative))]
#[alga_quickcheck]
struct W(f64);

fn test_trait_impl() {
    fn is_field<T: Field>() {}
    is_field::<W>();
}

impl AbsDiffEq for W {
    type Epsilon = W;
    fn default_epsilon() -> W {
        W(0.0000000001)
    }

    fn abs_diff_eq(&self, other: &W, epsilon: W) -> bool {
        self.0.abs_diff_eq(&other.0, epsilon.0)
    }
}

impl RelativeEq for W {
    fn default_max_relative() -> W {
        W(0.0000000001)
    }

    fn relative_eq(&self, other: &Self, epsilon: W, max_relative: W) -> bool {
        self.0.relative_eq(&other.0, epsilon.0, max_relative.0)
    }
}

impl UlpsEq for W {
    fn default_max_ulps() -> u32 {
        40
    }

    fn ulps_eq(&self, other: &Self, epsilon: W, max_ulps: u32) -> bool {
        self.0.ulps_eq(&other.0, epsilon.0, max_ulps)
    }
}

impl Arbitrary for W {
    fn arbitrary<G: Gen>(g: &mut G) -> Self {
        W(f64::arbitrary(g))
    }
    fn shrink(&self) -> Box<dyn Iterator<Item = Self>> {
        Box::new(self.0.shrink().map(W))
    }
}

impl AbstractMagma<Additive> for W {
    fn operate(&self, right: &Self) -> Self {
        W(self.0 + right.0)
    }
}
impl AbstractMagma<Multiplicative> for W {
    fn operate(&self, right: &Self) -> Self {
        W(self.0 * right.0)
    }
}

impl TwoSidedInverse<Additive> for W {
    fn two_sided_inverse(&self) -> Self {
        W(-self.0)
    }
}

impl TwoSidedInverse<Multiplicative> for W {
    fn two_sided_inverse(&self) -> Self {
        W(1. / self.0)
    }
}

impl Identity<Additive> for W {
    fn identity() -> Self {
        W(0.)
    }
}

impl Identity<Multiplicative> for W {
    fn identity() -> Self {
        W(1.)
    }
}

impl Add<W> for W {
    type Output = W;

    fn add(self, rhs: W) -> W {
        W(self.0 + rhs.0)
    }
}

impl Sub<W> for W {
    type Output = W;

    fn sub(self, rhs: W) -> W {
        W(self.0 - rhs.0)
    }
}

impl AddAssign<W> for W {
    fn add_assign(&mut self, rhs: W) {
        self.0 += rhs.0
    }
}

impl SubAssign<W> for W {
    fn sub_assign(&mut self, rhs: W) {
        self.0 -= rhs.0
    }
}

impl Neg for W {
    type Output = W;

    fn neg(self) -> W {
        W(-self.0)
    }
}

impl Zero for W {
    fn zero() -> W {
        W(0.0)
    }

    fn is_zero(&self) -> bool {
        self.0.is_zero()
    }
}

impl One for W {
    fn one() -> W {
        W(1.0)
    }
}

impl Mul<W> for W {
    type Output = W;

    fn mul(self, rhs: W) -> W {
        W(self.0 * rhs.0)
    }
}


impl Div<W> for W {
    type Output = W;

    fn div(self, rhs: W) -> W {
        W(self.0 / rhs.0)
    }
}

impl MulAssign<W> for W {
    fn mul_assign(&mut self, rhs: W) {
        self.0 *= rhs.0
    }
}


impl DivAssign<W> for W {
    fn div_assign(&mut self, rhs: W) {
        self.0 /= rhs.0
    }
}
