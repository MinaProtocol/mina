use crate::general::{
    ClosedDiv, ClosedMul, ClosedNeg, ComplexField, Id, MultiplicativeGroup, MultiplicativeMonoid,
    RealField, SubsetOf, TwoSidedInverse,
};
use crate::linear::{EuclideanSpace, NormedSpace};

// NOTE: A subgroup trait inherit from its parent groups.

/// A general transformation acting on an euclidean space. It may not be inversible.
pub trait Transformation<E: EuclideanSpace>: MultiplicativeMonoid {
    /// Applies this group's action on a point from the euclidean space.
    fn transform_point(&self, pt: &E) -> E;

    /// Applies this group's action on a vector from the euclidean space.
    ///
    /// If `v` is a vector and `a, b` two point such that `v = a - b`, the action `∘` on a vector
    /// is defined as `self ∘ v = (self × a) - (self × b)`.
    fn transform_vector(&self, v: &E::Coordinates) -> E::Coordinates;
}

/// The most general form of invertible transformations on an euclidean space.
pub trait ProjectiveTransformation<E: EuclideanSpace>:
    MultiplicativeGroup + Transformation<E>
{
    /// Applies this group's two_sided_inverse action on a point from the euclidean space.
    fn inverse_transform_point(&self, pt: &E) -> E;

    /// Applies this group's two_sided_inverse action on a vector from the euclidean space.
    ///
    /// If `v` is a vector and `a, b` two point such that `v = a - b`, the action `∘` on a vector
    /// is defined as `self ∘ v = (self × a) - (self × b)`.
    fn inverse_transform_vector(&self, v: &E::Coordinates) -> E::Coordinates;
}

/// The group of affine transformations. They are decomposable into a rotation, a non-uniform
/// scaling, a second rotation, and a translation (applied in that order).
pub trait AffineTransformation<E: EuclideanSpace>: ProjectiveTransformation<E> {
    /// Type of the first rotation to be applied.
    type Rotation: Rotation<E>;
    /// Type of the non-uniform scaling to be applied.
    type NonUniformScaling: AffineTransformation<E>;
    /// The type of the pure translation part of this affine transformation.
    type Translation: Translation<E>;

    /// Decomposes this affine transformation into a rotation followed by a non-uniform scaling,
    /// followed by a rotation, followed by a translation.
    fn decompose(
        &self,
    ) -> (
        Self::Translation,
        Self::Rotation,
        Self::NonUniformScaling,
        Self::Rotation,
    );
    // FIXME: add a `recompose` method?

    /*
     * Composition with components.
     */
    /// Appends a translation to this similarity.
    fn append_translation(&self, t: &Self::Translation) -> Self;

    /// Prepends a translation to this similarity.
    fn prepend_translation(&self, t: &Self::Translation) -> Self;

    /// Appends a rotation to this similarity.
    fn append_rotation(&self, r: &Self::Rotation) -> Self;

    /// Prepends a rotation to this similarity.
    fn prepend_rotation(&self, r: &Self::Rotation) -> Self;

    /// Appends a scaling factor to this similarity.
    fn append_scaling(&self, s: &Self::NonUniformScaling) -> Self;

    /// Prepends a scaling factor to this similarity.
    fn prepend_scaling(&self, s: &Self::NonUniformScaling) -> Self;

    /// Appends to this similarity a rotation centered at the point `p`, i.e., this point is left
    /// invariant.
    ///
    /// May return `None` if `Self` does not have enough translational degree of liberty to perform
    /// this computation.
    #[inline]
    fn append_rotation_wrt_point(&self, r: &Self::Rotation, p: &E) -> Option<Self> {
        if let Some(t) = Self::Translation::from_vector(p.coordinates()) {
            let it = t.two_sided_inverse();
            Some(
                self.append_translation(&it)
                    .append_rotation(&r)
                    .append_translation(&t),
            )
        } else {
            None
        }
    }
}

/// Subgroups of the similarity group `S(n)`, i.e., rotations, translations, and (signed) uniform scaling.
///
/// Similarities map lines to lines and preserve angles.
pub trait Similarity<E: EuclideanSpace>:
    AffineTransformation<E, NonUniformScaling = <Self as Similarity<E>>::Scaling>
{
    /// The type of the pure (uniform) scaling part of this similarity transformation.
    type Scaling: Scaling<E>;

    /*
     * Components retrieval.
     */
    /// The pure translational component of this similarity transformation.
    fn translation(&self) -> Self::Translation;

    /// The pure rotational component of this similarity transformation.
    fn rotation(&self) -> Self::Rotation;

    /// The pure scaling component of this similarity transformation.
    fn scaling(&self) -> Self::Scaling;

    /*
     * Transformations.
     */
    /// Applies this transformation's pure translational part to a point.
    #[inline]
    fn translate_point(&self, pt: &E) -> E {
        self.translation().transform_point(pt)
    }

    /// Applies this transformation's pure rotational part to a point.
    #[inline]
    fn rotate_point(&self, pt: &E) -> E {
        self.rotation().transform_point(pt)
    }

    /// Applies this transformation's pure scaling part to a point.
    #[inline]
    fn scale_point(&self, pt: &E) -> E {
        self.scaling().transform_point(pt)
    }

    /// Applies this transformation's pure rotational part to a vector.
    #[inline]
    fn rotate_vector(&self, pt: &E::Coordinates) -> E::Coordinates {
        self.rotation().transform_vector(pt)
    }

    /// Applies this transformation's pure scaling part to a vector.
    #[inline]
    fn scale_vector(&self, pt: &E::Coordinates) -> E::Coordinates {
        self.scaling().transform_vector(pt)
    }

    /*
     * Inverse transformations.
     */
    /// Applies this transformation inverse's pure translational part to a point.
    #[inline]
    fn inverse_translate_point(&self, pt: &E) -> E {
        self.translation().inverse_transform_point(pt)
    }

    /// Applies this transformation inverse's pure rotational part to a point.
    #[inline]
    fn inverse_rotate_point(&self, pt: &E) -> E {
        self.rotation().inverse_transform_point(pt)
    }

    /// Applies this transformation inverse's pure scaling part to a point.
    #[inline]
    fn inverse_scale_point(&self, pt: &E) -> E {
        self.scaling().inverse_transform_point(pt)
    }

    /// Applies this transformation inverse's pure rotational part to a vector.
    #[inline]
    fn inverse_rotate_vector(&self, pt: &E::Coordinates) -> E::Coordinates {
        self.rotation().inverse_transform_vector(pt)
    }

    /// Applies this transformation inverse's pure scaling part to a vector.
    #[inline]
    fn inverse_scale_vector(&self, pt: &E::Coordinates) -> E::Coordinates {
        self.scaling().inverse_transform_vector(pt)
    }
}

/// Subgroups of the isometry group `E(n)`, i.e., rotations, reflexions, and translations.
pub trait Isometry<E: EuclideanSpace>: Similarity<E, Scaling = Id> {}

/// Subgroups of the orientation-preserving isometry group `SE(n)`, i.e., rotations and translations.
pub trait DirectIsometry<E: EuclideanSpace>: Isometry<E> {}

/// Subgroups of the n-dimensional rotations and scaling `O(n)`.
pub trait OrthogonalTransformation<E: EuclideanSpace>: Isometry<E, Translation = Id> {}

/// Subgroups of the (signed) uniform scaling group.
pub trait Scaling<E: EuclideanSpace>:
    AffineTransformation<E, NonUniformScaling = Self, Translation = Id, Rotation = Id>
    + SubsetOf<E::RealField>
{
    /// Converts this scaling factor to a real. Same as `self.to_superset()`.
    #[inline]
    fn to_real(&self) -> E::RealField {
        self.to_superset()
    }

    /// Attempts to convert a real to an element of this scaling subgroup. Same as
    /// `Self::from_superset()`. Returns `None` if no such scaling is possible for this subgroup.
    #[inline]
    fn from_real(r: E::RealField) -> Option<Self> {
        Self::from_superset(&r)
    }

    /// Raises the scaling to a power. The result must be equivalent to
    /// `self.to_superset().powf(n)`. Returns `None` if the result is not representable by `Self`.
    #[inline]
    fn powf(&self, n: E::RealField) -> Option<Self> {
        Self::from_superset(&self.to_superset().powf(n))
    }

    /// The scaling required to make `a` have the same norm as `b`, i.e., `|b| = |a| * norm_ratio(a,
    /// b)`.
    #[inline]
    fn scale_between(a: &E::Coordinates, b: &E::Coordinates) -> Option<Self> {
        Self::from_superset(&(b.norm() / a.norm()))
    }
}

/// Subgroups of the n-dimensional translation group `T(n)`.
pub trait Translation<E: EuclideanSpace>:
    DirectIsometry<E, Translation = Self, Rotation = Id> /* + SubsetOf<E::Coordinates> */
{
    // NOTE: we must define those two conversions here (instead of just using SubsetOf) because the
    // structure of Self uses the multiplication for composition, while E::Coordinates uses addition.
    // Having a trait that says "remap this operator to this other one" does not seem to be
    // possible without higher kinded traits.
    /// Converts this translation to a vector.
    fn to_vector(&self) -> E::Coordinates;

    /// Attempts to convert a vector to this translation. Returns `None` if the translation
    /// represented by `v` is not part of the translation subgroup represented by `Self`.
    fn from_vector(v: E::Coordinates) -> Option<Self>;

    /// Raises the translation to a power. The result must be equivalent to
    /// `self.to_superset() * n`.  Returns `None` if the result is not representable by `Self`.
    #[inline]
    fn powf(&self, n: E::RealField) -> Option<Self> {
        Self::from_vector(self.to_vector() * n)
    }

    /// The translation needed to make `a` coincide with `b`, i.e., `b = a * translation_to(a, b)`.
    #[inline]
    fn translation_between(a: &E, b: &E) -> Option<Self> {
        Self::from_vector(b.clone() - a.clone())
    }
}

/// Subgroups of the n-dimensional rotation group `SO(n)`.
pub trait Rotation<E: EuclideanSpace>:
    OrthogonalTransformation<E, Rotation = Self> + DirectIsometry<E, Rotation = Self>
{
    /// Raises this rotation to a power. If this is a simple rotation, the result must be
    /// equivalent to multiplying the rotation angle by `n`.
    fn powf(&self, n: E::RealField) -> Option<Self>;

    /// Computes a simple rotation that makes the angle between `a` and `b` equal to zero, i.e.,
    /// `b.angle(a * delta_rotation(a, b)) = 0`. If `a` and `b` are collinear, the computed
    /// rotation may not be unique. Returns `None` if no such simple rotation exists in the
    /// subgroup represented by `Self`.
    fn rotation_between(a: &E::Coordinates, b: &E::Coordinates) -> Option<Self>;

    /// Computes the rotation between `a` and `b` and raises it to the power `n`.
    ///
    /// This is equivalent to calling `self.rotation_between(a, b)` followed by `.powf(n)` but will
    /// usually be much more efficient.
    #[inline]
    fn scaled_rotation_between(
        a: &E::Coordinates,
        b: &E::Coordinates,
        s: E::RealField,
    ) -> Option<Self>;

    // FIXME: add a function that computes the rotation with the axis orthogonal to Span(a, b) and
    // with angle equal to `n`?
}

/*
 *
 * Implementation for floats.
 *
 */

impl<R, E> Transformation<E> for R
where
    R: RealField,
    E: EuclideanSpace<RealField = R>,
    E::Coordinates: ClosedMul<R> + ClosedDiv<R> + ClosedNeg,
{
    #[inline]
    fn transform_point(&self, pt: &E) -> E {
        pt.scale_by(*self)
    }

    #[inline]
    fn transform_vector(&self, v: &E::Coordinates) -> E::Coordinates {
        v.clone() * *self
    }
}

impl<R, E> ProjectiveTransformation<E> for R
where
    R: RealField,
    E: EuclideanSpace<RealField = R>,
    E::Coordinates: ClosedMul<R> + ClosedDiv<R> + ClosedNeg,
{
    #[inline]
    fn inverse_transform_point(&self, pt: &E) -> E {
        assert!(*self != R::zero());
        pt.scale_by(R::one() / *self)
    }

    #[inline]
    fn inverse_transform_vector(&self, v: &E::Coordinates) -> E::Coordinates {
        assert!(*self != R::zero());
        v.clone() * (R::one() / *self)
    }
}

impl<R, E> AffineTransformation<E> for R
where
    R: RealField,
    E: EuclideanSpace<RealField = R>,
    E::Coordinates: ClosedMul<R> + ClosedDiv<R> + ClosedNeg,
{
    type Rotation = Id;
    type NonUniformScaling = R;
    type Translation = Id;

    #[inline]
    fn decompose(&self) -> (Id, Id, R, Id) {
        (Id::new(), Id::new(), *self, Id::new())
    }

    #[inline]
    fn append_translation(&self, _: &Self::Translation) -> Self {
        *self
    }

    #[inline]
    fn prepend_translation(&self, _: &Self::Translation) -> Self {
        *self
    }

    #[inline]
    fn append_rotation(&self, _: &Self::Rotation) -> Self {
        *self
    }

    #[inline]
    fn prepend_rotation(&self, _: &Self::Rotation) -> Self {
        *self
    }

    #[inline]
    fn append_scaling(&self, s: &Self::NonUniformScaling) -> Self {
        *s * *self
    }

    #[inline]
    fn prepend_scaling(&self, s: &Self::NonUniformScaling) -> Self {
        *self * *s
    }
}

impl<R, E> Scaling<E> for R
where
    R: RealField + SubsetOf<R>,
    E: EuclideanSpace<RealField = R>,
    E::Coordinates: ClosedMul<R> + ClosedDiv<R> + ClosedNeg,
{
    #[inline]
    fn to_real(&self) -> E::RealField {
        *self
    }

    #[inline]
    fn from_real(r: E::RealField) -> Option<Self> {
        Some(r)
    }

    #[inline]
    fn powf(&self, n: E::RealField) -> Option<Self> {
        Some(n.powf(n))
    }

    #[inline]
    fn scale_between(a: &E::Coordinates, b: &E::Coordinates) -> Option<Self> {
        Some(b.norm() / a.norm())
    }
}

impl<R, E> Similarity<E> for R
where
    R: RealField + SubsetOf<R>,
    E: EuclideanSpace<RealField = R>,
    E::Coordinates: ClosedMul<R> + ClosedDiv<R> + ClosedNeg,
{
    type Scaling = R;

    fn translation(&self) -> Self::Translation {
        Id::new()
    }

    fn rotation(&self) -> Self::Rotation {
        Id::new()
    }

    fn scaling(&self) -> Self::Scaling {
        *self
    }
}
