//! Traits dedicated to linear algebra.

pub use self::matrix::{InversibleSquareMatrix, Matrix, MatrixMut, SquareMatrix, SquareMatrixMut};
pub use self::transformation::{
    AffineTransformation, DirectIsometry, Isometry, OrthogonalTransformation,
    ProjectiveTransformation, Rotation, Scaling, Similarity, Transformation, Translation,
};
pub use self::vector::{
    AffineSpace, EuclideanSpace, FiniteDimInnerSpace, FiniteDimVectorSpace, InnerSpace,
    NormedSpace, VectorSpace,
};

mod id;
mod matrix;
mod transformation;
mod vector;
