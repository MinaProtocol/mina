//! High level construction of sparse matrices by stacking, by block, ...

use crate::indexing::SpIndex;
use crate::sparse::prelude::*;
use std::cmp;
use std::default::Default;

/// Stack the given matrices into a new one, using the most efficient stacking
/// direction (ie vertical stack for CSR matrices, horizontal stack for CSC)
pub fn same_storage_fast_stack<'a, N, I, Iptr, MatArray>(
    mats: &MatArray,
) -> CsMatI<N, I, Iptr>
where
    N: 'a + Clone,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    MatArray: AsRef<[CsMatViewI<'a, N, I, Iptr>]>,
{
    let mats = mats.as_ref();
    assert!(!mats.is_empty(), "Empty stacking list");
    let inner_dim = mats[0].inner_dims();
    assert!(
        mats.iter().all(|x| x.inner_dims() == inner_dim),
        "Dimension mismatch"
    );
    let storage_type = mats[0].storage();
    assert!(
        mats.iter().all(|x| x.storage() == storage_type),
        "Storage mismatch"
    );

    let outer_dim = mats.iter().map(CsMatBase::outer_dims).sum::<usize>();
    let nnz = mats.iter().map(CsMatBase::nnz).sum::<usize>();

    let mut res = CsMatI::empty(storage_type, inner_dim);
    res.reserve_outer_dim_exact(outer_dim);
    res.reserve_nnz_exact(nnz);
    for mat in mats {
        for vec in mat.outer_iterator() {
            res = res.append_outer_csvec(vec.view());
        }
    }

    res
}

/// Construct a sparse matrix by vertically stacking other matrices
pub fn vstack<'a, N, I, Iptr, MatArray>(mats: &MatArray) -> CsMatI<N, I, Iptr>
where
    N: 'a + Clone + Default,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    MatArray: AsRef<[CsMatViewI<'a, N, I, Iptr>]>,
{
    let mats = mats.as_ref();
    if mats.iter().all(CsMatBase::is_csr) {
        return same_storage_fast_stack(&mats);
    }

    let mats_csr: Vec<_> = mats.iter().map(CsMatBase::to_csr).collect();
    let mats_csr_views: Vec<_> = mats_csr.iter().map(CsMatBase::view).collect();
    same_storage_fast_stack(&mats_csr_views)
}

/// Construct a sparse matrix by horizontally stacking other matrices
pub fn hstack<'a, N, I, Iptr, MatArray>(mats: &MatArray) -> CsMatI<N, I, Iptr>
where
    N: 'a + Clone + Default,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    MatArray: AsRef<[CsMatViewI<'a, N, I, Iptr>]>,
{
    let mats = mats.as_ref();
    if mats.iter().all(CsMatBase::is_csc) {
        return same_storage_fast_stack(&mats);
    }

    let mats_csc: Vec<_> = mats.iter().map(CsMatBase::to_csc).collect();
    let mats_csc_views: Vec<_> = mats_csc.iter().map(CsMatBase::view).collect();
    same_storage_fast_stack(&mats_csc_views)
}

/// Specify a sparse matrix by constructing it from blocks of other matrices
///
/// # Examples
/// ```
/// use sprs::CsMat;
/// let a = CsMat::<f64>::eye(3);
/// let b = CsMat::<f64>::eye(4);
/// let c = sprs::bmat(&[[Some(a.view()), None],
///                      [None, Some(b.view())]]);
/// assert_eq!(c.rows(), 7);
/// ```
pub fn bmat<'a, N, I, Iptr, OuterArray, InnerArray>(
    mats: &OuterArray,
) -> CsMatI<N, I, Iptr>
where
    N: 'a + Clone + Default,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    OuterArray: 'a + AsRef<[InnerArray]>,
    InnerArray: 'a + AsRef<[Option<CsMatViewI<'a, N, I, Iptr>>]>,
{
    let mats = mats.as_ref();
    let super_rows = mats.len();
    assert_ne!(super_rows, 0, "Empty stacking list");
    let super_cols = mats[0].as_ref().len();
    assert_ne!(super_cols, 0, "Empty stacking list");

    // check input has matrix shape
    assert!(
        mats.iter().all(|x| x.as_ref().len() == super_cols),
        "Dimension mismatch"
    );

    assert!(
        !mats.iter().any(|x| x.as_ref().iter().all(Option::is_none)),
        "Empty bmat row"
    );
    assert!(
        !(0..super_cols).any(|j| mats.iter().all(|x| x.as_ref()[j].is_none())),
        "Empty bmat col"
    );

    // find out the shapes of the None elements
    let rows_per_row: Vec<_> = mats
        .iter()
        .map(|row| {
            row.as_ref().iter().fold(0, |nrows, mopt| {
                mopt.as_ref().map_or(nrows, |m| cmp::max(nrows, m.rows()))
            })
        })
        .collect();
    let cols_per_col: Vec<_> = (0..super_cols)
        .map(|j| {
            mats.iter().fold(0, |ncols, row| {
                row.as_ref()[j]
                    .as_ref()
                    .map_or(ncols, |m| cmp::max(ncols, m.cols()))
            })
        })
        .collect();
    let mut to_vstack = Vec::new();
    to_vstack.reserve(super_rows);
    for (i, row) in mats.iter().enumerate() {
        let with_zeros: Vec<_> = row
            .as_ref()
            .iter()
            .enumerate()
            .map(|(j, m)| {
                let shape = (rows_per_row[i], cols_per_col[j]);
                m.as_ref().map_or(CsMatI::zero(shape), CsMatBase::to_owned)
            })
            .collect();
        let borrows: Vec<_> = with_zeros.iter().map(CsMatBase::view).collect();
        let stacked = hstack(&borrows);
        to_vstack.push(stacked);
    }
    let borrows: Vec<_> = to_vstack.iter().map(CsMatBase::view).collect();
    vstack(&borrows)
}

#[cfg(test)]
mod test {
    use crate::sparse::CsMat;
    use crate::test_data::{mat1, mat2, mat3, mat4};

    fn mat1_vstack_mat2() -> CsMat<f64> {
        let indptr = vec![0, 2, 4, 5, 6, 7, 11, 13, 13, 15, 17];
        let indices = vec![2, 3, 3, 4, 2, 1, 3, 0, 1, 2, 4, 0, 3, 2, 3, 1, 2];
        let data = vec![
            3., 4., 2., 5., 5., 8., 7., 6., 7., 3., 3., 8., 9., 2., 4., 4., 4.,
        ];
        CsMat::new((10, 5), indptr, indices, data)
    }

    #[test]
    #[should_panic]
    fn same_storage_fast_stack_fail_empty_stacking_list() {
        let _: CsMat<f64> = super::same_storage_fast_stack(&[]);
    }

    #[test]
    #[should_panic]
    fn same_storage_fast_stack_fail_dim_mismatch() {
        let a = mat1();
        let c = mat3();
        let _ = super::same_storage_fast_stack(&[a.view(), c.view()]);
    }

    #[test]
    #[should_panic]
    fn same_storage_fast_stack_fail_storage() {
        let a = mat1();
        let d = mat4();
        let _ = super::same_storage_fast_stack(&[a.view(), d.view()]);
    }

    #[test]
    fn same_storage_fast_stack_ok() {
        let a = mat1();
        let b = mat2();
        let res = super::same_storage_fast_stack(&[a.view(), b.view()]);
        let expected = mat1_vstack_mat2();
        assert_eq!(res, expected);
    }

    #[test]
    fn vstack_trivial() {
        let a = mat1();
        let b = mat2();
        let res = super::vstack(&[a.view(), b.view()]);
        let expected = mat1_vstack_mat2();
        assert_eq!(res, expected);
    }

    #[test]
    fn hstack_trivial() {
        let a = mat1().transpose_into();
        let b = mat2().transpose_into();
        let res = super::hstack(&[a.view(), b.view()]);
        let expected = mat1_vstack_mat2().transpose_into();
        assert_eq!(res, expected);
    }

    #[test]
    fn vstack_with_conversion() {
        let a = mat1().to_csc();
        let b = mat2();
        let res = super::vstack(&[a.view(), b.view()]);
        let expected = mat1_vstack_mat2();
        assert_eq!(res, expected);
    }

    #[test]
    #[should_panic]
    fn bmat_fail_shapes() {
        let _: CsMat<f64> = super::bmat(&vec![vec![None, None], vec![None]]);
    }

    #[test]
    #[should_panic]
    fn bmat_fail_empty_stacking_list() {
        let _: CsMat<f64> = super::bmat(&[[]]);
    }

    #[test]
    #[should_panic]
    fn bmat_fail_empty_bmat_row() {
        let a = mat1();
        let c = mat3();
        let _: CsMat<f64> =
            super::bmat(&[[None, None], [Some(a.view()), Some(c.view())]]);
    }

    #[test]
    #[should_panic]
    fn bmat_fail_empty_bmat_col() {
        let a = mat1();
        let c = mat3();
        let _: CsMat<f64> =
            super::bmat(&[[Some(c.view()), None], [Some(a.view()), None]]);
    }

    #[test]
    fn bmat_simple() {
        let a = CsMat::<f64>::eye(5);
        let b = CsMat::<f64>::eye(4);
        let c = super::bmat(&[[Some(a.view()), None], [None, Some(b.view())]]);
        let expected = CsMat::new(
            (9, 9),
            vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
            vec![0, 1, 2, 3, 4, 5, 6, 7, 8],
            vec![1.; 9],
        );
        assert_eq!(c, expected);
    }

    #[test]
    fn bmat_complex() {
        let a = mat1();
        let b = mat2();
        let c = super::bmat(&[
            [Some(a.view()), Some(b.view())],
            [Some(b.view()), None],
        ]);
        let expected = CsMat::new(
            (10, 10),
            vec![0, 6, 10, 11, 14, 17, 21, 23, 23, 25, 27],
            vec![
                2, 3, 5, 6, 7, 9, 3, 4, 5, 8, 2, 1, 7, 8, 3, 6, 7, 0, 1, 2, 4,
                0, 3, 2, 3, 1, 2,
            ],
            vec![
                3., 4., 6., 7., 3., 3., 2., 5., 8., 9., 5., 8., 2., 4., 7., 4.,
                4., 6., 7., 3., 3., 8., 9., 2., 4., 4., 4.,
            ],
        );
        assert_eq!(c, expected);

        let d = mat3();
        let e = mat4();
        let f = super::bmat(&[
            [Some(d.view()), Some(a.view())],
            [None, Some(e.view())],
        ]);
        let expected = CsMat::new(
            (10, 9),
            vec![0, 4, 8, 10, 12, 14, 16, 18, 21, 23, 24],
            vec![
                2, 3, 6, 7, 2, 3, 7, 8, 2, 6, 1, 5, 3, 7, 4, 5, 4, 8, 4, 7, 8,
                5, 7, 4,
            ],
            vec![
                3., 4., 3., 4., 2., 5., 2., 5., 5., 5., 8., 8., 7., 7., 6., 8.,
                7., 4., 3., 2., 4., 9., 4., 3.,
            ],
        );
        assert_eq!(f, expected);
    }
}
