use super::{CsMatViewI, CsVecViewI};
use crate::indexing::SpIndex;
use crate::{Ix1, Ix2};
///! Utilities for sparse-to-dense conversion
use ndarray::{ArrayViewMut, Axis};

/// Assign a sparse matrix into a dense matrix
///
/// The dense matrix will not be zeroed prior to assignment,
/// so existing values not corresponding to non-zeroes will be preserved.
pub fn assign_to_dense<N, I, Iptr>(
    mut array: ArrayViewMut<N, Ix2>,
    spmat: CsMatViewI<N, I, Iptr>,
) where
    N: Clone,
    I: SpIndex,
    Iptr: SpIndex,
{
    assert_eq!(spmat.cols(), array.shape()[1], "Dimension mismatch");
    assert_eq!(spmat.rows(), array.shape()[0], "Dimension mismatch");
    let outer_axis = if spmat.is_csr() { Axis(0) } else { Axis(1) };

    let iterator = spmat.outer_iterator().zip(array.axis_iter_mut(outer_axis));
    for (sprow, mut drow) in iterator {
        for (ind, val) in sprow.iter() {
            drow[[ind]] = val.clone();
        }
    }
}

/// Assign a sparse vector into a dense vector
///
/// The dense vector will not be zeroed prior to assignment,
/// so existing values not corresponding to non-zeroes will be preserved.
pub fn assign_vector_to_dense<N, I>(
    mut array: ArrayViewMut<N, Ix1>,
    spvec: CsVecViewI<N, I>,
) where
    N: Clone,
    I: SpIndex,
{
    assert_eq!(spvec.dim(), array.len(), "Dimension mismatch");

    for (ind, val) in spvec.iter() {
        array[[ind]] = val.clone();
    }
}

#[cfg(test)]
mod test {
    use crate::test_data::{mat1, mat3};
    use crate::{CsMat, CsVec};
    use ndarray::{arr1, arr2, Array};

    #[test]
    fn to_dense() {
        let speye: CsMat<f64> = CsMat::eye(3);
        let mut deye = Array::zeros((3, 3));

        super::assign_to_dense(deye.view_mut(), speye.view());

        let res = Array::eye(3);
        assert_eq!(deye, res);

        let speye: CsMat<f64> = CsMat::eye_csc(3);
        let mut deye = Array::zeros((3, 3));

        super::assign_to_dense(deye.view_mut(), speye.view());

        assert_eq!(deye, res);

        let res = mat1().to_dense();
        let expected = arr2(&[
            [0., 0., 3., 4., 0.],
            [0., 0., 0., 2., 5.],
            [0., 0., 5., 0., 0.],
            [0., 8., 0., 0., 0.],
            [0., 0., 0., 7., 0.],
        ]);
        assert_eq!(expected, res);

        let res2 = mat3().to_dense();
        let expected2 = arr2(&[
            [0., 0., 3., 4.],
            [0., 0., 2., 5.],
            [0., 0., 5., 0.],
            [0., 8., 0., 0.],
            [0., 0., 0., 7.],
        ]);
        assert_eq!(expected2, res2);
    }

    #[test]
    fn vector_to_dense() {
        let spvec = CsVec::new(4, vec![1, 2, 3], vec![1_i32, 3, 4]);

        let mut dvec = Array::zeros(4);

        super::assign_vector_to_dense(dvec.view_mut(), spvec.view());

        let expected = arr1(&[0_i32, 1, 3, 4]);
        assert_eq!(dvec, expected);

        let dvec2 = spvec.to_dense();
        assert_eq!(dvec2, expected)
    }
}
