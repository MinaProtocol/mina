use num;

use crate::general::{Id, Identity};
use crate::linear::{
    AffineTransformation, DirectIsometry, EuclideanSpace, InnerSpace, Isometry,
    OrthogonalTransformation, ProjectiveTransformation, Rotation, Scaling, Similarity,
    Transformation, Translation,
};

/*
 * Implementation of linear algebra structures for the ubiquitous identity element.
 */
impl<E: EuclideanSpace> Transformation<E> for Id {
    #[inline]
    fn transform_point(&self, pt: &E) -> E {
        pt.clone()
    }

    #[inline]
    fn transform_vector(&self, v: &E::Coordinates) -> E::Coordinates {
        v.clone()
    }
}

impl<E: EuclideanSpace> ProjectiveTransformation<E> for Id {
    #[inline]
    fn inverse_transform_point(&self, pt: &E) -> E {
        pt.clone()
    }

    #[inline]
    fn inverse_transform_vector(&self, v: &E::Coordinates) -> E::Coordinates {
        v.clone()
    }
}

impl<E: EuclideanSpace> AffineTransformation<E> for Id {
    type Rotation = Id;
    type NonUniformScaling = Id;
    type Translation = Id;

    #[inline]
    fn decompose(&self) -> (Id, Id, Id, Id) {
        (Id::new(), Id::new(), Id::new(), Id::new())
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
    fn append_scaling(&self, _: &Self::NonUniformScaling) -> Self {
        *self
    }

    #[inline]
    fn prepend_scaling(&self, _: &Self::NonUniformScaling) -> Self {
        *self
    }
}

impl<E: EuclideanSpace> Similarity<E> for Id {
    type Scaling = Id;

    #[inline]
    fn translation(&self) -> Self::Translation {
        Id::new()
    }

    #[inline]
    fn rotation(&self) -> Self::Rotation {
        Id::new()
    }

    #[inline]
    fn scaling(&self) -> Self::Scaling {
        Id::new()
    }
}

impl<E: EuclideanSpace> Scaling<E> for Id {}
impl<E: EuclideanSpace> Isometry<E> for Id {}
impl<E: EuclideanSpace> DirectIsometry<E> for Id {}
impl<E: EuclideanSpace> OrthogonalTransformation<E> for Id {}

impl<E: EuclideanSpace> Rotation<E> for Id {
    #[inline]
    fn powf(&self, _: E::RealField) -> Option<Self> {
        Some(Id::new())
    }

    #[inline]
    fn rotation_between(a: &E::Coordinates, b: &E::Coordinates) -> Option<Self> {
        if a.angle(b) == num::zero() {
            Some(Id::new())
        } else {
            None
        }
    }

    #[inline]
    fn scaled_rotation_between(
        a: &E::Coordinates,
        b: &E::Coordinates,
        _: E::RealField,
    ) -> Option<Self> {
        Rotation::<E>::rotation_between(a, b)
    }
}

impl<E: EuclideanSpace> Translation<E> for Id {
    #[inline]
    fn to_vector(&self) -> E::Coordinates {
        E::Coordinates::identity()
    }

    #[inline]
    fn from_vector(v: E::Coordinates) -> Option<Self> {
        if v == E::Coordinates::identity() {
            Some(Id::new())
        } else {
            None
        }
    }
}
