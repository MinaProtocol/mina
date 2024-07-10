use ark_std::{
    io::{Result as IoResult, Write},
    vec::Vec,
};

use ark_ff::{
    bytes::ToBytes,
    fields::{BitIteratorBE, Field, Fp2},
};

use num_traits::{One, Zero};

use crate::{
    bls12::{Bls12Parameters, TwistType},
    models::SWModelParameters,
    short_weierstrass_jacobian::{GroupAffine, GroupProjective},
    AffineCurve,
};

pub type G2Affine<P> = GroupAffine<<P as Bls12Parameters>::G2Parameters>;
pub type G2Projective<P> = GroupProjective<<P as Bls12Parameters>::G2Parameters>;

#[derive(Derivative)]
#[derivative(
    Clone(bound = "P: Bls12Parameters"),
    Debug(bound = "P: Bls12Parameters"),
    PartialEq(bound = "P: Bls12Parameters"),
    Eq(bound = "P: Bls12Parameters")
)]
pub struct G2Prepared<P: Bls12Parameters> {
    // Stores the coefficients of the line evaluations as calculated in
    // https://eprint.iacr.org/2013/722.pdf
    pub ell_coeffs: Vec<EllCoeff<Fp2<P::Fp2Params>>>,
    pub infinity: bool,
}

pub(crate) type EllCoeff<F> = (F, F, F);

#[derive(Derivative)]
#[derivative(
    Clone(bound = "P: Bls12Parameters"),
    Copy(bound = "P: Bls12Parameters"),
    Debug(bound = "P: Bls12Parameters")
)]
struct G2HomProjective<P: Bls12Parameters> {
    x: Fp2<P::Fp2Params>,
    y: Fp2<P::Fp2Params>,
    z: Fp2<P::Fp2Params>,
}

impl<P: Bls12Parameters> Default for G2Prepared<P> {
    fn default() -> Self {
        Self::from(G2Affine::<P>::prime_subgroup_generator())
    }
}

impl<P: Bls12Parameters> ToBytes for G2Prepared<P> {
    fn write<W: Write>(&self, mut writer: W) -> IoResult<()> {
        for coeff in &self.ell_coeffs {
            coeff.0.write(&mut writer)?;
            coeff.1.write(&mut writer)?;
            coeff.2.write(&mut writer)?;
        }
        self.infinity.write(writer)
    }
}

impl<P: Bls12Parameters> From<G2Affine<P>> for G2Prepared<P> {
    fn from(q: G2Affine<P>) -> Self {
        let two_inv = P::Fp::one().double().inverse().unwrap();
        if q.is_zero() {
            return Self {
                ell_coeffs: vec![],
                infinity: true,
            };
        }

        let mut ell_coeffs = vec![];
        let mut r = G2HomProjective {
            x: q.x,
            y: q.y,
            z: Fp2::one(),
        };

        for i in BitIteratorBE::new(P::X).skip(1) {
            ell_coeffs.push(doubling_step::<P>(&mut r, &two_inv));

            if i {
                ell_coeffs.push(addition_step::<P>(&mut r, &q));
            }
        }

        Self {
            ell_coeffs,
            infinity: false,
        }
    }
}
impl<P: Bls12Parameters> G2Prepared<P> {
    pub fn is_zero(&self) -> bool {
        self.infinity
    }
}

fn doubling_step<B: Bls12Parameters>(
    r: &mut G2HomProjective<B>,
    two_inv: &B::Fp,
) -> EllCoeff<Fp2<B::Fp2Params>> {
    // Formula for line function when working with
    // homogeneous projective coordinates.

    let mut a = r.x * &r.y;
    a.mul_assign_by_fp(two_inv);
    let b = r.y.square();
    let c = r.z.square();
    let e = B::G2Parameters::COEFF_B * &(c.double() + &c);
    let f = e.double() + &e;
    let mut g = b + &f;
    g.mul_assign_by_fp(two_inv);
    let h = (r.y + &r.z).square() - &(b + &c);
    let i = e - &b;
    let j = r.x.square();
    let e_square = e.square();

    r.x = a * &(b - &f);
    r.y = g.square() - &(e_square.double() + &e_square);
    r.z = b * &h;
    match B::TWIST_TYPE {
        TwistType::M => (i, j.double() + &j, -h),
        TwistType::D => (-h, j.double() + &j, i),
    }
}

fn addition_step<B: Bls12Parameters>(
    r: &mut G2HomProjective<B>,
    q: &G2Affine<B>,
) -> EllCoeff<Fp2<B::Fp2Params>> {
    // Formula for line function when working with
    // homogeneous projective coordinates.
    let theta = r.y - &(q.y * &r.z);
    let lambda = r.x - &(q.x * &r.z);
    let c = theta.square();
    let d = lambda.square();
    let e = lambda * &d;
    let f = r.z * &c;
    let g = r.x * &d;
    let h = e + &f - &g.double();
    r.x = lambda * &h;
    r.y = theta * &(g - &h) - &(e * &r.y);
    r.z *= &e;
    let j = theta * &q.x - &(lambda * &q.y);

    match B::TWIST_TYPE {
        TwistType::M => (j, -theta, lambda),
        TwistType::D => (lambda, -theta, j),
    }
}
