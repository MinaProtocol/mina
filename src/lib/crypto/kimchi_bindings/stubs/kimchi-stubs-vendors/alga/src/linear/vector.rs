use num;
use num_complex::Complex;

use std::ops::{
    Add, AddAssign, Div, DivAssign, Index, IndexMut, Mul, MulAssign, Neg, Sub, SubAssign,
};

use crate::general::{ClosedAdd, ClosedDiv, ClosedMul, ComplexField, Field, Module, RealField};

/// A vector space has a module structure over a field instead of a ring.
pub trait VectorSpace: Module<Ring = <Self as VectorSpace>::Field>
/* +
ClosedDiv<<Self as VectorSpace>::Field> */
{
    /// The underlying scalar field.
    type Field: Field;
}

/// A normed vector space.
pub trait NormedSpace: VectorSpace<Field = <Self as NormedSpace>::ComplexField> {
    /// The result of the norm (not necessarily the same same as the field used by this vector space).
    type RealField: RealField;
    /// The field of this space must be this complex number.
    type ComplexField: ComplexField<RealField = Self::RealField>;

    /// The squared norm of this vector.
    fn norm_squared(&self) -> Self::RealField;

    /// The norm of this vector.
    fn norm(&self) -> Self::RealField;

    /// Returns a normalized version of this vector.
    fn normalize(&self) -> Self;

    /// Normalizes this vector in-place and returns its norm.
    fn normalize_mut(&mut self) -> Self::RealField;

    /// Returns a normalized version of this vector unless its norm as smaller or equal to `eps`.
    fn try_normalize(&self, eps: Self::RealField) -> Option<Self>;

    /// Normalizes this vector in-place or does nothing if its norm is smaller or equal to `eps`.
    ///
    /// If the normalization succeeded, returns the old normal of this vector.
    fn try_normalize_mut(&mut self, eps: Self::RealField) -> Option<Self::RealField>;
}

/// A vector space equipped with an inner product.
///
/// It must be a normed space as well and the norm must agree with the inner product.
/// The inner product must be symmetric, linear in its first argument, and positive definite.
pub trait InnerSpace: NormedSpace {
    /// Computes the inner product of `self` with `other`.
    fn inner_product(&self, other: &Self) -> Self::ComplexField;

    /// Measures the angle between two vectors.
    #[inline]
    fn angle(&self, other: &Self) -> Self::RealField {
        let prod = self.inner_product(other);
        let n1 = self.norm();
        let n2 = other.norm();

        if n1 == num::zero() || n2 == num::zero() {
            num::zero()
        } else {
            let cang = prod.real() * n1 * n2;

            if cang > num::one() {
                num::zero()
            } else if cang < -num::one::<Self::RealField>() {
                Self::RealField::pi()
            } else {
                cang.acos()
            }
        }
    }
}

/// A finite-dimensional vector space.
pub trait FiniteDimVectorSpace:
    VectorSpace
    + Index<usize, Output = <Self as VectorSpace>::Field>
    + IndexMut<usize, Output = <Self as VectorSpace>::Field>
{
    /// The vector space dimension.
    fn dimension() -> usize;

    /// Applies the given closule to each element of this vector space's canonical basis. Stops if
    /// `f` returns `false`.
    // XXX: return an iterator instead when `-> impl Iterator` will be supported by Rust.
    fn canonical_basis<F: FnMut(&Self) -> bool>(mut f: F) {
        for i in 0..Self::dimension() {
            if !f(&Self::canonical_basis_element(i)) {
                break;
            }
        }
    }

    /// The i-the canonical basis element.
    fn canonical_basis_element(i: usize) -> Self;

    /// The dot product between two vectors.
    fn dot(&self, other: &Self) -> Self::Field;

    /// Same as `&self[i]` but without bound-checking.
    unsafe fn component_unchecked(&self, i: usize) -> &Self::Field;

    /// Same as `&mut self[i]` but without bound-checking.
    unsafe fn component_unchecked_mut(&mut self, i: usize) -> &mut Self::Field;
}

/// A finite-dimensional vector space equipped with an inner product that must coincide
/// with the dot product.
pub trait FiniteDimInnerSpace:
    InnerSpace + FiniteDimVectorSpace<Field = <Self as NormedSpace>::ComplexField>
{
    /// Orthonormalizes the given family of vectors. The largest free family of vectors is moved at
    /// the beginning of the array and its size is returned. Vectors at an indices larger or equal to
    /// this length can be modified to an arbitrary value.
    fn orthonormalize(vs: &mut [Self]) -> usize;

    /// Applies the given closure to each element of the orthonormal basis of the subspace
    /// orthogonal to free family of vectors `vs`. If `vs` is not a free family, the result is
    /// unspecified.
    // XXX: return an iterator instead when `-> impl Iterator` will be supported by Rust.
    fn orthonormal_subspace_basis<F: FnMut(&Self) -> bool>(vs: &[Self], f: F);
}

/// A set points associated with a vector space and a transitive and free additive group action
/// (the translation).
pub trait AffineSpace:
    Sized
    + Clone
    + PartialEq
    + Sub<Self, Output = <Self as AffineSpace>::Translation>
    + ClosedAdd<<Self as AffineSpace>::Translation>
{
    /// The associated vector space.
    type Translation: VectorSpace;

    /// Same as `*self + *t`. Applies the additive group action of this affine space's associated
    /// vector space on `self`.
    #[inline]
    fn translate_by(&self, t: &Self::Translation) -> Self {
        self.clone() + t.clone()
    }

    /// Same as `*self - *other`. Returns the unique element `v` of the associated vector space
    /// such that `self = right + v`.
    #[inline]
    fn subtract(&self, right: &Self) -> Self::Translation {
        self.clone() - right.clone()
    }
}

/// The finite-dimensional affine space based on the field of reals.
pub trait EuclideanSpace: AffineSpace<Translation = <Self as EuclideanSpace>::Coordinates> +
                          // Equivalent to `.scale_by`.
                          ClosedMul<<Self as EuclideanSpace>::RealField> +
                          // Equivalent to `.scale_by`.
                          ClosedDiv<<Self as EuclideanSpace>::RealField> +
                          // Equivalent to `.scale_by(-1.0)`.
                          Neg<Output = Self> {
    /// The underlying finite vector space.
    type Coordinates: FiniteDimInnerSpace<RealField = Self::RealField, ComplexField = Self::RealField> +
                 // XXX: the following bounds should not be necessary but the compiler does not
                 // seem to be able to find them (from supertraits of VectorSpace)… Also, it won't
                 // find them even if we add ClosedMul instead of Mul and MulAssign separately…
                 Add<Self::Coordinates, Output = Self::Coordinates> +
                 AddAssign<Self::Coordinates> +
                 Sub<Self::Coordinates, Output = Self::Coordinates> +
                 SubAssign<Self::Coordinates> +
                 Mul<Self::RealField, Output = Self::Coordinates> +
                 MulAssign<Self::RealField>                  +
                 Div<Self::RealField, Output = Self::Coordinates> +
                 DivAssign<Self::RealField>                  +
                 Neg<Output = Self::Coordinates>;

    // XXX: we can't write the following =( :
    // type Vector: FiniteDimInnerSpace<Field = Self::RealField> + InnerSpace<RealField = Self::RealField>;
    // The compiler won't recognize that VectorSpace::Field = Self::RealField.
    // Though it will work if only one bound is used… looks like a compiler bug.

    /// The underlying reals.
    type RealField: RealField;

    /// The preferred origin of this euclidean space.
    ///
    /// Theoretically, an euclidean space has no clearly defined origin. Though it is almost always
    /// useful to have some reference point to express all the others as translations of it.
    fn origin() -> Self;

    /// Multiplies the distance of this point to `Self::origin()` by `s`.
    ///
    /// Same as self * s.
    #[inline]
    fn scale_by(&self, s: Self::RealField) -> Self {
        Self::from_coordinates(self.coordinates() * s)
    }

    // FIXME: take self by-value?
    /// The coordinates of this point, i.e., the translation from the origin.
    #[inline]
    fn coordinates(&self) -> Self::Coordinates {
        self.subtract(&Self::origin())
    }

    /// Builds a point from its coordinates relative to the origin.
    #[inline]
    fn from_coordinates(coords: Self::Coordinates) -> Self {
        Self::origin().translate_by(&coords)
    }

    /// The distance between two points.
    #[inline]
    fn distance_squared(&self, b: &Self) -> Self::RealField {
        self.subtract(b).norm_squared()
    }

    /// The distance between two points.
    #[inline]
    fn distance(&self, b: &Self) -> Self::RealField {
        self.subtract(b).norm()
    }
}

macro_rules! impl_vec_space(
    ($($T:ty),*) => {
        $(
            impl VectorSpace for $T{
                type Field = $T;
            }

            impl NormedSpace for $T{
                type RealField = $T;
                type ComplexField = $T;

                #[inline]
                fn norm_squared(&self) -> Self::RealField {
                    self.modulus_squared()
                }

                #[inline]
                fn norm(&self) -> Self::RealField {
                    self.modulus()
                }

                #[inline]
                fn normalize(&self) -> Self {
                    *self / self.modulus()
                }

                #[inline]
                fn normalize_mut(&mut self) -> Self::RealField {
                    let norm = self.modulus();
                    *self /= norm;
                    norm
                }

                #[inline]
                fn try_normalize(&self, eps: Self::RealField) -> Option<Self> {
                    let norm = self.modulus_squared();
                    if norm > eps * eps {
                        Some(*self / self.modulus())
                    } else {
                        None
                    }
                }

                #[inline]
                fn try_normalize_mut(&mut self, eps: Self::RealField) -> Option<Self::RealField> {
                    let sq_norm = self.modulus_squared();
                    if sq_norm > eps * eps {
                        let norm = self.modulus();
                        *self /= norm;
                        Some(norm)
                    } else {
                        None
                    }
                }

            }
        )*
    }
);

impl_vec_space!(f32, f64);

impl<N: Field + num::NumAssign> VectorSpace for Complex<N> {
    type Field = N;
}

impl<N: RealField> NormedSpace for Complex<N> {
    type RealField = N;
    type ComplexField = N;

    #[inline]
    fn norm_squared(&self) -> Self::RealField {
        self.norm_sqr()
    }

    #[inline]
    fn norm(&self) -> Self::RealField {
        self.norm_sqr().sqrt()
    }

    #[inline]
    fn normalize(&self) -> Self {
        *self / self.norm()
    }

    #[inline]
    fn normalize_mut(&mut self) -> Self::RealField {
        let norm = self.norm();
        *self /= norm;
        norm
    }

    #[inline]
    fn try_normalize(&self, eps: Self::RealField) -> Option<Self> {
        let norm = self.norm_sqr();
        if norm > eps * eps {
            Some(*self / norm.sqrt())
        } else {
            None
        }
    }

    #[inline]
    fn try_normalize_mut(&mut self, eps: Self::RealField) -> Option<Self::RealField> {
        let sq_norm = self.norm_sqr();
        if sq_norm > eps * eps {
            let norm = sq_norm.sqrt();
            *self /= norm;
            Some(norm)
        } else {
            None
        }
    }
}

// Note: we can't implement FiniteDimVectorSpace for Complex because
// the `Complex` type does not implement Index.
