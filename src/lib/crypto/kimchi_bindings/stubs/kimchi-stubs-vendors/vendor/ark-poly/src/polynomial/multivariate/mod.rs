//! Work with sparse multivariate polynomials.
use ark_ff::Field;
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize, SerializationError};
use ark_std::{
    cmp::Ordering,
    fmt::{Debug, Error, Formatter},
    hash::Hash,
    io::{Read, Write},
    ops::Deref,
    vec::Vec,
};

#[cfg(feature = "parallel")]
use rayon::prelude::*;

mod sparse;
pub use sparse::SparsePolynomial;

/// Describes the interface for a term (monomial) of a multivariate polynomial.
pub trait Term:
    Clone
    + PartialOrd
    + Ord
    + PartialEq
    + Eq
    + Hash
    + Default
    + Debug
    + Deref<Target = [(usize, usize)]>
    + Send
    + Sync
    + CanonicalSerialize
    + CanonicalDeserialize
{
    /// Create a new `Term` from a list of tuples of the form `(variable, power)`
    fn new(term: Vec<(usize, usize)>) -> Self;

    /// Returns the total degree of `self`. This is the sum of all variable powers in `self`
    fn degree(&self) -> usize;

    /// Returns a list of variables in `self`
    fn vars(&self) -> Vec<usize>;

    /// Returns a list of the powers of each variable in `self`
    fn powers(&self) -> Vec<usize>;

    /// Returns whether `self` is a constant
    fn is_constant(&self) -> bool;

    /// Evaluates `self` at the point `p`.
    fn evaluate<F: Field>(&self, p: &[F]) -> F;
}

/// Stores a term (monomial) in a multivariate polynomial.
/// Each element is of the form `(variable, power)`.  
#[derive(Clone, PartialEq, Eq, Hash, Default, CanonicalSerialize, CanonicalDeserialize)]
pub struct SparseTerm(Vec<(usize, usize)>);

impl SparseTerm {
    /// Sums the powers of any duplicated variables. Assumes `term` is sorted.
    fn combine(term: &[(usize, usize)]) -> Vec<(usize, usize)> {
        let mut term_dedup: Vec<(usize, usize)> = Vec::new();
        for (var, pow) in term {
            match term_dedup.last_mut() {
                Some(prev) => {
                    if prev.0 == *var {
                        prev.1 += pow;
                        continue;
                    }
                }
                _ => {}
            };
            term_dedup.push((*var, *pow));
        }
        term_dedup
    }
}

impl Term for SparseTerm {
    /// Create a new `Term` from a list of tuples of the form `(variable, power)`
    fn new(mut term: Vec<(usize, usize)>) -> Self {
        // Remove any terms with power 0
        term.retain(|(_, pow)| *pow != 0);
        // If there are more than one variables, make sure they are
        // in order and combine any duplicates
        if term.len() > 1 {
            term.sort_by(|(v1, _), (v2, _)| v1.cmp(v2));
            term = Self::combine(&term);
        }
        Self(term)
    }

    /// Returns the sum of all variable powers in `self`
    fn degree(&self) -> usize {
        self.iter().fold(0, |sum, acc| sum + acc.1)
    }

    /// Returns a list of variables in `self`
    fn vars(&self) -> Vec<usize> {
        self.iter().map(|(v, _)| *v).collect()
    }

    /// Returns a list of variable powers in `self`
    fn powers(&self) -> Vec<usize> {
        self.iter().map(|(_, p)| *p).collect()
    }

    /// Returns whether `self` is a constant
    fn is_constant(&self) -> bool {
        self.len() == 0
    }

    /// Evaluates `self` at the given `point` in the field.
    fn evaluate<F: Field>(&self, point: &[F]) -> F {
        cfg_into_iter!(self)
            .map(|(var, power)| point[*var].pow(&[*power as u64]))
            .product()
    }
}

impl Debug for SparseTerm {
    fn fmt(&self, f: &mut Formatter<'_>) -> Result<(), Error> {
        for variable in self.iter() {
            if variable.1 == 1 {
                write!(f, " * x_{}", variable.0)?;
            } else {
                write!(f, " * x_{}^{}", variable.0, variable.1)?;
            }
        }
        Ok(())
    }
}

impl Deref for SparseTerm {
    type Target = [(usize, usize)];

    fn deref(&self) -> &[(usize, usize)] {
        &self.0
    }
}

impl PartialOrd for SparseTerm {
    /// Sort by total degree. If total degree is equal then ordering
    /// is given by exponent weight in lower-numbered variables
    /// ie. `x_1 > x_2`, `x_1^2 > x_1 * x_2`, etc.
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        if self.degree() != other.degree() {
            Some(self.degree().cmp(&other.degree()))
        } else {
            // Iterate through all variables and return the corresponding ordering
            // if they differ in variable numbering or power
            for (cur, other) in self.iter().zip(other.iter()) {
                if other.0 == cur.0 {
                    if cur.1 != other.1 {
                        return Some((cur.1).cmp(&other.1));
                    }
                } else {
                    return Some((other.0).cmp(&cur.0));
                }
            }
            Some(Ordering::Equal)
        }
    }
}

impl Ord for SparseTerm {
    fn cmp(&self, other: &Self) -> Ordering {
        self.partial_cmp(other).unwrap()
    }
}
