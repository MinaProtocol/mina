use std::ops::Mul;

use crate::general::{Field, MultiplicativeGroup, MultiplicativeMonoid};
use crate::linear::FiniteDimVectorSpace;

/// The space of all matrices.
pub trait Matrix:
    Sized + Clone + Mul<<Self as Matrix>::Row, Output = <Self as Matrix>::Column>
{
    /// The underlying field.
    type Field: Field;

    /// The type of rows of this matrix.
    type Row: FiniteDimVectorSpace<Field = Self::Field>;

    /// The type of columns of this matrix.
    type Column: FiniteDimVectorSpace<Field = Self::Field>;

    /// The type of the transposed matrix.
    type Transpose: Matrix<Field = Self::Field, Row = Self::Column, Column = Self::Row>;

    /// The number of rows of this matrix.
    fn nrows(&self) -> usize;

    /// The number of columns of this matrix.
    fn ncolumns(&self) -> usize;

    /// The i-th row of this matrix.
    fn row(&self, i: usize) -> Self::Row;

    /// The i-th column of this matrix.
    fn column(&self, i: usize) -> Self::Column;

    /// Gets the component at row `i` and column `j` of this matrix without bound checking.
    unsafe fn get_unchecked(&self, i: usize, j: usize) -> Self::Field;

    /// Gets the component at row `i` and column `j` of this matrix.
    fn get(&self, i: usize, j: usize) -> Self::Field {
        assert!(
            i < self.nrows() && j < self.ncolumns(),
            "Matrix indexing: index out of bounds."
        );

        unsafe { self.get_unchecked(i, j) }
    }

    /// Transposes this matrix.
    fn transpose(&self) -> Self::Transpose;
}

/// The space of all matrices that are stable under modifications of its components, rows and columns.
pub trait MatrixMut: Matrix {
    /// Sets the i-th row of this matrix.
    #[inline]
    fn set_row(&self, i: usize, row: &Self::Row) -> Self {
        let mut res = self.clone();
        res.set_row_mut(i, row);
        res
    }

    /// In-place sets the i-th row of this matrix.
    fn set_row_mut(&mut self, i: usize, row: &Self::Row);

    /// Sets the i-th col of this matrix.
    #[inline]
    fn set_column(&self, i: usize, col: &Self::Column) -> Self {
        let mut res = self.clone();
        res.set_column_mut(i, col);
        res
    }

    /// In-place sets the i-th col of this matrix.
    fn set_column_mut(&mut self, i: usize, col: &Self::Column);

    /// Sets the component at row `i` and column `j` of this matrix without bound checking.
    unsafe fn set_unchecked(&mut self, i: usize, j: usize, val: Self::Field);

    /// Sets the component at row `i` and column `j` of this matrix.
    fn set(&mut self, i: usize, j: usize, val: Self::Field) {
        assert!(
            i < self.nrows() && j < self.ncolumns(),
            "Matrix indexing: index out of bounds."
        );

        unsafe { self.set_unchecked(i, j, val) }
    }
}

/// The monoid of all square matrices, including non-inversible ones.
pub trait SquareMatrix:
    Matrix<
        Row = <Self as SquareMatrix>::Vector,
        Column = <Self as SquareMatrix>::Vector,
        Transpose = Self,
    > + MultiplicativeMonoid
{
    /// The type of rows, column, and diagonal of this matrix.
    type Vector: FiniteDimVectorSpace<Field = Self::Field>;

    /// The diagonal of this matrix.
    fn diagonal(&self) -> Self::Vector;

    /// The determinant of this matrix.
    fn determinant(&self) -> Self::Field;

    // FIXME: add an epsilon value (as for try_normalize)?
    /// Attempts to two_sided_inverse `self`.
    #[inline]
    fn try_inverse(&self) -> Option<Self>;

    /// The number of rows or column of this matrix.
    #[inline]
    fn dimension(&self) -> usize {
        self.nrows()
    }

    /// In-place transposition.
    #[inline]
    fn transpose_mut(&mut self) {
        *self = self.transpose()
    }
}

/// The monoid of all mutable square matrices that are stable under modification of its diagonal.
pub trait SquareMatrixMut:
    SquareMatrix
    + MatrixMut<
        Row = <Self as SquareMatrix>::Vector,
        Column = <Self as SquareMatrix>::Vector,
        Transpose = Self,
    >
{
    /// Constructs a new diagonal matrix.
    fn from_diagonal(diag: &Self::Vector) -> Self;

    /// Sets the matrix diagonal.
    #[inline]
    fn set_diagonal(&self, diag: &Self::Vector) -> Self {
        let mut res = self.clone();
        res.set_diagonal_mut(diag);
        res
    }

    /// In-place sets the matrix diagonal.
    fn set_diagonal_mut(&mut self, diag: &Self::Vector);
}

/// The group of inversible matrix. Commonly known as the General Linear group `GL(n)` by
/// algebraists.
pub trait InversibleSquareMatrix: SquareMatrix + MultiplicativeGroup {}

// Add marker traits for symmetric-, SDP-ness, etc.
