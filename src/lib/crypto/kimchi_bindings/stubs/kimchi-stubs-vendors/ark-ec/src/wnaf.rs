use crate::ProjectiveCurve;
use ark_ff::{BigInteger, PrimeField};
use ark_std::vec::Vec;

/// A helper type that contains all the context required for computing
/// a window NAF multiplication of a group element by a scalar.
pub struct WnafContext {
    pub window_size: usize,
}

impl WnafContext {
    /// Construct a new context for a window of size `window_size`.
    pub fn new(window_size: usize) -> Self {
        assert!(window_size >= 2);
        assert!(window_size < 64);
        Self { window_size }
    }

    pub fn table<G: ProjectiveCurve>(&self, mut base: G) -> Vec<G> {
        let mut table = Vec::with_capacity(1 << (self.window_size - 1));
        let dbl = base.double();

        for _ in 0..(1 << (self.window_size - 1)) {
            table.push(base);
            base += &dbl;
        }
        table
    }

    /// Computes scalar multiplication of a group element `g` by `scalar`.
    ///
    /// This method uses the wNAF algorithm to perform the scalar multiplication;
    /// first, it uses `Self::table` to calculate an appropriate table of multiples of `g`,
    /// and then uses the wNAF algorithm to compute the scalar multiple.
    pub fn mul<G: ProjectiveCurve>(&self, g: G, scalar: &G::ScalarField) -> G {
        let table = self.table(g);
        self.mul_with_table(&table, scalar).unwrap()
    }

    /// Computes scalar multiplication of a group element by `scalar`.
    /// `base_table` holds precomputed multiples of the group element; it can be generated using `Self::table`.
    /// `scalar` is an element of `G::ScalarField`.
    ///
    /// Returns `None` if the table is too small.
    pub fn mul_with_table<G: ProjectiveCurve>(
        &self,
        base_table: &[G],
        scalar: &G::ScalarField,
    ) -> Option<G> {
        if 1 << (self.window_size - 1) > base_table.len() {
            return None;
        }
        let scalar_wnaf = scalar.into_repr().find_wnaf(self.window_size).unwrap();

        let mut result = G::zero();

        let mut found_non_zero = false;

        for n in scalar_wnaf.iter().rev() {
            if found_non_zero {
                result.double_in_place();
            }

            if *n != 0 {
                found_non_zero = true;

                if *n > 0 {
                    result += &base_table[(n / 2) as usize];
                } else {
                    result -= &base_table[((-n) / 2) as usize];
                }
            }
        }

        Some(result)
    }
}
