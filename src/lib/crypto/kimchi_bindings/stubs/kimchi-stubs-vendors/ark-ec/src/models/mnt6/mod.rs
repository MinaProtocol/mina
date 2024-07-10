use {
    crate::{
        models::{ModelParameters, SWModelParameters},
        PairingEngine,
    },
    ark_ff::{
        fp3::{Fp3, Fp3Parameters},
        fp6_2over3::{Fp6, Fp6Parameters},
        BitIteratorBE, Field, PrimeField, SquareRootField,
    },
    num_traits::{One, Zero},
};

use core::marker::PhantomData;

pub mod g1;
pub mod g2;

use self::g2::{AteAdditionCoefficients, AteDoubleCoefficients, G2ProjectiveExtended};
pub use self::{
    g1::{G1Affine, G1Prepared, G1Projective},
    g2::{G2Affine, G2Prepared, G2Projective},
};

pub type GT<P> = Fp6<P>;

pub trait MNT6Parameters: 'static {
    const TWIST: Fp3<Self::Fp3Params>;
    const TWIST_COEFF_A: Fp3<Self::Fp3Params>;
    const ATE_LOOP_COUNT: &'static [u64];
    const ATE_IS_LOOP_COUNT_NEG: bool;
    const FINAL_EXPONENT_LAST_CHUNK_1: <Self::Fp as PrimeField>::BigInt;
    const FINAL_EXPONENT_LAST_CHUNK_W0_IS_NEG: bool;
    const FINAL_EXPONENT_LAST_CHUNK_ABS_OF_W0: <Self::Fp as PrimeField>::BigInt;
    type Fp: PrimeField + SquareRootField + Into<<Self::Fp as PrimeField>::BigInt>;
    type Fr: PrimeField + SquareRootField + Into<<Self::Fr as PrimeField>::BigInt>;
    type Fp3Params: Fp3Parameters<Fp = Self::Fp>;
    type Fp6Params: Fp6Parameters<Fp3Params = Self::Fp3Params>;
    type G1Parameters: SWModelParameters<BaseField = Self::Fp, ScalarField = Self::Fr>;
    type G2Parameters: SWModelParameters<
        BaseField = Fp3<Self::Fp3Params>,
        ScalarField = <Self::G1Parameters as ModelParameters>::ScalarField,
    >;
}

#[derive(Derivative)]
#[derivative(Copy, Clone, PartialEq, Eq, Debug, Hash)]
pub struct MNT6<P: MNT6Parameters>(PhantomData<fn() -> P>);

impl<P: MNT6Parameters> MNT6<P> {
    fn doubling_step_for_flipped_miller_loop(
        r: &G2ProjectiveExtended<P>,
    ) -> (G2ProjectiveExtended<P>, AteDoubleCoefficients<P>) {
        let a = r.t.square();
        let b = r.x.square();
        let c = r.y.square();
        let d = c.square();
        let e = (r.x + &c).square() - &b - &d;
        let f = (b + &b + &b) + &(P::TWIST_COEFF_A * &a);
        let g = f.square();

        let d_eight = d.double().double().double();

        let e2 = e.double();
        let x = g - &e2.double();
        let y = -d_eight + &(f * &(e2 - &x));
        let z = (r.y + &r.z).square() - &c - &r.z.square();
        let t = z.square();

        let r2 = G2ProjectiveExtended { x, y, z, t };
        let coeff = AteDoubleCoefficients {
            c_h: (r2.z + &r.t).square() - &r2.t - &a,
            c_4c: c + &c + &c + &c,
            c_j: (f + &r.t).square() - &g - &a,
            c_l: (f + &r.x).square() - &g - &b,
        };

        (r2, coeff)
    }

    fn mixed_addition_step_for_flipped_miller_loop(
        x: &Fp3<P::Fp3Params>,
        y: &Fp3<P::Fp3Params>,
        r: &G2ProjectiveExtended<P>,
    ) -> (G2ProjectiveExtended<P>, AteAdditionCoefficients<P>) {
        let a = y.square();
        let b = r.t * x;
        let d = ((r.z + y).square() - &a - &r.t) * &r.t;
        let h = b - &r.x;
        let i = h.square();
        let e = i + &i + &i + &i;
        let j = h * &e;
        let v = r.x * &e;
        let ry2 = r.y.double();
        let l1 = d - &ry2;

        let x = l1.square() - &j - &(v + &v);
        let y = l1 * &(v - &x) - &(j * &ry2);
        let z = (r.z + &h).square() - &r.t - &i;
        let t = z.square();

        let r2 = G2ProjectiveExtended { x, y, z, t };
        let coeff = AteAdditionCoefficients { c_l1: l1, c_rz: z };

        (r2, coeff)
    }

    pub fn ate_miller_loop(p: &G1Prepared<P>, q: &G2Prepared<P>) -> Fp6<P::Fp6Params> {
        let l1_coeff = Fp3::new(p.x, P::Fp::zero(), P::Fp::zero()) - &q.x_over_twist;

        let mut f = <Fp6<P::Fp6Params>>::one();

        let mut add_idx: usize = 0;

        // code below gets executed for all bits (EXCEPT the MSB itself) of
        // mnt6_param_p (skipping leading zeros) in MSB to LSB order
        for (bit, dc) in BitIteratorBE::without_leading_zeros(P::ATE_LOOP_COUNT)
            .skip(1)
            .zip(&q.double_coefficients)
        {
            let g_rr_at_p = Fp6::new(
                dc.c_l - &dc.c_4c - &(dc.c_j * &p.x_twist),
                dc.c_h * &p.y_twist,
            );

            f = f.square() * &g_rr_at_p;

            if bit {
                let ac = &q.addition_coefficients[add_idx];
                add_idx += 1;

                let g_rq_at_p = Fp6::new(
                    ac.c_rz * &p.y_twist,
                    -(q.y_over_twist * &ac.c_rz + &(l1_coeff * &ac.c_l1)),
                );
                f *= &g_rq_at_p;
            }
        }

        if P::ATE_IS_LOOP_COUNT_NEG {
            let ac = &q.addition_coefficients[add_idx];

            let g_rnegr_at_p = Fp6::new(
                ac.c_rz * &p.y_twist,
                -(q.y_over_twist * &ac.c_rz + &(l1_coeff * &ac.c_l1)),
            );
            f = (f * &g_rnegr_at_p).inverse().unwrap();
        }

        f
    }

    pub fn final_exponentiation(value: &Fp6<P::Fp6Params>) -> GT<P::Fp6Params> {
        let value_inv = value.inverse().unwrap();
        let value_to_first_chunk = Self::final_exponentiation_first_chunk(value, &value_inv);
        let value_inv_to_first_chunk = Self::final_exponentiation_first_chunk(&value_inv, value);
        Self::final_exponentiation_last_chunk(&value_to_first_chunk, &value_inv_to_first_chunk)
    }

    fn final_exponentiation_first_chunk(
        elt: &Fp6<P::Fp6Params>,
        elt_inv: &Fp6<P::Fp6Params>,
    ) -> Fp6<P::Fp6Params> {
        // (q^3-1)*(q+1)

        // elt_q3 = elt^(q^3)
        let mut elt_q3 = *elt;
        elt_q3.conjugate();
        // elt_q3_over_elt = elt^(q^3-1)
        let elt_q3_over_elt = elt_q3 * elt_inv;
        // alpha = elt^((q^3-1) * q)
        let mut alpha = elt_q3_over_elt;
        alpha.frobenius_map(1);
        // beta = elt^((q^3-1)*(q+1)
        alpha * &elt_q3_over_elt
    }

    fn final_exponentiation_last_chunk(
        elt: &Fp6<P::Fp6Params>,
        elt_inv: &Fp6<P::Fp6Params>,
    ) -> Fp6<P::Fp6Params> {
        let elt_clone = *elt;
        let elt_inv_clone = *elt_inv;

        let mut elt_q = *elt;
        elt_q.frobenius_map(1);

        let w1_part = elt_q.cyclotomic_exp(&P::FINAL_EXPONENT_LAST_CHUNK_1);
        let w0_part = if P::FINAL_EXPONENT_LAST_CHUNK_W0_IS_NEG {
            elt_inv_clone.cyclotomic_exp(&P::FINAL_EXPONENT_LAST_CHUNK_ABS_OF_W0)
        } else {
            elt_clone.cyclotomic_exp(&P::FINAL_EXPONENT_LAST_CHUNK_ABS_OF_W0)
        };

        w1_part * &w0_part
    }
}

impl<P: MNT6Parameters> PairingEngine for MNT6<P> {
    type Fr = <P::G1Parameters as ModelParameters>::ScalarField;
    type G1Projective = G1Projective<P>;
    type G1Affine = G1Affine<P>;
    type G1Prepared = G1Prepared<P>;
    type G2Projective = G2Projective<P>;
    type G2Affine = G2Affine<P>;
    type G2Prepared = G2Prepared<P>;
    type Fq = P::Fp;
    type Fqe = Fp3<P::Fp3Params>;
    type Fqk = Fp6<P::Fp6Params>;

    fn miller_loop<'a, I>(i: I) -> Self::Fqk
    where
        I: IntoIterator<Item = &'a (Self::G1Prepared, Self::G2Prepared)>,
    {
        let mut result = Self::Fqk::one();
        for (p, q) in i {
            result *= &Self::ate_miller_loop(p, q);
        }
        result
    }

    fn final_exponentiation(r: &Self::Fqk) -> Option<Self::Fqk> {
        Some(Self::final_exponentiation(r))
    }
}
