//! Sparse matrix addition, subtraction

use std::ops::{Add, Deref, Mul, Sub};

use crate::errors::StructureError;
use crate::indexing::SpIndex;
use crate::sparse::compressed::SpMatView;
use crate::sparse::csmat::CompressedStorage;
use crate::sparse::prelude::*;
use crate::sparse::vec::NnzEither::{Both, Left, Right};
use crate::sparse::vec::SparseIterTools;
use crate::IndPtr;
use ndarray::{
    self, Array, ArrayBase, ArrayView, ArrayViewMut, Axis, ShapeBuilder,
};
use num_traits::Zero;

use crate::Ix2;

impl<
        'a,
        'b,
        Lhs,
        Rhs,
        Res,
        I,
        Iptr,
        IpStorage,
        IStorage,
        DStorage,
        IpS2,
        IS2,
        DS2,
    > Add<&'b CsMatBase<Rhs, I, IpS2, IS2, DS2, Iptr>>
    for &'a CsMatBase<Lhs, I, IpStorage, IStorage, DStorage, Iptr>
where
    Lhs: Zero,
    Rhs: Zero + Clone + Default,
    Res: Zero + Clone,
    for<'r> &'r Lhs: Add<&'r Rhs, Output = Res>,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpStorage: 'a + Deref<Target = [Iptr]>,
    IStorage: 'a + Deref<Target = [I]>,
    DStorage: 'a + Deref<Target = [Lhs]>,
    IpS2: 'b + Deref<Target = [Iptr]>,
    IS2: 'b + Deref<Target = [I]>,
    DS2: 'b + Deref<Target = [Rhs]>,
{
    type Output = CsMatI<Res, I, Iptr>;

    fn add(
        self,
        rhs: &'b CsMatBase<Rhs, I, IpS2, IS2, DS2, Iptr>,
    ) -> Self::Output {
        if self.storage() != rhs.view().storage() {
            return csmat_binop(
                self.view(),
                rhs.to_other_storage().view(),
                |x, y| x.add(y),
            );
        }
        csmat_binop(self.view(), rhs.view(), |x, y| x.add(y))
    }
}

impl<
        'a,
        'b,
        Lhs,
        Rhs,
        Res,
        I,
        Iptr,
        IpStorage,
        IStorage,
        DStorage,
        IpS2,
        IS2,
        DS2,
    > Sub<&'b CsMatBase<Rhs, I, IpS2, IS2, DS2, Iptr>>
    for &'a CsMatBase<Lhs, I, IpStorage, IStorage, DStorage, Iptr>
where
    Lhs: Zero,
    Rhs: Zero + Clone + Default,
    Res: Zero + Clone,
    for<'r> &'r Lhs: Sub<&'r Rhs, Output = Res>,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpStorage: 'a + Deref<Target = [Iptr]>,
    IStorage: 'a + Deref<Target = [I]>,
    DStorage: 'a + Deref<Target = [Lhs]>,
    IpS2: 'a + Deref<Target = [Iptr]>,
    IS2: 'a + Deref<Target = [I]>,
    DS2: 'a + Deref<Target = [Rhs]>,
{
    type Output = CsMatI<Res, I, Iptr>;

    fn sub(
        self,
        rhs: &'b CsMatBase<Rhs, I, IpS2, IS2, DS2, Iptr>,
    ) -> Self::Output {
        if self.storage() != rhs.view().storage() {
            return csmat_binop(
                self.view(),
                rhs.to_other_storage().view(),
                |x, y| x - y,
            );
        }
        csmat_binop(self.view(), rhs.view(), |x, y| x - y)
    }
}

/// Sparse matrix scalar multiplication, with same storage type
pub fn mul_mat_same_storage<Lhs, Rhs, Res, I, Iptr, Mat1, Mat2>(
    lhs: &Mat1,
    rhs: &Mat2,
) -> CsMatI<Res, I, Iptr>
where
    Lhs: Zero,
    Rhs: Zero,
    Res: Zero + Clone,
    for<'r> &'r Lhs: std::ops::Mul<&'r Rhs, Output = Res>,
    I: SpIndex,
    Iptr: SpIndex,
    Mat1: SpMatView<Lhs, I, Iptr>,
    Mat2: SpMatView<Rhs, I, Iptr>,
{
    csmat_binop(lhs.view(), rhs.view(), |x, y| x * y)
}

macro_rules! sparse_scalar_mul {
    ($scalar: ident) => {
        impl<'a, I, Iptr, IpStorage, IStorage, DStorage> Mul<$scalar>
            for &'a CsMatBase<$scalar, I, IpStorage, IStorage, DStorage, Iptr>
        where
            I: 'a + SpIndex,
            Iptr: 'a + SpIndex,
            IpStorage: 'a + Deref<Target = [Iptr]>,
            IStorage: 'a + Deref<Target = [I]>,
            DStorage: 'a + Deref<Target = [$scalar]>,
        {
            type Output = CsMatI<$scalar, I, Iptr>;

            fn mul(self, rhs: $scalar) -> Self::Output {
                self.map(|x| x * rhs)
            }
        }
    };
}

sparse_scalar_mul!(u8);
sparse_scalar_mul!(i8);
sparse_scalar_mul!(u16);
sparse_scalar_mul!(i16);
sparse_scalar_mul!(u32);
sparse_scalar_mul!(i32);
sparse_scalar_mul!(u64);
sparse_scalar_mul!(i64);
sparse_scalar_mul!(isize);
sparse_scalar_mul!(usize);
sparse_scalar_mul!(f32);
sparse_scalar_mul!(f64);

/// Applies a binary operation to matching non-zero elements
/// of two sparse matrices. When e.g. only the `lhs` has a non-zero at a
/// given location, `0` is inferred for the non-zero value of the other matrix.
/// Both matrices should have the same storage.
///
/// Thus the behaviour is correct iff `binop(N::zero(), N::zero()) == N::zero()`
///
/// # Panics
///
/// - on incompatible dimensions
/// - on incomatible storage
pub fn csmat_binop<Lhs, Rhs, Res, I, Iptr, F>(
    lhs: CsMatViewI<Lhs, I, Iptr>,
    rhs: CsMatViewI<Rhs, I, Iptr>,
    binop: F,
) -> CsMatI<Res, I, Iptr>
where
    Lhs: Zero,
    Rhs: Zero,
    Res: Zero + Clone,
    I: SpIndex,
    Iptr: SpIndex,
    F: Fn(&Lhs, &Rhs) -> Res,
{
    let nrows = lhs.rows();
    let ncols = lhs.cols();
    let storage = lhs.storage();
    assert!(
        nrows == rhs.rows() && ncols == rhs.cols(),
        "Dimension mismatch"
    );
    assert_eq!(storage, rhs.storage(), "Storage mismatch");

    let max_nnz = lhs.nnz() + rhs.nnz();
    let mut out_indptr = vec![Iptr::zero(); lhs.outer_dims() + 1];
    let mut out_indices = vec![I::zero(); max_nnz];
    let mut out_data = vec![Res::zero(); max_nnz];

    let nnz = csmat_binop_same_storage_raw(
        lhs,
        rhs,
        binop,
        &mut out_indptr[..],
        &mut out_indices[..],
        &mut out_data[..],
    );
    out_indices.truncate(nnz);
    out_data.truncate(nnz);
    CsMatI {
        storage,
        nrows,
        ncols,
        indptr: IndPtr::new_trusted(out_indptr),
        indices: out_indices,
        data: out_data,
    }
}

/// Raw implementation of scalar binary operation for compressed sparse matrices
/// sharing the same storage. The output arrays are assumed to be preallocated
///
/// Returns the nnz count
pub fn csmat_binop_same_storage_raw<Lhs, Rhs, Res, I, Iptr, F>(
    lhs: CsMatViewI<Lhs, I, Iptr>,
    rhs: CsMatViewI<Rhs, I, Iptr>,
    binop: F,
    out_indptr: &mut [Iptr],
    out_indices: &mut [I],
    out_data: &mut [Res],
) -> usize
where
    Lhs: Zero,
    Rhs: Zero,
    Res: Zero,
    I: SpIndex,
    Iptr: SpIndex,
    F: Fn(&Lhs, &Rhs) -> Res,
{
    assert_eq!(lhs.cols(), rhs.cols());
    assert_eq!(lhs.rows(), rhs.rows());
    assert_eq!(lhs.storage(), rhs.storage());
    assert_eq!(out_indptr.len(), rhs.outer_dims() + 1);
    let max_nnz = lhs.nnz() + rhs.nnz();
    assert!(out_data.len() >= max_nnz);
    assert!(out_indices.len() >= max_nnz);
    let mut nnz = 0;
    out_indptr[0] = Iptr::zero();
    let iter = lhs.outer_iterator().zip(rhs.outer_iterator()).enumerate();
    for (dim, (lv, rv)) in iter {
        for elem in lv.iter().nnz_or_zip(rv.iter()) {
            let (ind, binop_val) = match elem {
                Left((ind, val)) => (ind, binop(val, &Rhs::zero())),
                Right((ind, val)) => (ind, binop(&Lhs::zero(), val)),
                Both((ind, lval, rval)) => (ind, binop(lval, rval)),
            };
            if !binop_val.is_zero() {
                out_indices[nnz] = I::from_usize_unchecked(ind);
                out_data[nnz] = binop_val;
                nnz += 1;
            }
        }
        out_indptr[dim + 1] = Iptr::from_usize(nnz);
    }
    nnz
}

/// Compute alpha * lhs + beta * rhs with lhs a sparse matrix and rhs dense
/// and alpha and beta scalars
///
/// The matrices must have the same ordering, a `CSR` matrix must be
/// added with a matrix with `C`-like ordering, a `CSC` matrix
/// must be added with a matrix with `F`-like ordering.
pub fn add_dense_mat_same_ordering<
    Lhs,
    Rhs,
    Res,
    Alpha,
    Beta,
    ByProd1,
    ByProd2,
    I,
    Iptr,
    Mat,
    D,
>(
    lhs: &Mat,
    rhs: &ArrayBase<D, Ix2>,
    alpha: Alpha,
    beta: Beta,
) -> Array<Res, Ix2>
where
    Mat: SpMatView<Lhs, I, Iptr>,
    D: ndarray::Data<Elem = Rhs>,
    Lhs: Zero,
    Rhs: Zero,
    Res: Zero + Copy,
    for<'r> &'r Alpha: Mul<&'r Lhs, Output = ByProd1>,
    for<'r> &'r Beta: Mul<&'r Rhs, Output = ByProd2>,
    ByProd1: Add<ByProd2, Output = Res>,
    I: SpIndex,
    Iptr: SpIndex,
{
    let shape = (rhs.shape()[0], rhs.shape()[1]);
    let is_clike_layout = super::utils::fastest_axis(rhs.view()) == Axis(1);
    let mut res = if is_clike_layout {
        Array::zeros(shape)
    } else {
        Array::zeros(shape.f())
    };
    csmat_binop_dense_raw(
        lhs.view(),
        rhs.view(),
        |x, y| &alpha * x + &beta * y,
        res.view_mut(),
    );
    res
}

/// Compute coeff wise `alpha * lhs * rhs` with `lhs` a sparse matrix,
/// `rhs` a dense matrix, and `alpha` a scalar
///
/// The matrices must have the same ordering, a `CSR` matrix must be
/// multiplied with a matrix with `C`-like ordering, a `CSC` matrix
/// must be multiplied with a matrix with `F`-like ordering.
pub fn mul_dense_mat_same_ordering<
    Lhs,
    Rhs,
    Res,
    Alpha,
    ByProd,
    I,
    Iptr,
    Mat,
    D,
>(
    lhs: &Mat,
    rhs: &ArrayBase<D, Ix2>,
    alpha: Alpha,
) -> Array<Res, Ix2>
where
    Lhs: Zero,
    Rhs: Zero,
    Res: Zero + Clone,
    Alpha: Copy + for<'r> Mul<&'r Lhs, Output = ByProd>,
    ByProd: for<'r> Mul<&'r Rhs, Output = Res>,
    I: SpIndex,
    Iptr: SpIndex,
    Mat: SpMatView<Lhs, I, Iptr>,
    D: ndarray::Data<Elem = Rhs>,
{
    let shape = (rhs.shape()[0], rhs.shape()[1]);
    let is_clike_layout = super::utils::fastest_axis(rhs.view()) == Axis(1);
    let mut res = if is_clike_layout {
        Array::zeros(shape)
    } else {
        Array::zeros(shape.f())
    };
    csmat_binop_dense_raw(
        lhs.view(),
        rhs.view(),
        |x, y| alpha * x * y,
        res.view_mut(),
    );
    res
}

/// Raw implementation of sparse/dense binary operations with the same
/// ordering
///
/// # Panics
///
/// On dimension mismatch
///
/// On storage mismatch. The storage for the matrices must either be
/// `lhs = CSR` with `rhs` and `out` with `Axis(1)` as the fastest dimension,
/// or
/// `lhs = CSC` with `rhs` and `out` with `Axis(0)` as the fastest dimension,
pub fn csmat_binop_dense_raw<'a, Lhs, Rhs, Res, I, Iptr, F>(
    lhs: CsMatViewI<'a, Lhs, I, Iptr>,
    rhs: ArrayView<'a, Rhs, Ix2>,
    binop: F,
    mut out: ArrayViewMut<'a, Res, Ix2>,
) where
    Lhs: 'a + Zero,
    Rhs: 'a + Zero,
    Res: Zero,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    F: Fn(&Lhs, &Rhs) -> Res,
{
    if lhs.cols() != rhs.shape()[1]
        || lhs.cols() != out.shape()[1]
        || lhs.rows() != rhs.shape()[0]
        || lhs.rows() != out.shape()[0]
    {
        panic!("Dimension mismatch");
    }
    match (
        lhs.storage(),
        super::utils::fastest_axis(rhs),
        super::utils::fastest_axis(out.view()),
    ) {
        (CompressedStorage::CSR, Axis(1), Axis(1))
        | (CompressedStorage::CSC, Axis(0), Axis(0)) => (),
        (_, _, _) => panic!("Storage mismatch"),
    }
    let slowest_axis = super::utils::slowest_axis(rhs);
    for ((mut orow, lrow), rrow) in out
        .axis_iter_mut(slowest_axis)
        .zip(lhs.outer_iterator())
        .zip(rhs.axis_iter(slowest_axis))
    {
        // now some equivalent of nnz_or_zip is needed
        for items in orow
            .iter_mut()
            .zip(rrow.iter().enumerate().nnz_or_zip(lrow.iter()))
        {
            let (oval, rl_elems) = items;
            let binop_val = match rl_elems {
                Left((_, val)) => binop(&Lhs::zero(), val),
                Right((_, val)) => binop(val, &Rhs::zero()),
                Both((_, rval, lval)) => binop(lval, rval),
            };
            *oval = binop_val;
        }
    }
}

/// Binary operations for [`CsVec`](CsVecBase)
///
/// This function iterates the non-zero locations of `lhs` and `rhs`
/// and applies the function `binop` to the matching elements (defaulting
/// to zero when e.g. only `lhs` has a non-zero at a given location).
///
/// The function thus has a correct behavior iff `binop(0, 0) == 0`.
pub fn csvec_binop<Lhs, Rhs, Res, I, F>(
    mut lhs: CsVecViewI<Lhs, I>,
    mut rhs: CsVecViewI<Rhs, I>,
    binop: F,
) -> Result<CsVecI<Res, I>, StructureError>
where
    Lhs: Zero,
    Rhs: Zero,
    F: Fn(&Lhs, &Rhs) -> Res,
    I: SpIndex,
{
    csvec_fix_zeros(&mut lhs, &mut rhs);
    assert_eq!(lhs.dim(), rhs.dim(), "Dimension mismatch");
    let mut res = CsVecI::empty(lhs.dim());
    let max_nnz = lhs.nnz() + rhs.nnz();
    res.reserve_exact(max_nnz);
    for elem in lhs.iter().nnz_or_zip(rhs.iter()) {
        let (ind, binop_val) = match elem {
            Left((ind, val)) => (ind, binop(val, &Rhs::zero())),
            Right((ind, val)) => (ind, binop(&Lhs::zero(), val)),
            Both((ind, lval, rval)) => (ind, binop(lval, rval)),
        };
        res.append(ind, binop_val);
    }
    Ok(res)
}

fn csvec_fix_zeros<Lhs, Rhs, I: SpIndex>(
    lhs: &mut CsVecViewI<Lhs, I>,
    rhs: &mut CsVecViewI<Rhs, I>,
) {
    if rhs.dim() == 0 {
        rhs.dim = lhs.dim;
    }
    if lhs.dim() == 0 {
        lhs.dim = rhs.dim;
    }
}

#[cfg(test)]
mod test {
    use crate::sparse::CsMat;
    use crate::sparse::CsVec;
    use crate::test_data::{mat1, mat1_times_2, mat2, mat_dense1};
    use ndarray::{arr2, Array};

    fn mat1_plus_mat2() -> CsMat<f64> {
        let indptr = vec![0, 5, 8, 9, 12, 15];
        let indices = vec![0, 1, 2, 3, 4, 0, 3, 4, 2, 1, 2, 3, 1, 2, 3];
        let data =
            vec![6., 7., 6., 4., 3., 8., 11., 5., 5., 8., 2., 4., 4., 4., 7.];
        CsMat::new((5, 5), indptr, indices, data)
    }

    fn mat1_minus_mat2() -> CsMat<f64> {
        let indptr = vec![0, 4, 7, 8, 11, 14];
        let indices = vec![0, 1, 3, 4, 0, 3, 4, 2, 1, 2, 3, 1, 2, 3];
        let data = vec![
            -6., -7., 4., -3., -8., -7., 5., 5., 8., -2., -4., -4., -4., 7.,
        ];
        CsMat::new((5, 5), indptr, indices, data)
    }

    fn mat1_times_mat2() -> CsMat<f64> {
        let indptr = vec![0, 1, 2, 2, 2, 2];
        let indices = vec![2, 3];
        let data = vec![9., 18.];
        CsMat::new((5, 5), indptr, indices, data)
    }

    #[test]
    fn test_add1() {
        let a = mat1();
        let b = mat2();

        let c = &a + &b;
        let c_true = mat1_plus_mat2();
        assert_eq!(c, c_true);

        // test with CSR matrices having differ row patterns
        let a = CsMat::new((3, 3), vec![0, 1, 1, 2], vec![0, 2], vec![1., 1.]);
        let b = CsMat::new((3, 3), vec![0, 1, 2, 2], vec![0, 1], vec![1., 1.]);
        let c = CsMat::new(
            (3, 3),
            vec![0, 1, 2, 3],
            vec![0, 1, 2],
            vec![2., 1., 1.],
        );

        assert_eq!(c, &a + &b);
    }

    #[test]
    fn test_sub1() {
        let a = mat1();
        let b = mat2();

        let c = &a - &b;
        let c_true = mat1_minus_mat2();
        assert_eq!(c, c_true);
    }

    #[test]
    fn test_mul1() {
        let a = mat1();
        let b = mat2();

        let c = super::mul_mat_same_storage(&a, &b);
        let c_true = mat1_times_mat2();
        assert_eq!(c.indptr(), c_true.indptr());
        assert_eq!(c.indices(), c_true.indices());
        assert_eq!(c.data(), c_true.data());
    }

    #[test]
    fn test_smul() {
        let a = mat1();
        let c = &a * 2.;
        let c_true = mat1_times_2();
        assert_eq!(c.indptr(), c_true.indptr());
        assert_eq!(c.indices(), c_true.indices());
        assert_eq!(c.data(), c_true.data());
    }

    #[test]
    fn csvec_binops() {
        let vec1 = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);
        let vec2 = CsVec::new(8, vec![1, 3, 5, 7], vec![2.; 4]);
        let vec3 = CsVec::new(8, vec![1, 2, 5, 6], vec![3.; 4]);

        let res = &vec1 + &vec2;
        let expected_output = CsVec::new(
            8,
            vec![0, 1, 2, 3, 4, 5, 6, 7],
            vec![1., 2., 1., 2., 1., 2., 1., 2.],
        );
        assert_eq!(expected_output, res);

        let res = &vec1 + &vec3;
        let expected_output =
            CsVec::new(8, vec![0, 1, 2, 4, 5, 6], vec![1., 3., 4., 1., 3., 4.]);
        assert_eq!(expected_output, res);
    }

    #[test]
    fn zero_sized_vector_works_as_right_vector_operand() {
        let vector = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);
        let zero = CsVec::<f64>::new(0, vec![], vec![]);
        assert_eq!(&vector + zero, vector);
    }

    #[test]
    fn zero_sized_vector_works_as_left_vector_operand() {
        let vector = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);
        let zero = CsVec::<f64>::new(0, vec![], vec![]);
        assert_eq!(zero + &vector, vector);
    }

    #[test]
    fn csr_add_dense_rowmaj() {
        let a = Array::<f32, ndarray::Dim<[usize; 2]>>::zeros((3, 3));
        let b = CsMat::<f32>::eye(3);

        let c = super::add_dense_mat_same_ordering(&b, &a, 1., 1.);

        let mut expected_output = Array::zeros((3, 3));
        expected_output[[0, 0]] = 1.;
        expected_output[[1, 1]] = 1.;
        expected_output[[2, 2]] = 1.;

        assert_eq!(c, expected_output);

        let a = mat1();
        let b = mat_dense1();

        let expected_output = arr2(&[
            [0., 1., 5., 7., 4.],
            [5., 6., 5., 6., 8.],
            [4., 5., 9., 3., 2.],
            [3., 12., 3., 2., 1.],
            [1., 2., 1., 8., 0.],
        ]);
        let c = super::add_dense_mat_same_ordering(&a, &b, 1., 1.);
        assert_eq!(c, expected_output);
        let c = &a + &b;
        assert_eq!(c, expected_output);
    }

    #[test]
    fn csr_mul_dense_rowmaj() {
        let a = Array::from_elem((3, 3), 1.);
        let b = CsMat::<f64>::eye(3);

        let c = super::mul_dense_mat_same_ordering(&b, &a, 1.);

        let expected_output = Array::eye(3);

        assert_eq!(c, expected_output);
    }

    #[test]
    fn mul_dense_strided() {
        // Multiplication should yield dense matrices
        // with the same fastest axis as input
        let a = Array::from_elem((6, 6), 1.0);
        let a = a.slice(ndarray::s![..;2, ..;2]);
        let b = CsMat::<f64>::eye(3);

        let c = super::mul_dense_mat_same_ordering(&b, &a, 1.0);
        assert!(c.is_standard_layout());

        let expected_output = Array::eye(3);
        assert_eq!(c, expected_output);

        use ndarray::ShapeBuilder;
        let a = Array::from_elem((6, 6).f(), 1.0);
        let a = a.slice(ndarray::s![..;2, ..;2]);
        let b = CsMat::<f64>::eye_csc(3);

        let c = super::mul_dense_mat_same_ordering(&b, &a, 1.0);
        assert!(c.t().is_standard_layout());

        let expected_output = Array::eye(3);
        assert_eq!(c, expected_output);
    }

    #[test]
    fn binop_standard_layouts() {
        use ndarray::ShapeBuilder;
        let csr = CsMat::zero((3, 4));
        let a = Array::from_elem((3, 4), 1.0);
        let mut out = a.clone();
        super::csmat_binop_dense_raw(
            csr.view(),
            a.view(),
            |_: &f32, _: &f32| 0.0,
            out.view_mut(),
        );

        let csc = CsMat::zero((3, 4)).into_csc();
        let a = Array::from_elem((3, 4).f(), 1.0);
        let mut out = Array::zeros((3, 4).f());
        super::csmat_binop_dense_raw(
            csc.view(),
            a.view(),
            |_: &f32, _: &f32| 0.0,
            out.view_mut(),
        );
    }

    #[test]
    fn binop_strided_layouts() {
        // Strided matrices are compatible if they have
        // the same fastest dimension
        use ndarray::{s, ShapeBuilder};
        let csr = CsMat::zero((3, 4));
        let a = Array::from_elem((3, 8), 1.0);
        let a = a.slice(s![.., ..;2]);
        let mut out = Array::zeros((3, 4));
        super::csmat_binop_dense_raw(
            csr.view(),
            a.view(),
            |_: &f32, _: &f32| 0.0,
            out.view_mut(),
        );

        let csc = CsMat::zero((3, 4)).into_csc();
        let a = Array::from_elem((3, 8).f(), 1.0);
        let a = a.slice(s![.., ..;2]);
        let mut out = Array::zeros((3, 4).f());
        super::csmat_binop_dense_raw(
            csc.view(),
            a.view(),
            |_: &f32, _: &f32| 0.0,
            out.view_mut(),
        );
    }
}
