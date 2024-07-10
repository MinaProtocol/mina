extern crate alga;
#[macro_use]
extern crate alga_derive;
#[macro_use]
extern crate approx;
extern crate quickcheck;

use std::fmt::{Display, Error, Formatter};

use alga::general::wrapper::Wrapper as W;
use alga::general::*;

use approx::{AbsDiffEq, RelativeEq, UlpsEq};

use quickcheck::{Arbitrary, Gen};

#[derive(Alga, PartialEq, Clone, Debug)]
#[alga_traits(GroupAbelian(Additive), Where = "Scalar: AbstractField")]
#[alga_quickcheck(check(Rational))]
struct Vec2<Scalar> {
    x: Scalar,
    y: Scalar,
}

impl<Scalar: AbstractField + Arbitrary> Arbitrary for Vec2<Scalar> {
    fn arbitrary<G: Gen>(g: &mut G) -> Self {
        Vec2::new(Scalar::arbitrary(g), Scalar::arbitrary(g))
    }

    fn shrink(&self) -> Box<dyn Iterator<Item = Self>> {
        Box::new(
            self.x
                .shrink()
                .zip(self.y.shrink())
                .map(|(x, y)| Vec2::new(x, y)),
        )
    }
}

impl<Scalar: AbstractField> Vec2<Scalar> {
    fn new(x: Scalar, y: Scalar) -> Vec2<Scalar> {
        Vec2 { x: x, y: y }
    }
}

impl<Scalar: AbstractField + Display> Display for Vec2<Scalar> {
    fn fmt(&self, fmt: &mut Formatter) -> Result<(), Error> {
        fmt.write_fmt(format_args!("({}, {})", self.x, self.y))
    }
}

impl<Scalar: AbstractField + AbsDiffEq> AbsDiffEq for Vec2<Scalar>
where
    Scalar::Epsilon: Clone,
{
    type Epsilon = Scalar::Epsilon;

    fn default_epsilon() -> Self::Epsilon {
        Scalar::default_epsilon()
    }

    fn abs_diff_eq(&self, other: &Self, epsilon: Self::Epsilon) -> bool {
        self.x.abs_diff_eq(&other.x, epsilon.clone()) && self.y.abs_diff_eq(&other.y, epsilon)
    }
}

impl<Scalar: AbstractField + RelativeEq> RelativeEq for Vec2<Scalar>
where
    Scalar::Epsilon: Clone,
{
    fn default_max_relative() -> Self::Epsilon {
        Scalar::default_max_relative()
    }

    fn relative_eq(
        &self,
        other: &Self,
        epsilon: Self::Epsilon,
        max_relative: Self::Epsilon,
    ) -> bool {
        self.x
            .relative_eq(&other.x, epsilon.clone(), max_relative.clone())
            && self.y.relative_eq(&other.y, epsilon, max_relative)
    }
}

impl<Scalar: AbstractField + UlpsEq> UlpsEq for Vec2<Scalar>
where
    Scalar::Epsilon: Clone,
{
    fn default_max_ulps() -> u32 {
        Scalar::default_max_ulps()
    }

    fn ulps_eq(&self, other: &Self, epsilon: Self::Epsilon, max_ulps: u32) -> bool {
        self.x.ulps_eq(&other.x, epsilon.clone(), max_ulps)
            && self.y.ulps_eq(&other.y, epsilon, max_ulps)
    }
}

impl<Scalar: AbstractField> AbstractMagma<Additive> for Vec2<Scalar> {
    fn operate(&self, lhs: &Self) -> Self {
        Vec2::new(self.x.op(Additive, &lhs.x), self.y.op(Additive, &lhs.y))
    }
}

impl<Scalar: AbstractField> TwoSidedInverse<Additive> for Vec2<Scalar> {
    fn two_sided_inverse(&self) -> Self {
        Vec2::new(
            TwoSidedInverse::<Additive>::two_sided_inverse(&self.x),
            TwoSidedInverse::<Additive>::two_sided_inverse(&self.y),
        )
    }
}

impl<Scalar: AbstractField> Identity<Additive> for Vec2<Scalar> {
    fn identity() -> Self {
        Vec2 {
            x: Identity::<Additive>::identity(),
            y: Identity::<Additive>::identity(),
        }
    }
}

impl<Scalar: AbstractField> AbstractModule for Vec2<Scalar> {
    type AbstractRing = Scalar;
    fn multiply_by(&self, r: Self::AbstractRing) -> Self {
        self.op(Multiplicative, &Vec2::new(r.clone(), r))
    }
}

impl<Scalar: AbstractField> AbstractMagma<Multiplicative> for Vec2<Scalar> {
    fn operate(&self, lhs: &Self) -> Self {
        Vec2::new(
            self.x.op(Multiplicative, &lhs.x),
            self.y.op(Multiplicative, &lhs.y),
        )
    }
}

impl<Scalar: AbstractField> Identity<Multiplicative> for Vec2<Scalar> {
    fn identity() -> Self {
        Vec2 {
            x: Identity::<Multiplicative>::identity(),
            y: Identity::<Multiplicative>::identity(),
        }
    }
}

fn gcd<T: AbstractRingCommutative + PartialOrd>(a: T, b: T) -> T {
    let (mut a, mut b) = (W::<_, _, Multiplicative>::new(a), W::new(b));
    let zero = W::new(Identity::<Additive>::identity());
    if a < zero {
        a = -a;
    }
    if b < zero {
        b = -b;
    }
    if a == zero {
        if b == zero {
            return zero.val;
        }
        return b.val;
    }
    if b == zero {
        return a.val;
    }
    while a != b {
        if a > b {
            a = a - b.clone();
        } else {
            b = b - a.clone();
        }
    }
    a.val
}

#[test]
fn gcd_works() {
    assert_eq!(2, gcd(8, 6));
    assert_eq!(2, gcd(6, 8));
    assert_eq!(3, gcd(15, 6));
    assert_eq!(3, gcd(6, 15));
    assert_eq!(1, gcd(17, 12345));
    assert_eq!(1, gcd(42312, 17));
    assert_eq!(5, gcd(15, -35));
    assert_eq!(5, gcd(-15, 35));
    assert_eq!(5, gcd(-15, -35));
}

#[derive(Alga, Clone, Debug)]
#[alga_traits(Field(Additive, Multiplicative))]
#[alga_quickcheck]
struct Rational {
    a: i64,
    b: i64,
}

impl Arbitrary for Rational {
    fn arbitrary<G: Gen>(g: &mut G) -> Self {
        let mut div = 0;
        while div == 0 {
            div = i64::arbitrary(g);
        }
        Rational::new(i64::arbitrary(g), div)
    }

    fn shrink(&self) -> Box<dyn Iterator<Item = Self>> {
        RationalShrinker::new(self.clone())
    }
}

struct RationalShrinker {
    x: Rational,
    i: Rational,
}

impl RationalShrinker {
    pub fn new(x: Rational) -> Box<dyn Iterator<Item = Rational>> {
        if x.a == 0 {
            quickcheck::empty_shrinker()
        } else {
            let shrinker = RationalShrinker {
                x: x.clone(),
                i: Rational::new(x.a, x.b * 2),
            };
            let items = vec![Rational::new(0, 1)];
            Box::new(items.into_iter().chain(shrinker))
        }
    }
}

impl Iterator for RationalShrinker {
    type Item = Rational;
    fn next(&mut self) -> Option<Self::Item> {
        let next = Rational::new(
            (self.x.a * self.i.b) - (self.i.a * self.x.b),
            self.x.b * self.i.b,
        );
        if next.a * self.x.b < self.x.a * next.b {
            let result = Some(next);
            self.i = Rational::new(self.i.a, self.i.b * 2);
            result
        } else {
            None
        }
    }
}

impl Rational {
    fn new(mut a: i64, mut b: i64) -> Self {
        assert!(b != 0);
        if b < 0 {
            b = -b;
            a = -a;
        }
        if a == 0 {
            Rational::whole(0)
        } else {
            let gcd = gcd(a, b);
            Rational {
                a: a / gcd,
                b: b / gcd,
            }
        }
    }

    fn whole(n: i64) -> Self {
        Rational { a: n, b: 1 }
    }
}

impl Display for Rational {
    fn fmt(&self, fmt: &mut Formatter) -> Result<(), Error> {
        if self.b == 1 {
            fmt.write_fmt(format_args!("{}", self.a))
        } else {
            fmt.write_fmt(format_args!("{}⁄{}", self.a, self.b))
        }
    }
}

impl PartialEq for Rational {
    fn eq(&self, lhs: &Self) -> bool {
        self.a * lhs.b == lhs.a * self.b
    }
}

impl AbsDiffEq for Rational {
    type Epsilon = f64;

    fn default_epsilon() -> Self::Epsilon {
        ::std::f64::EPSILON
    }

    fn abs_diff_eq(&self, other: &Self, epsilon: f64) -> bool {
        let us = self.a as f64 / self.b as f64;
        let them = other.a as f64 / other.b as f64;
        us.abs_diff_eq(&them, epsilon)
    }
}

impl RelativeEq for Rational {
    fn default_max_relative() -> Self::Epsilon {
        ::std::f64::EPSILON
    }

    fn relative_eq(
        &self,
        other: &Self,
        epsilon: Self::Epsilon,
        max_relative: Self::Epsilon,
    ) -> bool {
        let us = self.a as f64 / self.b as f64;
        let them = other.a as f64 / other.b as f64;
        us.relative_eq(&them, epsilon, max_relative)
    }
}

impl UlpsEq for Rational {
    fn default_max_ulps() -> u32 {
        4
    }

    fn ulps_eq(&self, other: &Self, epsilon: Self::Epsilon, max_ulps: u32) -> bool {
        let us = self.a as f64 / self.b as f64;
        let them = other.a as f64 / other.b as f64;
        us.ulps_eq(&them, epsilon, max_ulps)
    }
}

impl AbstractMagma<Additive> for Rational {
    fn operate(&self, lhs: &Self) -> Self {
        let a = self.a * lhs.b + lhs.a * self.b;
        let b = self.b * lhs.b;
        let gcd = gcd(a, b);
        Rational::new(a / gcd, b / gcd)
    }
}

impl TwoSidedInverse<Additive> for Rational {
    fn two_sided_inverse(&self) -> Self {
        Rational::new(-self.a, self.b)
    }
}

impl Identity<Additive> for Rational {
    fn identity() -> Self {
        Rational::whole(0)
    }
}

impl AbstractMagma<Multiplicative> for Rational {
    fn operate(&self, lhs: &Self) -> Self {
        let a = self.a * lhs.a;
        let b = self.b * lhs.b;
        let gcd = gcd(a, b);
        Rational::new(a / gcd, b / gcd)
    }
}

impl TwoSidedInverse<Multiplicative> for Rational {
    fn two_sided_inverse(&self) -> Self {
        if self.a == 0 {
            self.clone()
        } else {
            Rational::new(self.b, self.a)
        }
    }
}

impl Identity<Multiplicative> for Rational {
    fn identity() -> Self {
        Rational::whole(1)
    }
}

fn main() {
    let vec = || {
        W::<_, Additive, Multiplicative>::new(Vec2::new(Rational::new(1, 2), Rational::whole(3)))
    };
    let vec2 = || W::new(Vec2::new(Rational::whole(5), Rational::new(11, 7)));
    let vec3 = || W::new(Vec2::new(Rational::new(7, 11), Rational::whole(17)));

    let vec4 = (vec() * vec2()) + (vec() * vec3());
    let vec5 = vec() * (vec2() + vec3());
    if relative_eq!(vec4, vec5) {
        println!("{} == {}", vec4, vec5);
    } else {
        println!("{} != {}", vec4, vec5);
    }
}
