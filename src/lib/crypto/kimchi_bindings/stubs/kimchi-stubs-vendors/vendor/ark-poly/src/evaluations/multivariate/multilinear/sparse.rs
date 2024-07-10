//! multilinear polynomial represented in sparse evaluation form.

use crate::evaluations::multivariate::multilinear::swap_bits;
use crate::{DenseMultilinearExtension, MultilinearExtension};
use ark_ff::{Field, Zero};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize, Read, SerializationError, Write};
use ark_std::collections::BTreeMap;
use ark_std::fmt::{Debug, Formatter};
use ark_std::iter::FromIterator;
use ark_std::ops::{Add, AddAssign, Index, Neg, Sub, SubAssign};
use ark_std::rand::Rng;
use ark_std::vec::Vec;
use ark_std::{fmt, UniformRand};
use hashbrown::HashMap;
#[cfg(feature = "parallel")]
use rayon::prelude::*;

/// Stores a multilinear polynomial in sparse evaluation form.
#[derive(Clone, PartialEq, Eq, Hash, Default, CanonicalSerialize, CanonicalDeserialize)]
pub struct SparseMultilinearExtension<F: Field> {
    /// tuples of index and value
    pub evaluations: BTreeMap<usize, F>,
    /// number of variables
    pub num_vars: usize,
    zero: F,
}

impl<F: Field> SparseMultilinearExtension<F> {
    pub fn from_evaluations<'a>(
        num_vars: usize,
        evaluations: impl IntoIterator<Item = &'a (usize, F)>,
    ) -> Self {
        let bit_mask = 1 << num_vars;
        // check
        let evaluations = evaluations.into_iter();
        let evaluations: Vec<_> = evaluations
            .map(|(i, v): &(usize, F)| {
                assert!(*i < bit_mask, "index out of range");
                (*i, *v)
            })
            .collect();

        Self {
            evaluations: tuples_to_treemap(&evaluations),
            num_vars,
            zero: F::zero(),
        }
    }

    /// Outputs an `l`-variate multilinear extension where value of evaluations are sampled uniformly at random.
    /// The number of nonzero entries is `num_nonzero_entries` and indices of those nonzero entries are distributed uniformly at random.
    ///
    /// Note that this function uses rejection sampling. As number of nonzero entries approach `2 ^ num_vars`,
    /// sampling will be very slow due to large number of collisions.
    pub fn rand_with_config<R: Rng>(
        num_vars: usize,
        num_nonzero_entries: usize,
        rng: &mut R,
    ) -> Self {
        assert!(num_nonzero_entries <= (1 << num_vars));

        let mut map = HashMap::new();
        for _ in 0..num_nonzero_entries {
            let mut index = usize::rand(rng) & ((1 << num_vars) - 1);
            while let Some(_) = map.get(&index) {
                index = usize::rand(rng) & ((1 << num_vars) - 1);
            }
            map.entry(index).or_insert(F::rand(rng));
        }
        let mut buf = Vec::new();
        for (arg, v) in map.iter() {
            if *v != F::zero() {
                buf.push((*arg, *v));
            }
        }
        let evaluations = hashmap_to_treemap(&map);
        Self {
            num_vars,
            evaluations,
            zero: F::zero(),
        }
    }

    /// Convert the sparse multilinear polynomial to dense form.
    pub fn to_dense_multilinear_extension(&self) -> DenseMultilinearExtension<F> {
        let mut evaluations: Vec<_> = (0..(1 << self.num_vars)).map(|_| F::zero()).collect();
        for (&i, &v) in self.evaluations.iter() {
            evaluations[i] = v;
        }
        DenseMultilinearExtension::from_evaluations_vec(self.num_vars, evaluations)
    }
}

/// utility: precompute f(x) = eq(g,x)
fn precompute_eq<F: Field>(g: &[F]) -> Vec<F> {
    let dim = g.len();
    let mut dp = Vec::with_capacity(1 << dim);
    dp.resize(1 << dim, F::zero());
    dp[0] = F::one() - g[0];
    dp[1] = g[0];
    for i in 1..dim {
        let dp_prev = (&dp[0..(1 << i)]).to_vec();
        for b in 0..(1 << i) {
            dp[b] = dp_prev[b] * (F::one() - g[i]);
            dp[b + (1 << i)] = dp_prev[b] * g[i];
        }
    }
    dp
}

impl<F: Field> MultilinearExtension<F> for SparseMultilinearExtension<F> {
    fn num_vars(&self) -> usize {
        self.num_vars
    }

    fn evaluate(&self, point: &[F]) -> Option<F> {
        if point.len() == self.num_vars {
            Some(self.fix_variables(&point)[0])
        } else {
            None
        }
    }

    /// Outputs an `l`-variate multilinear extension where value of evaluations are sampled uniformly at random.
    /// The number of nonzero entries is `sqrt(2^num_vars)` and indices of those nonzero entries are distributed uniformly at random.
    fn rand<R: Rng>(num_vars: usize, rng: &mut R) -> Self {
        Self::rand_with_config(num_vars, 1 << (num_vars / 2), rng)
    }

    fn relabel(&self, mut a: usize, mut b: usize, k: usize) -> Self {
        if a > b {
            // swap
            let t = a;
            a = b;
            b = t;
        }
        // sanity check
        assert!(
            a + k < self.num_vars && b + k < self.num_vars,
            "invalid relabel argument"
        );
        if a == b || k == 0 {
            return self.clone();
        }
        assert!(a + k <= b, "overlapped swap window is not allowed");
        let ev: Vec<_> = cfg_iter!(self.evaluations)
            .map(|(&i, &v)| (swap_bits(i, a, b, k), v))
            .collect();
        Self {
            num_vars: self.num_vars,
            evaluations: tuples_to_treemap(&ev),
            zero: F::zero(),
        }
    }

    fn fix_variables(&self, partial_point: &[F]) -> Self {
        let dim = partial_point.len();
        assert!(dim <= self.num_vars, "invalid partial point dimension");

        let window = ark_std::log2(self.evaluations.len()) as usize;
        let mut point = partial_point;
        let mut last = treemap_to_hashmap(&self.evaluations);

        // batch evaluation
        while !point.is_empty() {
            let focus_length = if window > 0 && point.len() > window {
                window
            } else {
                point.len()
            };
            let focus = &point[..focus_length];
            point = &point[focus_length..];
            let pre = precompute_eq(focus);
            let dim = focus.len();
            let mut result = HashMap::new();
            for src_entry in last.iter() {
                let old_idx = *src_entry.0;
                let gz = pre[old_idx & ((1 << dim) - 1)];
                let new_idx = old_idx >> dim;
                let dst_entry = result.entry(new_idx).or_insert(F::zero());
                *dst_entry += gz * src_entry.1;
            }
            last = result;
        }
        let evaluations = hashmap_to_treemap(&last);
        Self {
            num_vars: self.num_vars - dim,
            evaluations,
            zero: F::zero(),
        }
    }

    fn to_evaluations(&self) -> Vec<F> {
        let mut evaluations: Vec<_> = (0..1 << self.num_vars).map(|_| F::zero()).collect();
        self.evaluations
            .iter()
            .map(|(&i, &v)| evaluations[i] = v)
            .last();
        evaluations
    }
}

impl<F: Field> Index<usize> for SparseMultilinearExtension<F> {
    type Output = F;

    /// Returns the evaluation of the polynomial at a point represented by index.
    ///
    /// Index represents a vector in {0,1}^`num_vars` in little endian form. For example, `0b1011` represents `P(1,1,0,1)`
    ///
    /// For Sparse multilinear polynomial, Lookup_evaluation takes log time to the size of polynomial.
    fn index(&self, index: usize) -> &Self::Output {
        if let Some(v) = self.evaluations.get(&index) {
            v
        } else {
            &self.zero
        }
    }
}

impl<F: Field> Add for SparseMultilinearExtension<F> {
    type Output = SparseMultilinearExtension<F>;

    fn add(self, other: SparseMultilinearExtension<F>) -> Self {
        &self + &other
    }
}

impl<'a, 'b, F: Field> Add<&'a SparseMultilinearExtension<F>>
    for &'b SparseMultilinearExtension<F>
{
    type Output = SparseMultilinearExtension<F>;

    fn add(self, rhs: &'a SparseMultilinearExtension<F>) -> Self::Output {
        // handle zero case
        if self.is_zero() {
            return rhs.clone();
        }
        if rhs.is_zero() {
            return self.clone();
        }

        assert_eq!(
            rhs.num_vars, self.num_vars,
            "trying to add non-zero polynomial with different number of variables"
        );
        // simply merge the evaluations
        let mut evaluations = HashMap::new();
        for (&i, &v) in self.evaluations.iter().chain(rhs.evaluations.iter()) {
            *(evaluations.entry(i).or_insert(F::zero())) += v;
        }
        let evaluations: Vec<_> = evaluations
            .into_iter()
            .filter(|(_, v)| !v.is_zero())
            .collect();

        Self::Output {
            evaluations: tuples_to_treemap(&evaluations),
            num_vars: self.num_vars,
            zero: F::zero(),
        }
    }
}

impl<F: Field> AddAssign for SparseMultilinearExtension<F> {
    fn add_assign(&mut self, other: Self) {
        *self = &*self + &other;
    }
}

impl<'a, 'b, F: Field> AddAssign<&'a SparseMultilinearExtension<F>>
    for SparseMultilinearExtension<F>
{
    fn add_assign(&mut self, other: &'a SparseMultilinearExtension<F>) {
        *self = &*self + other;
    }
}

impl<'a, 'b, F: Field> AddAssign<(F, &'a SparseMultilinearExtension<F>)>
    for SparseMultilinearExtension<F>
{
    fn add_assign(&mut self, (f, other): (F, &'a SparseMultilinearExtension<F>)) {
        if !self.is_zero() && !other.is_zero() {
            assert_eq!(
                other.num_vars, self.num_vars,
                "trying to add non-zero polynomial with different number of variables"
            );
        }
        let ev: Vec<_> = cfg_iter!(other.evaluations)
            .map(|(i, v)| (*i, f * v))
            .collect();
        let other = Self {
            num_vars: other.num_vars,
            evaluations: tuples_to_treemap(&ev),
            zero: F::zero(),
        };
        *self += &other;
    }
}

impl<F: Field> Neg for SparseMultilinearExtension<F> {
    type Output = SparseMultilinearExtension<F>;

    fn neg(self) -> Self::Output {
        let ev: Vec<_> = cfg_iter!(self.evaluations)
            .map(|(i, v)| (*i, -*v))
            .collect();
        Self::Output {
            num_vars: self.num_vars,
            evaluations: tuples_to_treemap(&ev),
            zero: F::zero(),
        }
    }
}

impl<F: Field> Sub for SparseMultilinearExtension<F> {
    type Output = SparseMultilinearExtension<F>;

    fn sub(self, other: SparseMultilinearExtension<F>) -> Self {
        &self - &other
    }
}

impl<'a, 'b, F: Field> Sub<&'a SparseMultilinearExtension<F>>
    for &'b SparseMultilinearExtension<F>
{
    type Output = SparseMultilinearExtension<F>;

    fn sub(self, rhs: &'a SparseMultilinearExtension<F>) -> Self::Output {
        self + &rhs.clone().neg()
    }
}

impl<F: Field> SubAssign for SparseMultilinearExtension<F> {
    fn sub_assign(&mut self, other: Self) {
        *self = &*self - &other;
    }
}

impl<'a, 'b, F: Field> SubAssign<&'a SparseMultilinearExtension<F>>
    for SparseMultilinearExtension<F>
{
    fn sub_assign(&mut self, other: &'a SparseMultilinearExtension<F>) {
        *self = &*self - other;
    }
}

impl<F: Field> Zero for SparseMultilinearExtension<F> {
    fn zero() -> Self {
        Self {
            num_vars: 0,
            evaluations: tuples_to_treemap(&Vec::new()),
            zero: F::zero(),
        }
    }

    fn is_zero(&self) -> bool {
        self.num_vars == 0 && self.evaluations.is_empty()
    }
}

impl<F: Field> Debug for SparseMultilinearExtension<F> {
    fn fmt(&self, f: &mut Formatter<'_>) -> Result<(), fmt::Error> {
        write!(
            f,
            "SparseMultilinearPolynomial(num_vars = {}, evaluations = [",
            self.num_vars
        )?;
        let mut ev_iter = self.evaluations.iter();
        for _ in 0..ark_std::cmp::min(8, self.evaluations.len()) {
            write!(f, "{:?}", ev_iter.next())?;
        }
        if self.evaluations.len() > 8 {
            write!(f, "...")?;
        }
        write!(f, "])")?;
        Ok(())
    }
}

/// Utility: Convert tuples to hashmap.
fn tuples_to_treemap<F: Field>(tuples: &[(usize, F)]) -> BTreeMap<usize, F> {
    BTreeMap::from_iter(tuples.iter().map(|(i, v)| (*i, *v)))
}

fn treemap_to_hashmap<F: Field>(map: &BTreeMap<usize, F>) -> HashMap<usize, F> {
    HashMap::from_iter(map.iter().map(|(i, v)| (*i, *v)))
}

fn hashmap_to_treemap<F: Field>(map: &HashMap<usize, F>) -> BTreeMap<usize, F> {
    BTreeMap::from_iter(map.iter().map(|(i, v)| (*i, *v)))
}

#[cfg(test)]
mod tests {
    use crate::evaluations::multivariate::multilinear::MultilinearExtension;
    use crate::SparseMultilinearExtension;
    use ark_ff::{One, Zero};
    use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
    use ark_std::ops::Neg;
    use ark_std::vec::Vec;
    use ark_std::{test_rng, UniformRand};
    use ark_test_curves::bls12_381::Fr;
    /// Some sanity test to ensure random sparse polynomial make sense.
    #[test]
    fn random_poly() {
        const NV: usize = 16;

        let mut rng = test_rng();
        // two random poly should be different
        let poly1 = SparseMultilinearExtension::<Fr>::rand(NV, &mut rng);
        let poly2 = SparseMultilinearExtension::<Fr>::rand(NV, &mut rng);
        assert_ne!(poly1, poly2);
        // test sparsity
        assert!(
            ((1 << (NV / 2)) >> 1) <= poly1.evaluations.len()
                && poly1.evaluations.len() <= ((1 << (NV / 2)) << 1),
            "polynomial size out of range: expected: [{},{}] ,actual: {}",
            ((1 << (NV / 2)) >> 1),
            ((1 << (NV / 2)) << 1),
            poly1.evaluations.len()
        );
    }

    #[test]
    /// Test if sparse multilinear polynomial evaluates correctly.
    /// This function assumes dense multilinear polynomial functions correctly.
    fn evaluate() {
        const NV: usize = 12;
        let mut rng = test_rng();
        for _ in 0..20 {
            let sparse = SparseMultilinearExtension::<Fr>::rand(NV, &mut rng);
            let dense = sparse.to_dense_multilinear_extension();
            let point: Vec<_> = (0..NV).map(|_| Fr::rand(&mut rng)).collect();
            assert_eq!(sparse.evaluate(&point), dense.evaluate(&point));
            let sparse_partial = sparse.fix_variables(&point[..3].to_vec());
            let dense_partial = dense.fix_variables(&point[..3].to_vec());
            let point2: Vec<_> = (0..(NV - 3)).map(|_| Fr::rand(&mut rng)).collect();
            assert_eq!(
                sparse_partial.evaluate(&point2),
                dense_partial.evaluate(&point2)
            );
        }
    }

    #[test]
    fn evaluate_edge_cases() {
        // test constant polynomial
        let mut rng = test_rng();
        let ev1 = Fr::rand(&mut rng);
        let poly1 = SparseMultilinearExtension::from_evaluations(0, &vec![(0, ev1)]);
        assert_eq!(poly1.evaluate(&vec![]).unwrap(), ev1);

        // test single-variate polynomial
        let ev2 = vec![Fr::rand(&mut rng), Fr::rand(&mut rng)];
        let poly2 =
            SparseMultilinearExtension::from_evaluations(1, &vec![(0, ev2[0]), (1, ev2[1])]);

        let x = Fr::rand(&mut rng);
        assert_eq!(
            poly2.evaluate(&vec![x]).unwrap(),
            x * ev2[1] + (Fr::one() - x) * ev2[0]
        );

        // test single-variate polynomial with one entry missing
        let ev3 = Fr::rand(&mut rng);
        let poly2 = SparseMultilinearExtension::from_evaluations(1, &vec![(1, ev3)]);

        let x = Fr::rand(&mut rng);
        assert_eq!(poly2.evaluate(&vec![x]).unwrap(), x * ev3);
    }

    #[test]
    fn index() {
        let mut rng = test_rng();
        let points = vec![
            (11, Fr::rand(&mut rng)),
            (117, Fr::rand(&mut rng)),
            (213, Fr::rand(&mut rng)),
            (255, Fr::rand(&mut rng)),
        ];
        let poly = SparseMultilinearExtension::from_evaluations(8, &points);
        points
            .into_iter()
            .map(|(i, v)| assert_eq!(poly[i], v))
            .last();
        assert_eq!(poly[0], Fr::zero());
        assert_eq!(poly[1], Fr::zero());
    }

    #[test]
    fn arithmetic() {
        const NV: usize = 18;
        let mut rng = test_rng();
        for _ in 0..20 {
            let point: Vec<_> = (0..NV).map(|_| Fr::rand(&mut rng)).collect();
            let poly1 = SparseMultilinearExtension::rand(NV, &mut rng);
            let poly2 = SparseMultilinearExtension::rand(NV, &mut rng);
            let v1 = poly1.evaluate(&point).unwrap();
            let v2 = poly2.evaluate(&point).unwrap();
            // test add
            assert_eq!((&poly1 + &poly2).evaluate(&point).unwrap(), v1 + v2);
            // test sub
            assert_eq!((&poly1 - &poly2).evaluate(&point).unwrap(), v1 - v2);
            // test negate
            assert_eq!(poly1.clone().neg().evaluate(&point).unwrap(), -v1);
            // test add assign
            {
                let mut poly1 = poly1.clone();
                poly1 += &poly2;
                assert_eq!(poly1.evaluate(&point).unwrap(), v1 + v2)
            }
            // test sub assign
            {
                let mut poly1 = poly1.clone();
                poly1 -= &poly2;
                assert_eq!(poly1.evaluate(&point).unwrap(), v1 - v2)
            }
            // test add assign with scalar
            {
                let mut poly1 = poly1.clone();
                let scalar = Fr::rand(&mut rng);
                poly1 += (scalar, &poly2);
                assert_eq!(poly1.evaluate(&point).unwrap(), v1 + scalar * v2)
            }
            // test additive identity
            {
                assert_eq!(&poly1 + &SparseMultilinearExtension::zero(), poly1);
                assert_eq!(&SparseMultilinearExtension::zero() + &poly1, poly1);
                {
                    let mut poly1_cloned = poly1.clone();
                    poly1_cloned += &SparseMultilinearExtension::zero();
                    assert_eq!(&poly1_cloned, &poly1);
                    let mut zero = SparseMultilinearExtension::zero();
                    let scalar = Fr::rand(&mut rng);
                    zero += (scalar, &poly1);
                    assert_eq!(zero.evaluate(&point).unwrap(), scalar * v1);
                }
            }
        }
    }

    #[test]
    fn relabel() {
        let mut rng = test_rng();
        for _ in 0..20 {
            let mut poly = SparseMultilinearExtension::rand(10, &mut rng);
            let mut point: Vec<_> = (0..10).map(|_| Fr::rand(&mut rng)).collect();

            let expected = poly.evaluate(&point).unwrap();

            poly = poly.relabel(2, 2, 1); // should have no effect
            assert_eq!(expected, poly.evaluate(&point).unwrap());

            poly = poly.relabel(3, 4, 1); // should switch 3 and 4
            point.swap(3, 4);
            assert_eq!(expected, poly.evaluate(&point).unwrap());

            poly = poly.relabel(7, 5, 1);
            point.swap(7, 5);
            assert_eq!(expected, poly.evaluate(&point).unwrap());

            poly = poly.relabel(2, 5, 3);
            point.swap(2, 5);
            point.swap(3, 6);
            point.swap(4, 7);
            assert_eq!(expected, poly.evaluate(&point).unwrap());

            poly = poly.relabel(7, 0, 2);
            point.swap(0, 7);
            point.swap(1, 8);
            assert_eq!(expected, poly.evaluate(&point).unwrap());
        }
    }

    #[test]
    fn serialize() {
        let mut rng = test_rng();
        for _ in 0..20 {
            let mut buf = Vec::new();
            let poly = SparseMultilinearExtension::<Fr>::rand(10, &mut rng);
            let point: Vec<_> = (0..10).map(|_| Fr::rand(&mut rng)).collect();
            let expected = poly.evaluate(&point);

            poly.serialize(&mut buf).unwrap();

            let poly2: SparseMultilinearExtension<Fr> =
                SparseMultilinearExtension::deserialize(&buf[..]).unwrap();
            assert_eq!(poly2.evaluate(&point), expected);
        }
    }
}
