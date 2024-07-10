use crate::dense_vector::{DenseVector, DenseVectorMut};
use crate::sparse::to_dense::assign_vector_to_dense;
use crate::Ix1;
use ndarray::Array;
use std::cmp;
use std::collections::HashSet;
use std::convert::AsRef;
use std::hash::Hash;
/// A sparse vector, which can be extracted from a sparse matrix
///
/// # Example
/// ```rust
/// use sprs::CsVec;
/// let vec1 = CsVec::new(8, vec![0, 2, 5, 6], vec![1.; 4]);
/// let vec2 = CsVec::new(8, vec![1, 3, 5], vec![2.; 3]);
/// let res = &vec1 + &vec2;
/// let mut iter = res.iter();
/// assert_eq!(iter.next(), Some((0, &1.)));
/// assert_eq!(iter.next(), Some((1, &2.)));
/// assert_eq!(iter.next(), Some((2, &1.)));
/// assert_eq!(iter.next(), Some((3, &2.)));
/// assert_eq!(iter.next(), Some((5, &3.)));
/// assert_eq!(iter.next(), Some((6, &1.)));
/// assert_eq!(iter.next(), None);
/// ```
use std::iter::{Enumerate, FilterMap, IntoIterator, Peekable, Sum, Zip};
use std::marker::PhantomData;
use std::ops::{
    Add, Deref, DerefMut, DivAssign, Index, IndexMut, Mul, MulAssign, Neg, Sub,
};
use std::slice::{Iter, IterMut};

use num_traits::{Float, Signed, Zero};

use crate::array_backend::Array2;
use crate::errors::StructureError;
use crate::indexing::SpIndex;
use crate::sparse::csmat::CompressedStorage::{CSC, CSR};
use crate::sparse::permutation::PermViewI;
use crate::sparse::prelude::*;
use crate::sparse::utils;
use crate::sparse::{binop, prod};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
/// Hold the index of a non-zero element in the compressed storage
///
/// An `NnzIndex` can be used to later access the non-zero element in constant
/// time.
pub struct NnzIndex(pub usize);

/// A trait to represent types which can be interpreted as vectors
/// of a given dimension.
pub trait VecDim<N> {
    /// The dimension of the vector
    fn dim(&self) -> usize;
}

impl<N, I: SpIndex, IS: Deref<Target = [I]>, DS: Deref<Target = [N]>> VecDim<N>
    for CsVecBase<IS, DS, N, I>
{
    fn dim(&self) -> usize {
        self.dim
    }
}

impl<N, T: ?Sized> VecDim<N> for T
where
    T: AsRef<[N]>,
{
    fn dim(&self) -> usize {
        self.as_ref().len()
    }
}

/// An iterator over the non-zero elements of a sparse vector
#[derive(Clone)]
pub struct VectorIterator<'a, N: 'a, I: 'a> {
    ind_data: Zip<Iter<'a, I>, Iter<'a, N>>,
}

pub struct VectorIteratorPerm<'a, N: 'a, I: 'a> {
    ind_data: Zip<Iter<'a, I>, Iter<'a, N>>,
    perm: PermViewI<'a, I>,
}

/// An iterator over the mutable non-zero elements of a sparse vector
pub struct VectorIteratorMut<'a, N: 'a, I: 'a> {
    ind_data: Zip<Iter<'a, I>, IterMut<'a, N>>,
}

impl<'a, N: 'a, I: 'a + SpIndex> Iterator for VectorIterator<'a, N, I> {
    type Item = (usize, &'a N);

    fn next(&mut self) -> Option<<Self as Iterator>::Item> {
        self.ind_data
            .next()
            .map(|(inner_ind, data)| (inner_ind.index_unchecked(), data))
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.ind_data.size_hint()
    }
}

impl<'a, N: 'a, I: 'a + SpIndex> Iterator for VectorIteratorPerm<'a, N, I> {
    type Item = (usize, &'a N);

    fn next(&mut self) -> Option<<Self as Iterator>::Item> {
        match self.ind_data.next() {
            None => None,
            Some((inner_ind, data)) => {
                Some((self.perm.at(inner_ind.index_unchecked()), data))
            }
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.ind_data.size_hint()
    }
}

impl<'a, N: 'a, I: 'a + SpIndex> Iterator for VectorIteratorMut<'a, N, I> {
    type Item = (usize, &'a mut N);

    fn next(&mut self) -> Option<<Self as Iterator>::Item> {
        self.ind_data
            .next()
            .map(|(inner_ind, data)| (inner_ind.index_unchecked(), data))
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.ind_data.size_hint()
    }
}

pub trait SparseIterTools: Iterator {
    /// Iterate over non-zero elements of either of two vectors.
    /// This is useful for implementing eg addition of vectors.
    ///
    /// # Example
    ///
    /// ```rust
    /// use sprs::CsVec;
    /// use sprs::vec::NnzEither;
    /// use sprs::vec::SparseIterTools;
    /// let v0 = CsVec::new(5, vec![0, 2, 4], vec![1., 2., 3.]);
    /// let v1 = CsVec::new(5, vec![1, 2, 3], vec![-1., -2., -3.]);
    /// let mut nnz_or_iter = v0.iter().nnz_or_zip(v1.iter());
    /// assert_eq!(nnz_or_iter.next(), Some(NnzEither::Left((0, &1.))));
    /// assert_eq!(nnz_or_iter.next(), Some(NnzEither::Right((1, &-1.))));
    /// assert_eq!(nnz_or_iter.next(), Some(NnzEither::Both((2, &2., &-2.))));
    /// assert_eq!(nnz_or_iter.next(), Some(NnzEither::Right((3, &-3.))));
    /// assert_eq!(nnz_or_iter.next(), Some(NnzEither::Left((4, &3.))));
    /// assert_eq!(nnz_or_iter.next(), None);
    /// ```
    fn nnz_or_zip<'a, I, N1, N2>(
        self,
        other: I,
    ) -> NnzOrZip<'a, Self, I::IntoIter, N1, N2>
    where
        Self: Iterator<Item = (usize, &'a N1)> + Sized,
        I: IntoIterator<Item = (usize, &'a N2)>,
    {
        NnzOrZip {
            left: self.peekable(),
            right: other.into_iter().peekable(),
            life: PhantomData,
        }
    }

    /// Iterate over the matching non-zero elements of both vectors
    /// Useful for vector dot product.
    ///
    /// # Example
    ///
    /// ```rust
    /// use sprs::CsVec;
    /// use sprs::vec::SparseIterTools;
    /// let v0 = CsVec::new(5, vec![0, 2, 4], vec![1., 2., 3.]);
    /// let v1 = CsVec::new(5, vec![1, 2, 3], vec![-1., -2., -3.]);
    /// let mut nnz_zip = v0.iter().nnz_zip(v1.iter());
    /// assert_eq!(nnz_zip.next(), Some((2, &2., &-2.)));
    /// assert_eq!(nnz_zip.next(), None);
    /// ```
    #[allow(clippy::type_complexity)]
    fn nnz_zip<'a, I, N1, N2>(
        self,
        other: I,
    ) -> FilterMap<
        NnzOrZip<'a, Self, I::IntoIter, N1, N2>,
        fn(NnzEither<'a, N1, N2>) -> Option<(usize, &'a N1, &'a N2)>,
    >
    where
        Self: Iterator<Item = (usize, &'a N1)> + Sized,
        I: IntoIterator<Item = (usize, &'a N2)>,
    {
        let nnz_or_iter = NnzOrZip {
            left: self.peekable(),
            right: other.into_iter().peekable(),
            life: PhantomData,
        };
        nnz_or_iter.filter_map(filter_both_nnz)
    }
}

impl<T: Iterator> SparseIterTools for Enumerate<T> {}

impl<'a, N: 'a, I: 'a + SpIndex> SparseIterTools for VectorIterator<'a, N, I> {}

/// Trait for types that can be iterated as sparse vectors
pub trait IntoSparseVecIter<'a, N: 'a> {
    type IterType;

    /// Transform self into an iterator that yields (usize, &N) tuples
    /// where the usize is the index of the value in the sparse vector.
    /// The indices should be sorted.
    fn into_sparse_vec_iter(
        self,
    ) -> <Self as IntoSparseVecIter<'a, N>>::IterType
    where
        <Self as IntoSparseVecIter<'a, N>>::IterType:
            Iterator<Item = (usize, &'a N)>;

    /// The dimension of the vector
    fn dim(&self) -> usize;

    /// Indicator to check whether the vector is actually dense
    fn is_dense(&self) -> bool {
        false
    }

    /// Random access to an element in the vector.
    ///
    /// # Panics
    ///
    /// - if the vector is not dense
    /// - if the index is out of bounds
    #[allow(unused_variables)]
    fn index(self, idx: usize) -> &'a N
    where
        Self: Sized,
    {
        panic!("cannot be called on a vector that is not dense");
    }
}

impl<'a, N: 'a, I: 'a> IntoSparseVecIter<'a, N> for CsVecViewI<'a, N, I>
where
    I: SpIndex,
{
    type IterType = VectorIterator<'a, N, I>;

    fn dim(&self) -> usize {
        self.dim()
    }

    fn into_sparse_vec_iter(self) -> VectorIterator<'a, N, I> {
        self.iter_rbr()
    }
}

impl<'a, N: 'a, I: 'a, IS, DS> IntoSparseVecIter<'a, N>
    for &'a CsVecBase<IS, DS, N, I>
where
    I: SpIndex,
    IS: Deref<Target = [I]>,
    DS: Deref<Target = [N]>,
{
    type IterType = VectorIterator<'a, N, I>;

    fn dim(&self) -> usize {
        (*self).dim()
    }

    fn into_sparse_vec_iter(self) -> VectorIterator<'a, N, I> {
        self.iter()
    }
}

impl<'a, N: 'a, V: ?Sized> IntoSparseVecIter<'a, N> for &'a V
where
    V: DenseVector<Scalar = N>,
{
    // FIXME we want
    // type IterType = impl Iterator<Item=(usize, &'a N)>
    #[allow(clippy::type_complexity)]
    type IterType = std::iter::Map<
        std::iter::Zip<std::iter::Repeat<Self>, std::ops::Range<usize>>,
        fn((&'a V, usize)) -> (usize, &'a N),
    >;

    #[inline(always)]
    fn into_sparse_vec_iter(self) -> Self::IterType {
        // FIXME since it's not possible to have an existential type as an
        // associated type yet, I'm using a trick to send the necessary
        // context to a plain function, which enables specifying the type
        // Needless to say, this needs to go when it's no longer necessary
        #[inline(always)]
        fn hack_instead_of_closure<N, V: ?Sized>(vi: (&V, usize)) -> (usize, &N)
        where
            V: DenseVector<Scalar = N>,
        {
            (vi.1, vi.0.index(vi.1))
        }
        let n = DenseVector::dim(self);
        std::iter::repeat(self)
            .zip(0..n)
            .map(hack_instead_of_closure)
    }

    fn dim(&self) -> usize {
        DenseVector::dim(*self)
    }

    fn is_dense(&self) -> bool {
        true
    }

    #[inline(always)]
    fn index(self, idx: usize) -> &'a N {
        DenseVector::index(self, idx)
    }
}

/// An iterator over the non zeros of either of two vector iterators, ordered,
/// such that the sum of the vectors may be computed
pub struct NnzOrZip<'a, Ite1, Ite2, N1: 'a, N2: 'a>
where
    Ite1: Iterator<Item = (usize, &'a N1)>,
    Ite2: Iterator<Item = (usize, &'a N2)>,
{
    left: Peekable<Ite1>,
    right: Peekable<Ite2>,
    life: PhantomData<(&'a N1, &'a N2)>,
}

#[derive(PartialEq, Eq, Debug)]
pub enum NnzEither<'a, N1: 'a, N2: 'a> {
    Both((usize, &'a N1, &'a N2)),
    Left((usize, &'a N1)),
    Right((usize, &'a N2)),
}

fn filter_both_nnz<'a, N: 'a, M: 'a>(
    elem: NnzEither<'a, N, M>,
) -> Option<(usize, &'a N, &'a M)> {
    match elem {
        NnzEither::Both((ind, lval, rval)) => Some((ind, lval, rval)),
        _ => None,
    }
}

impl<'a, Ite1, Ite2, N1: 'a, N2: 'a> Iterator
    for NnzOrZip<'a, Ite1, Ite2, N1, N2>
where
    Ite1: Iterator<Item = (usize, &'a N1)>,
    Ite2: Iterator<Item = (usize, &'a N2)>,
{
    type Item = NnzEither<'a, N1, N2>;

    fn next(&mut self) -> Option<NnzEither<'a, N1, N2>> {
        use NnzEither::{Both, Left, Right};
        match (self.left.peek(), self.right.peek()) {
            (None, Some(&(_, _))) => {
                let (rind, rval) = self.right.next().unwrap();
                Some(Right((rind, rval)))
            }
            (Some(&(_, _)), None) => {
                let (lind, lval) = self.left.next().unwrap();
                Some(Left((lind, lval)))
            }
            (None, None) => None,
            (Some(&(lind, _)), Some(&(rind, _))) => match lind.cmp(&rind) {
                std::cmp::Ordering::Less => {
                    let (lind, lval) = self.left.next().unwrap();
                    Some(Left((lind, lval)))
                }
                std::cmp::Ordering::Greater => {
                    let (rind, rval) = self.right.next().unwrap();
                    Some(Right((rind, rval)))
                }
                std::cmp::Ordering::Equal => {
                    let (lind, lval) = self.left.next().unwrap();
                    let (_, rval) = self.right.next().unwrap();
                    Some(Both((lind, lval, rval)))
                }
            },
        }
    }

    #[inline]
    fn size_hint(&self) -> (usize, Option<usize>) {
        let (left_lower, left_upper) = self.left.size_hint();
        let (right_lower, right_upper) = self.right.size_hint();
        let upper = match (left_upper, right_upper) {
            (Some(x), Some(y)) => Some(x + y),
            (Some(x), None) => Some(x),
            (None, Some(y)) => Some(y),
            (None, None) => None,
        };
        (cmp::max(left_lower, right_lower), upper)
    }
}

/// # Constructor methods
impl<N, I: SpIndex, DStorage, IStorage> CsVecBase<IStorage, DStorage, N, I>
where
    DStorage: std::ops::Deref<Target = [N]>,
    IStorage: std::ops::Deref<Target = [I]>,
{
    /// Create a sparse vector
    ///
    /// # Panics
    ///
    /// - if `indices` and `data` lengths differ
    /// - if the vector contains out of bounds indices
    /// - if indices are out of order
    ///
    /// # Examples
    /// ```rust
    /// # use sprs::*;
    /// // Creating a sparse owned vector
    /// let owned = CsVec::new(10, vec![0, 4], vec![-4, 2]);
    /// // Creating a sparse borrowing vector with `I = u16`
    /// let borrow = CsVecViewI::new(10, &[0_u16, 4], &[-4, 2]);
    /// // Creating a general sparse vector with different storage types
    /// let mixed = CsVecBase::new(10, &[0_u64, 4] as &[_], vec![-4, 2]);
    /// ```
    pub fn new(n: usize, indices: IStorage, data: DStorage) -> Self {
        Self::try_new(n, indices, data)
            .map_err(|(_, _, e)| e)
            .unwrap()
    }

    /// Try create a sparse vector from the given buffers
    ///
    /// Will return the buffers along with the error if
    /// conversion is illegal
    pub fn try_new(
        n: usize,
        indices: IStorage,
        data: DStorage,
    ) -> Result<Self, (IStorage, DStorage, StructureError)> {
        if I::from(n).is_none() {
            return Err((
                indices,
                data,
                StructureError::OutOfRange("Index size is too small"),
            ));
        }
        if indices.len() != data.len() {
            return Err((
                indices,
                data,
                StructureError::SizeMismatch(
                    "indices and data do not have compatible lengths",
                ),
            ));
        }
        for i in indices.iter() {
            if i.to_usize().is_none() {
                return Err((
                    indices,
                    data,
                    StructureError::OutOfRange(
                        "index can not be converted to usize",
                    ),
                ));
            }
        }
        if !utils::sorted_indices(indices.as_ref()) {
            return Err((
                indices,
                data,
                StructureError::Unsorted("Unsorted indices"),
            ));
        }
        if let Some(i) = indices.last() {
            if i.to_usize().unwrap() >= n {
                return Err((
                    indices,
                    data,
                    StructureError::SizeMismatch(
                        "indices larger than vector size",
                    ),
                ));
            }
        }
        Ok(Self::new_trusted(n, indices, data))
    }

    /// Internal version of `new_unchecked` where we guarantee the invariants
    /// ourselves
    pub(crate) fn new_trusted(
        n: usize,
        indices: IStorage,
        data: DStorage,
    ) -> Self {
        Self {
            dim: n,
            indices,
            data,
        }
    }

    /// Create a `CsVec` without checking the structure
    ///
    /// # Safety
    ///
    /// This is unsafe because algorithms are free to assume
    /// that properties guaranteed by [`check_structure`](CsVecBase::check_structure) are enforced.
    /// For instance, non out-of-bounds indices can be relied upon to
    /// perform unchecked slice access.
    pub unsafe fn new_uncheked(
        n: usize,
        indices: IStorage,
        data: DStorage,
    ) -> Self {
        Self {
            dim: n,
            indices,
            data,
        }
    }
}

impl<N, I: SpIndex, DStorage, IStorage> CsVecBase<IStorage, DStorage, N, I>
where
    DStorage: std::ops::DerefMut<Target = [N]>,
    IStorage: std::ops::DerefMut<Target = [I]>,
{
    /// Creates a sparse vector
    ///
    /// Will sort indices and data if necessary
    pub fn new_from_unsorted(
        n: usize,
        indices: IStorage,
        data: DStorage,
    ) -> Result<Self, (IStorage, DStorage, StructureError)>
    where
        N: Clone,
    {
        let v = Self::try_new(n, indices, data);
        match v {
            Err((mut indices, mut data, StructureError::Unsorted(_))) => {
                let mut buf = Vec::with_capacity(indices.len());
                utils::sort_indices_data_slices(
                    &mut indices[..],
                    &mut data[..],
                    &mut buf,
                );
                Self::try_new(n, indices, data)
            }
            v => v,
        }
    }
}

/// # Methods operating on owning sparse vectors
impl<N, I: SpIndex> CsVecI<N, I> {
    /// Create an empty `CsVec`, which can be used for incremental construction
    pub fn empty(dim: usize) -> Self {
        Self::new_trusted(dim, vec![], vec![])
    }

    /// Append an element to the sparse vector. Used for incremental
    /// building of the `CsVec`. The append should preserve the structure
    /// of the vector, ie the newly added index should be strictly greater
    /// than the last element of indices.
    ///
    /// # Panics
    ///
    /// - Panics if `ind` is lower or equal to the last
    ///   element of `self.indices()`
    /// - Panics if `ind` is greater than `self.dim()`
    pub fn append(&mut self, ind: usize, val: N) {
        match self.indices.last() {
            None => (),
            Some(&last_ind) => {
                assert!(ind > last_ind.index_unchecked(), "unsorted append");
            }
        }
        assert!(ind <= self.dim, "out of bounds index");
        self.indices.push(I::from_usize(ind));
        self.data.push(val);
    }

    /// Reserve `size` additional non-zero values.
    pub fn reserve(&mut self, size: usize) {
        self.indices.reserve(size);
        self.data.reserve(size);
    }

    /// Reserve exactly `exact_size` non-zero values.
    pub fn reserve_exact(&mut self, exact_size: usize) {
        self.indices.reserve_exact(exact_size);
        self.data.reserve_exact(exact_size);
    }

    /// Clear the underlying storage
    pub fn clear(&mut self) {
        self.indices.clear();
        self.data.clear();
    }
}

/// # Common methods of sparse vectors
impl<N, I, IStorage, DStorage> CsVecBase<IStorage, DStorage, N, I>
where
    I: SpIndex,
    IStorage: Deref<Target = [I]>,
    DStorage: Deref<Target = [N]>,
{
    /// Get a view of this vector.
    pub fn view(&self) -> CsVecViewI<N, I> {
        CsVecViewI::new_trusted(self.dim, &self.indices[..], &self.data)
    }

    /// Convert the sparse vector to a dense one
    pub fn to_dense(&self) -> Array<N, Ix1>
    where
        N: Clone + Zero,
    {
        let mut res = Array::zeros(self.dim());
        assign_vector_to_dense(res.view_mut(), self.view());
        res
    }

    /// Iterate over the non zero values.
    ///
    /// # Example
    ///
    /// ```rust
    /// use sprs::CsVec;
    /// let v = CsVec::new(5, vec![0, 2, 4], vec![1., 2., 3.]);
    /// let mut iter = v.iter();
    /// assert_eq!(iter.next(), Some((0, &1.)));
    /// assert_eq!(iter.next(), Some((2, &2.)));
    /// assert_eq!(iter.next(), Some((4, &3.)));
    /// assert_eq!(iter.next(), None);
    /// ```
    pub fn iter(&self) -> VectorIterator<N, I> {
        VectorIterator {
            ind_data: self.indices.iter().zip(self.data.iter()),
        }
    }

    /// Permuted iteration. Not finished
    #[doc(hidden)]
    pub fn iter_perm<'a, 'perm: 'a>(
        &'a self,
        perm: PermViewI<'perm, I>,
    ) -> VectorIteratorPerm<'a, N, I>
    where
        N: 'a,
    {
        VectorIteratorPerm {
            ind_data: self.indices.iter().zip(self.data.iter()),
            perm,
        }
    }

    /// The underlying indices.
    pub fn indices(&self) -> &[I] {
        &self.indices
    }

    /// The underlying non zero values.
    pub fn data(&self) -> &[N] {
        &self.data
    }

    /// Destruct the vector object and recycle its storage containers.
    pub fn into_raw_storage(self) -> (IStorage, DStorage) {
        let Self { indices, data, .. } = self;
        (indices, data)
    }

    /// The dimension of this vector.
    pub fn dim(&self) -> usize {
        self.dim
    }

    /// The non zero count of this vector.
    pub fn nnz(&self) -> usize {
        self.data.len()
    }

    /// Check the sparse structure, namely that:
    /// - indices are sorted
    /// - all indices are less than dims()
    pub fn check_structure(&self) -> Result<(), StructureError> {
        // Make sure indices can be converted to usize
        for i in self.indices.iter() {
            i.index();
        }
        if !utils::sorted_indices(&self.indices) {
            return Err(StructureError::Unsorted("Unsorted indices"));
        }

        if self.dim == 0 && self.indices.len() == 0 && self.data.len() == 0 {
            return Ok(());
        }

        let max_ind = self
            .indices
            .iter()
            .max()
            .unwrap_or(&I::zero())
            .index_unchecked();
        if max_ind >= self.dim {
            return Err(StructureError::OutOfRange("Out of bounds index"));
        }

        Ok(())
    }

    /// Allocate a new vector equal to this one.
    pub fn to_owned(&self) -> CsVecI<N, I>
    where
        N: Clone,
    {
        CsVecI::new_trusted(self.dim, self.indices.to_vec(), self.data.to_vec())
    }

    /// Clone the vector with another integer type for its indices
    ///
    /// # Panics
    ///
    /// If the indices cannot be represented by the requested integer type.
    pub fn to_other_types<I2>(&self) -> CsVecI<N, I2>
    where
        N: Clone,
        I2: SpIndex,
    {
        let indices = self
            .indices
            .iter()
            .map(|i| I2::from_usize(i.index_unchecked()))
            .collect();
        let data = self.data.iter().cloned().collect();
        CsVecI::new_trusted(self.dim, indices, data)
    }

    /// View this vector as a matrix with only one row.
    pub fn row_view<Iptr: SpIndex>(&self) -> CsMatVecView_<N, I, Iptr> {
        // Safe because we're taking a view into a vector that has
        // necessarily been checked
        let indptr = Array2 {
            data: [
                Iptr::zero(),
                Iptr::from_usize_unchecked(self.indices.len()),
            ],
        };
        CsMatBase {
            storage: CSR,
            nrows: 1,
            ncols: self.dim,
            indptr: crate::IndPtrBase::new_trusted(indptr),
            indices: &self.indices[..],
            data: &self.data[..],
        }
    }

    /// View this vector as a matrix with only one column.
    pub fn col_view<Iptr: SpIndex>(&self) -> CsMatVecView_<N, I, Iptr> {
        // Safe because we're taking a view into a vector that has
        // necessarily been checked
        let indptr = Array2 {
            data: [
                Iptr::zero(),
                Iptr::from_usize_unchecked(self.indices.len()),
            ],
        };
        CsMatBase {
            storage: CSC,
            nrows: self.dim,
            ncols: 1,
            indptr: crate::IndPtrBase::new_trusted(indptr),
            indices: &self.indices[..],
            data: &self.data[..],
        }
    }

    /// Access element at given index, with logarithmic complexity
    pub fn get<'a>(&'a self, index: usize) -> Option<&'a N>
    where
        I: 'a,
    {
        self.view().get_rbr(index)
    }

    /// Find the non-zero index of the requested dimension index,
    /// returning None if no non-zero is present at the requested location.
    ///
    /// Looking for the `NnzIndex` is done with logarithmic complexity, but
    /// once it is available, the `NnzIndex` enables retrieving the data with
    /// O(1) complexity.
    pub fn nnz_index(&self, index: usize) -> Option<NnzIndex> {
        self.indices
            .binary_search(&I::from_usize(index))
            .map(|i| NnzIndex(i.index_unchecked()))
            .ok()
    }

    /// Sparse vector dot product. The right-hand-side can be any type
    /// that can be interpreted as a sparse vector (hence sparse vectors, std
    /// vectors and slices, and ndarray's dense vectors work).
    ///
    /// However, even if dense vectors work, it is more performant to use
    /// the [`dot_dense`](struct.CsVecBase.html#method.dot_dense).
    ///
    /// # Panics
    ///
    /// If the dimension of the vectors do not match.
    ///
    /// # Example
    ///
    /// ```rust
    /// use sprs::CsVec;
    /// let v1 = CsVec::new(8, vec![1, 2, 4, 6], vec![1.; 4]);
    /// let v2 = CsVec::new(8, vec![1, 3, 5, 7], vec![2.; 4]);
    /// assert_eq!(2., v1.dot(&v2));
    /// assert_eq!(4., v1.dot(&v1));
    /// assert_eq!(16., v2.dot(&v2));
    /// ```
    pub fn dot<'b, T: IntoSparseVecIter<'b, N>>(&'b self, rhs: T) -> N
    where
        N: 'b + crate::MulAcc + num_traits::Zero,
        I: 'b,
        <T as IntoSparseVecIter<'b, N>>::IterType:
            Iterator<Item = (usize, &'b N)>,
        T: Copy, // T is supposed to be a reference type
    {
        self.dot_acc(rhs)
    }

    /// Sparse vector dot product into accumulator.
    ///
    /// The right-hand-side can be any type
    /// that can be interpreted as a sparse vector (hence sparse vectors, std
    /// vectors and slices, and ndarray's dense vectors work).
    /// The output type can be any type supporting `MulAcc`.
    pub fn dot_acc<'b, T: IntoSparseVecIter<'b, M>, M, Acc>(
        &'b self,
        rhs: T,
    ) -> Acc
    where
        Acc: 'b + crate::MulAcc<N, M> + num_traits::Zero,
        M: 'b,
        <T as IntoSparseVecIter<'b, M>>::IterType:
            Iterator<Item = (usize, &'b M)>,
        T: Copy, // T is supposed to be a reference type
    {
        assert_eq!(self.dim(), rhs.dim());
        let mut sum = Acc::zero();
        if rhs.is_dense() {
            self.iter().for_each(|(idx, val)| {
                sum.mul_acc(val, rhs.index(idx.index_unchecked()));
            });
        } else {
            let mut lhs_iter = self.iter();
            let mut rhs_iter = rhs.into_sparse_vec_iter();
            let mut left_nnz = lhs_iter.next();
            let mut right_nnz = rhs_iter.next();
            while left_nnz.is_some() && right_nnz.is_some() {
                let (left_ind, left_val) = left_nnz.unwrap();
                let (right_ind, right_val) = right_nnz.unwrap();
                if left_ind == right_ind {
                    sum.mul_acc(left_val, right_val);
                }
                if left_ind <= right_ind {
                    left_nnz = lhs_iter.next();
                }
                if left_ind >= right_ind {
                    right_nnz = rhs_iter.next();
                }
            }
        }
        sum
    }

    /// Sparse-dense vector dot product. The right-hand-side can be any type
    /// that can be interpreted as a dense vector (hence std vectors and
    /// slices, and ndarray's dense vectors work).
    ///
    /// Since the `dot` method can work with the same performance on
    /// dot vectors, the main interest of this method is to enforce at
    /// compile time that the rhs is dense.
    ///
    /// # Panics
    ///
    /// If the dimension of the vectors do not match.
    pub fn dot_dense<V>(&self, rhs: V) -> N
    where
        V: DenseVector<Scalar = N>,
        N: Sum,
        for<'r> &'r N: Mul<&'r N, Output = N>,
    {
        assert_eq!(self.dim(), rhs.dim());
        self.iter()
            .map(|(idx, val)| val * rhs.index(idx.index_unchecked()))
            .sum()
    }

    /// Compute the squared L2-norm.
    pub fn squared_l2_norm(&self) -> N
    where
        N: Sum,
        for<'r> &'r N: Mul<&'r N, Output = N>,
    {
        self.data.iter().map(|x| x * x).sum()
    }

    /// Compute the L2-norm.
    pub fn l2_norm(&self) -> N
    where
        N: Float + Sum,
        for<'r> &'r N: Mul<&'r N, Output = N>,
    {
        self.squared_l2_norm().sqrt()
    }

    /// Compute the L1-norm.
    pub fn l1_norm(&self) -> N
    where
        N: Signed + Sum,
    {
        self.data.iter().map(Signed::abs).sum()
    }

    /// Compute the vector norm for the given order p.
    ///
    /// The norm for vector v is defined as:
    /// - If p = ∞: maxᵢ |vᵢ|
    /// - If p = -∞: minᵢ |vᵢ|
    /// - If p = 0: ∑ᵢ[vᵢ≠0]
    /// - Otherwise: ᵖ√(∑ᵢ|vᵢ|ᵖ)
    pub fn norm(&self, p: N) -> N
    where
        N: Float + Sum,
    {
        let abs_val_iter = self.data.iter().map(|x| x.abs());
        if p.is_infinite() {
            if self.data.is_empty() {
                N::zero()
            } else if p.is_sign_positive() {
                abs_val_iter.fold(N::neg_infinity(), N::max)
            } else {
                abs_val_iter.fold(N::infinity(), N::min)
            }
        } else if p.is_zero() {
            N::from(abs_val_iter.filter(|x| !x.is_zero()).count())
                .expect("Conversion from usize to a Float type should not fail")
        } else {
            abs_val_iter.map(|x| x.powf(p)).sum::<N>().powf(p.powi(-1))
        }
    }

    /// Fill a dense vector with our values
    // FIXME I'm uneasy with this &mut V, can't I get rid of it with more
    // trait magic? I would probably need to define what a mutable view is...
    // But it's valuable. But I cannot find a way with the current trait system.
    // Would probably require something link existential lifetimes.
    pub fn scatter<V>(&self, out: &mut V)
    where
        N: Clone,
        V: DenseVectorMut<Scalar = N> + ?Sized,
    {
        for (ind, val) in self.iter() {
            *out.index_mut(ind) = val.clone();
        }
    }

    /// Transform this vector into a set of (index, value) tuples
    pub fn to_set(&self) -> HashSet<(usize, N)>
    where
        N: Hash + Eq + Clone,
    {
        self.indices()
            .iter()
            .map(|i| i.index_unchecked())
            .zip(self.data.iter().cloned())
            .collect()
    }

    /// Apply a function to each non-zero element, yielding a new matrix
    /// with the same sparsity structure.
    pub fn map<F>(&self, f: F) -> CsVecI<N, I>
    where
        F: FnMut(&N) -> N,
        N: Clone,
    {
        let mut res = self.to_owned();
        res.map_inplace(f);
        res
    }
}

/// # Methods on sparse vectors with mutable access to their data
impl<'a, N, I, IStorage, DStorage> CsVecBase<IStorage, DStorage, N, I>
where
    N: 'a,
    I: 'a + SpIndex,
    IStorage: 'a + Deref<Target = [I]>,
    DStorage: DerefMut<Target = [N]>,
{
    /// The underlying non zero values as a mutable slice.
    fn data_mut(&mut self) -> &mut [N] {
        &mut self.data[..]
    }

    pub fn view_mut(&mut self) -> CsVecViewMutI<N, I> {
        CsVecViewMutI::new_trusted(
            self.dim,
            &self.indices[..],
            &mut self.data[..],
        )
    }

    /// Access element at given index, with logarithmic complexity
    pub fn get_mut(&mut self, index: usize) -> Option<&mut N> {
        if let Some(NnzIndex(position)) = self.nnz_index(index) {
            Some(&mut self.data[position])
        } else {
            None
        }
    }

    /// Apply a function to each non-zero element, mutating it
    pub fn map_inplace<F>(&mut self, mut f: F)
    where
        F: FnMut(&N) -> N,
    {
        for val in &mut self.data[..] {
            *val = f(val);
        }
    }

    /// Mutable iteration over the non-zero values of a sparse vector
    ///
    /// Only the values can be changed, the sparse structure is kept.
    pub fn iter_mut(&mut self) -> VectorIteratorMut<N, I> {
        VectorIteratorMut {
            ind_data: self.indices.iter().zip(self.data.iter_mut()),
        }
    }

    /// Divides the vector by its own L2-norm.
    ///
    /// Zero vector is left unchanged.
    pub fn unit_normalize(&mut self)
    where
        N: Float + Sum,
        for<'r> &'r N: Mul<&'r N, Output = N>,
    {
        let norm_sq = self.squared_l2_norm();
        if norm_sq > N::zero() {
            let norm = norm_sq.sqrt();
            self.map_inplace(|x| *x / norm);
        }
    }
}

/// # Methods propagating the lifetime of a `CsVecViewI`.
impl<'a, N: 'a, I: 'a + SpIndex> CsVecViewI<'a, N, I> {
    /// Access element at given index, with logarithmic complexity
    ///
    /// Re-borrowing version of `at()`.
    pub fn get_rbr(&self, index: usize) -> Option<&'a N> {
        self.nnz_index(index)
            .map(|NnzIndex(position)| &self.data[position])
    }

    /// Re-borrowing version of `iter()`. Namely, the iterator's lifetime
    /// will be bound to the lifetime of the underlying slices instead
    /// of being bound to the lifetime of the borrow.
    fn iter_rbr(&self) -> VectorIterator<'a, N, I> {
        VectorIterator {
            ind_data: self.indices.iter().zip(self.data.iter()),
        }
    }
}

impl<'a, 'b, N, I, Iptr, IS1, DS1, IpS2, IS2, DS2>
    Mul<&'b CsMatBase<N, I, IpS2, IS2, DS2, Iptr>>
    for &'a CsVecBase<IS1, DS1, N, I>
where
    N: 'a + Clone + crate::MulAcc + num_traits::Zero + Default + Send + Sync,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IS1: 'a + Deref<Target = [I]>,
    DS1: 'a + Deref<Target = [N]>,
    IpS2: 'b + Deref<Target = [Iptr]>,
    IS2: 'b + Deref<Target = [I]>,
    DS2: 'b + Deref<Target = [N]>,
{
    type Output = CsVecI<N, I>;

    fn mul(self, rhs: &CsMatBase<N, I, IpS2, IS2, DS2, Iptr>) -> Self::Output {
        (&self.row_view() * rhs).outer_view(0).unwrap().to_owned()
    }
}

impl<'a, 'b, N, I, Iptr, IpS1, IS1, DS1, IS2, DS2>
    Mul<&'b CsVecBase<IS2, DS2, N, I>>
    for &'a CsMatBase<N, I, IpS1, IS1, DS1, Iptr>
where
    N: Clone
        + crate::MulAcc
        + num_traits::Zero
        + PartialEq
        + Default
        + Send
        + Sync,
    I: SpIndex,
    Iptr: SpIndex,
    IpS1: Deref<Target = [Iptr]>,
    IS1: Deref<Target = [I]>,
    DS1: Deref<Target = [N]>,
    IS2: Deref<Target = [I]>,
    DS2: Deref<Target = [N]>,
{
    type Output = CsVecI<N, I>;

    fn mul(self, rhs: &CsVecBase<IS2, DS2, N, I>) -> Self::Output {
        if self.is_csr() {
            prod::csr_mul_csvec(self.view(), rhs.view())
        } else {
            self.mul(&rhs.col_view()).outer_view(0).unwrap().to_owned()
        }
    }
}

impl<Lhs, Rhs, Res, I, IS1, DS1, IS2, DS2> Add<CsVecBase<IS2, DS2, Rhs, I>>
    for CsVecBase<IS1, DS1, Lhs, I>
where
    Lhs: Zero,
    Rhs: Zero,
    for<'r> &'r Lhs: Add<&'r Rhs, Output = Res>,
    I: SpIndex,
    IS1: Deref<Target = [I]>,
    DS1: Deref<Target = [Lhs]>,
    IS2: Deref<Target = [I]>,
    DS2: Deref<Target = [Rhs]>,
{
    type Output = CsVecI<Res, I>;

    fn add(self, rhs: CsVecBase<IS2, DS2, Rhs, I>) -> Self::Output {
        &self + &rhs
    }
}

impl<'a, Lhs, Rhs, Res, I, IS1, DS1, IS2, DS2>
    Add<&'a CsVecBase<IS2, DS2, Rhs, I>> for CsVecBase<IS1, DS1, Lhs, I>
where
    Lhs: Zero,
    Rhs: Zero,
    for<'r> &'r Lhs: Add<&'r Rhs, Output = Res>,
    I: SpIndex,
    IS1: Deref<Target = [I]>,
    DS1: Deref<Target = [Lhs]>,
    IS2: Deref<Target = [I]>,
    DS2: Deref<Target = [Rhs]>,
{
    type Output = CsVecI<Res, I>;

    fn add(self, rhs: &CsVecBase<IS2, DS2, Rhs, I>) -> Self::Output {
        &self + rhs
    }
}

impl<'a, Lhs, Rhs, Res, I, IS1, DS1, IS2, DS2> Add<CsVecBase<IS2, DS2, Rhs, I>>
    for &'a CsVecBase<IS1, DS1, Lhs, I>
where
    Lhs: Zero,
    Rhs: Zero,
    for<'r> &'r Lhs: Add<&'r Rhs, Output = Res>,
    I: SpIndex,
    IS1: Deref<Target = [I]>,
    DS1: Deref<Target = [Lhs]>,
    IS2: Deref<Target = [I]>,
    DS2: Deref<Target = [Rhs]>,
{
    type Output = CsVecI<Res, I>;

    fn add(self, rhs: CsVecBase<IS2, DS2, Rhs, I>) -> Self::Output {
        self + &rhs
    }
}

impl<'a, 'b, Lhs, Rhs, Res, I, IS1, DS1, IS2, DS2>
    Add<&'b CsVecBase<IS2, DS2, Rhs, I>> for &'a CsVecBase<IS1, DS1, Lhs, I>
where
    Lhs: Zero,
    Rhs: Zero,
    for<'r> &'r Lhs: Add<&'r Rhs, Output = Res>,
    I: SpIndex,
    IS1: Deref<Target = [I]>,
    DS1: Deref<Target = [Lhs]>,
    IS2: Deref<Target = [I]>,
    DS2: Deref<Target = [Rhs]>,
{
    type Output = CsVecI<Res, I>;

    fn add(self, rhs: &CsVecBase<IS2, DS2, Rhs, I>) -> Self::Output {
        binop::csvec_binop(self.view(), rhs.view(), |x, y| x + y).unwrap()
    }
}

impl<'a, 'b, Lhs, Rhs, Res, I, IS1, DS1, IS2, DS2>
    Sub<&'b CsVecBase<IS2, DS2, Rhs, I>> for &'a CsVecBase<IS1, DS1, Lhs, I>
where
    Lhs: Zero,
    Rhs: Zero,
    for<'r> &'r Lhs: Sub<&'r Rhs, Output = Res>,
    I: SpIndex,
    IS1: Deref<Target = [I]>,
    DS1: Deref<Target = [Lhs]>,
    IS2: Deref<Target = [I]>,
    DS2: Deref<Target = [Rhs]>,
{
    type Output = CsVecI<Res, I>;

    fn sub(self, rhs: &CsVecBase<IS2, DS2, Rhs, I>) -> Self::Output {
        binop::csvec_binop(self.view(), rhs.view(), |x, y| x - y).unwrap()
    }
}

impl<N, I> Neg for CsVecI<N, I>
where
    N: Clone + Neg<Output = N>,
    I: SpIndex,
{
    type Output = Self;

    fn neg(mut self) -> Self::Output {
        for value in &mut self.data {
            *value = -value.clone();
        }
        self
    }
}

impl<N, I, IStorage, DStorage> MulAssign<N>
    for CsVecBase<IStorage, DStorage, N, I>
where
    N: Clone + MulAssign<N>,
    I: SpIndex,
    IStorage: Deref<Target = [I]>,
    DStorage: DerefMut<Target = [N]>,
{
    fn mul_assign(&mut self, rhs: N) {
        self.data_mut()
            .iter_mut()
            .for_each(|v| v.mul_assign(rhs.clone()));
    }
}

impl<N, I, IStorage, DStorage> DivAssign<N>
    for CsVecBase<IStorage, DStorage, N, I>
where
    N: Clone + DivAssign<N>,
    I: SpIndex,
    IStorage: Deref<Target = [I]>,
    DStorage: DerefMut<Target = [N]>,
{
    fn div_assign(&mut self, rhs: N) {
        self.data_mut()
            .iter_mut()
            .for_each(|v| v.div_assign(rhs.clone()));
    }
}

impl<N, IS, DS> Index<usize> for CsVecBase<IS, DS, N>
where
    IS: Deref<Target = [usize]>,
    DS: Deref<Target = [N]>,
{
    type Output = N;

    fn index(&self, index: usize) -> &N {
        self.get(index).unwrap()
    }
}

impl<N, IS, DS> IndexMut<usize> for CsVecBase<IS, DS, N>
where
    IS: Deref<Target = [usize]>,
    DS: DerefMut<Target = [N]>,
{
    fn index_mut(&mut self, index: usize) -> &mut N {
        self.get_mut(index).unwrap()
    }
}

impl<N, IS, DS> Index<NnzIndex> for CsVecBase<IS, DS, N>
where
    IS: Deref<Target = [usize]>,
    DS: Deref<Target = [N]>,
{
    type Output = N;

    fn index(&self, index: NnzIndex) -> &N {
        let NnzIndex(i) = index;
        self.data().get(i).unwrap()
    }
}

impl<N, IS, DS> IndexMut<NnzIndex> for CsVecBase<IS, DS, N>
where
    IS: Deref<Target = [usize]>,
    DS: DerefMut<Target = [N]>,
{
    fn index_mut(&mut self, index: NnzIndex) -> &mut N {
        let NnzIndex(i) = index;
        self.data_mut().get_mut(i).unwrap()
    }
}

impl<N, I> Zero for CsVecI<N, I>
where
    N: Zero + Clone,
    for<'r> &'r N: Add<Output = N>,
    I: SpIndex,
{
    fn zero() -> Self {
        Self::new(0, vec![], vec![])
    }

    fn is_zero(&self) -> bool {
        self.data.iter().all(Zero::is_zero)
    }
}

#[cfg(feature = "alga")]
/// These traits requires the `alga` feature to be activated
mod alga_impls {
    use super::*;
    use alga::general::*;
    use num_traits::Num;

    impl<N, I> AbstractMagma<Additive> for CsVecI<N, I>
    where
        N: Num + Clone,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
        fn operate(&self, right: &Self) -> Self {
            self + right
        }
    }

    impl<N, I> Identity<Additive> for CsVecI<N, I>
    where
        N: Num + Clone,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
        fn identity() -> Self {
            Self::zero()
        }
    }

    impl<N, I> AbstractSemigroup<Additive> for CsVecI<N, I>
    where
        N: Num + Clone,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
    }

    impl<N, I> AbstractMonoid<Additive> for CsVecI<N, I>
    where
        N: Num + Copy,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
    }

    impl<N, I> TwoSidedInverse<Additive> for CsVecI<N, I>
    where
        N: Clone + Neg<Output = N> + Num,
        I: SpIndex,
    {
        fn two_sided_inverse(&self) -> Self {
            Self::new_trusted(
                self.dim,
                self.indices.clone(),
                self.data.iter().map(|x| -x.clone()).collect(),
            )
        }
    }

    impl<N, I> AbstractQuasigroup<Additive> for CsVecI<N, I>
    where
        N: Num + Clone + Neg<Output = N>,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
    }

    impl<N, I> AbstractLoop<Additive> for CsVecI<N, I>
    where
        N: Num + Copy + Neg<Output = N>,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
    }

    impl<N, I> AbstractGroup<Additive> for CsVecI<N, I>
    where
        N: Num + Copy + Neg<Output = N>,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
    }

    impl<N, I> AbstractGroupAbelian<Additive> for CsVecI<N, I>
    where
        N: Num + Copy + Neg<Output = N>,
        for<'r> &'r N: Add<Output = N>,
        I: SpIndex,
    {
    }

    #[cfg(test)]
    mod test {
        use super::*;

        #[test]
        fn additive_operator_is_addition() {
            let a = CsVec::new(2, vec![0], vec![2.]);
            let b = CsVec::new(2, vec![0], vec![3.]);
            assert_eq!(AbstractMagma::<Additive>::operate(&a, &b), &a + &b);
        }

        #[test]
        fn additive_identity_is_zero() {
            assert_eq!(CsVec::<f64>::zero(), Identity::<Additive>::identity());
        }

        #[test]
        fn additive_inverse_is_negated() {
            let vector = CsVec::new(2, vec![0], vec![2.]);
            assert_eq!(
                -vector.clone(),
                TwoSidedInverse::<Additive>::two_sided_inverse(&vector)
            );
        }
    }
}

#[cfg(feature = "approx")]
mod approx_impls {
    use super::*;
    use approx::*;

    impl<N, I, IS1, DS1, IS2, DS2> AbsDiffEq<CsVecBase<IS2, DS2, N, I>>
        for CsVecBase<IS1, DS1, N, I>
    where
        I: SpIndex,
        CsVecBase<IS1, DS1, N, I>:
            std::cmp::PartialEq<CsVecBase<IS2, DS2, N, I>>,
        IS1: Deref<Target = [I]>,
        IS2: Deref<Target = [I]>,
        DS1: Deref<Target = [N]>,
        DS2: Deref<Target = [N]>,
        N: AbsDiffEq,
        N::Epsilon: Clone,
        N: num_traits::Zero,
    {
        type Epsilon = N::Epsilon;
        fn default_epsilon() -> N::Epsilon {
            N::default_epsilon()
        }

        fn abs_diff_eq(
            &self,
            other: &CsVecBase<IS2, DS2, N, I>,
            epsilon: N::Epsilon,
        ) -> bool {
            match (self.dim(), other.dim()) {
                (0, _) | (_, 0) => {}
                (nx, ny) => {
                    if nx != ny {
                        return false;
                    }
                }
            }
            let zero = N::zero();
            self.iter()
                .nnz_or_zip(other.iter())
                .map(|either| match either {
                    NnzEither::Both((_, l, r)) => (l, r),
                    NnzEither::Left((_, l)) => (l, &zero),
                    NnzEither::Right((_, r)) => (&zero, r),
                })
                .all(|(v0, v1)| v0.abs_diff_eq(v1, epsilon.clone()))
        }
    }

    impl<N, I, IS1, DS1, IS2, DS2> UlpsEq<CsVecBase<IS2, DS2, N, I>>
        for CsVecBase<IS1, DS1, N, I>
    where
        I: SpIndex,
        CsVecBase<IS1, DS1, N, I>:
            std::cmp::PartialEq<CsVecBase<IS2, DS2, N, I>>,
        IS1: Deref<Target = [I]>,
        IS2: Deref<Target = [I]>,
        DS1: Deref<Target = [N]>,
        DS2: Deref<Target = [N]>,
        N: UlpsEq,
        N::Epsilon: Clone,
        N: num_traits::Zero,
    {
        fn default_max_ulps() -> u32 {
            N::default_max_ulps()
        }

        fn ulps_eq(
            &self,
            other: &CsVecBase<IS2, DS2, N, I>,
            epsilon: N::Epsilon,
            max_ulps: u32,
        ) -> bool {
            match (self.dim(), other.dim()) {
                (0, _) | (_, 0) => {}
                (nx, ny) => {
                    if nx != ny {
                        return false;
                    }
                }
            }
            let zero = N::zero();
            self.iter()
                .nnz_or_zip(other.iter())
                .map(|either| match either {
                    NnzEither::Both((_, l, r)) => (l, r),
                    NnzEither::Left((_, l)) => (l, &zero),
                    NnzEither::Right((_, r)) => (&zero, r),
                })
                .all(|(v0, v1)| v0.ulps_eq(v1, epsilon.clone(), max_ulps))
        }
    }
    impl<N, I, IS1, DS1, IS2, DS2> RelativeEq<CsVecBase<IS2, DS2, N, I>>
        for CsVecBase<IS1, DS1, N, I>
    where
        I: SpIndex,
        CsVecBase<IS1, DS1, N, I>:
            std::cmp::PartialEq<CsVecBase<IS2, DS2, N, I>>,
        IS1: Deref<Target = [I]>,
        IS2: Deref<Target = [I]>,
        DS1: Deref<Target = [N]>,
        DS2: Deref<Target = [N]>,
        N: RelativeEq,
        N::Epsilon: Clone,
        N: num_traits::Zero,
    {
        fn default_max_relative() -> N::Epsilon {
            N::default_max_relative()
        }

        fn relative_eq(
            &self,
            other: &CsVecBase<IS2, DS2, N, I>,
            epsilon: N::Epsilon,
            max_relative: Self::Epsilon,
        ) -> bool {
            match (self.dim(), other.dim()) {
                (0, _) | (_, 0) => {}
                (nx, ny) => {
                    if nx != ny {
                        return false;
                    }
                }
            }
            let zero = N::zero();
            self.iter()
                .nnz_or_zip(other.iter())
                .map(|either| match either {
                    NnzEither::Both((_, l, r)) => (l, r),
                    NnzEither::Left((_, l)) => (l, &zero),
                    NnzEither::Right((_, r)) => (&zero, r),
                })
                .all(|(v0, v1)| {
                    v0.relative_eq(v1, epsilon.clone(), max_relative.clone())
                })
        }
    }
}

#[cfg(test)]
mod test {
    use super::SparseIterTools;
    use crate::sparse::{CsVec, CsVecI};
    use ndarray::Array;
    use num_traits::Zero;

    fn test_vec1() -> CsVec<f64> {
        let n = 8;
        let indices = vec![0, 1, 4, 5, 7];
        let data = vec![0., 1., 4., 5., 7.];

        return CsVec::new(n, indices, data);
    }

    fn test_vec2() -> CsVecI<f64, usize> {
        let n = 8;
        let indices = vec![0, 2, 4, 6, 7];
        let data = vec![0.5, 2.5, 4.5, 6.5, 7.5];

        return CsVecI::new(n, indices, data);
    }

    #[test]
    fn test_copy() {
        let v = test_vec1();
        let view1 = v.view();
        let view2 = view1; // this shouldn't move
        assert_eq!(view1, view2);
    }

    #[test]
    fn test_nnz_zip_iter() {
        let vec1 = test_vec1();
        let vec2 = test_vec2();
        let mut iter = vec1.iter().nnz_zip(vec2.iter());
        assert_eq!(iter.next().unwrap(), (0, &0., &0.5));
        assert_eq!(iter.next().unwrap(), (4, &4., &4.5));
        assert_eq!(iter.next().unwrap(), (7, &7., &7.5));
        assert!(iter.next().is_none());
    }

    #[test]
    fn test_nnz_or_zip_iter() {
        use super::NnzEither::*;
        let vec1 = test_vec1();
        let vec2 = test_vec2();
        let mut iter = vec1.iter().nnz_or_zip(vec2.iter());
        assert_eq!(iter.next().unwrap(), Both((0, &0., &0.5)));
        assert_eq!(iter.next().unwrap(), Left((1, &1.)));
        assert_eq!(iter.next().unwrap(), Right((2, &2.5)));
        assert_eq!(iter.next().unwrap(), Both((4, &4., &4.5)));
        assert_eq!(iter.next().unwrap(), Left((5, &5.)));
        assert_eq!(iter.next().unwrap(), Right((6, &6.5)));
        assert_eq!(iter.next().unwrap(), Both((7, &7., &7.5)));
    }

    #[test]
    fn dot_product() {
        let vec1 = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);
        let vec2 = CsVec::new(8, vec![1, 3, 5, 7], vec![2.; 4]);
        let vec3 = CsVec::new(8, vec![1, 2, 5, 6], vec![3.; 4]);

        assert_eq!(0., vec1.dot(&vec2));
        assert_eq!(4., vec1.dot(&vec1));
        assert_eq!(16., vec2.dot(&vec2));
        assert_eq!(6., vec1.dot(&vec3));
        assert_eq!(12., vec2.dot(vec3.view()));

        let dense_vec = vec![1., 2., 3., 4., 5., 6., 7., 8.];
        {
            let slice = &dense_vec[..];
            assert_eq!(16., vec1.dot(&dense_vec));
            assert_eq!(16., vec1.dot(slice));
            assert_eq!(16., vec1.dot_dense(slice));
            assert_eq!(16., vec1.dot_dense(&dense_vec));
        }
        assert_eq!(16., vec1.dot_dense(dense_vec));

        let ndarray_vec = Array::linspace(1., 8., 8);
        assert_eq!(16., vec1.dot(&ndarray_vec));
        assert_eq!(16., vec1.dot_dense(ndarray_vec.view()));
    }

    #[test]
    #[should_panic]
    fn dot_product_panics() {
        let vec1 = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);
        let vec2 = CsVec::new(9, vec![1, 3, 5, 7], vec![2.; 4]);
        vec1.dot(&vec2);
    }

    #[test]
    #[should_panic]
    fn dot_product_panics2() {
        let vec1 = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);
        let dense_vec = vec![0., 1., 2., 3., 4., 5., 6., 7., 8.];
        vec1.dot(&dense_vec);
    }

    #[test]
    fn squared_l2_norm() {
        // Should work with both float and integer data

        let v = CsVec::new(0, Vec::<usize>::new(), Vec::<i32>::new());
        assert_eq!(0, v.squared_l2_norm());

        let v = CsVec::new(0, Vec::<usize>::new(), Vec::<f32>::new());
        assert_eq!(0., v.squared_l2_norm());

        let v = CsVec::new(8, vec![0, 1, 4, 5, 7], vec![0, 1, 4, 5, 7]);
        assert_eq!(v.dot(&v), v.squared_l2_norm());

        let v = CsVec::new(8, vec![0, 1, 4, 5, 7], vec![0., 1., 4., 5., 7.]);
        assert_eq!(v.dot(&v), v.squared_l2_norm());
    }

    #[test]
    fn l2_norm() {
        let v = CsVec::new(0, Vec::<usize>::new(), Vec::<f32>::new());
        assert_eq!(0., v.l2_norm());

        let v = test_vec1();
        assert_eq!(v.dot(&v).sqrt(), v.l2_norm());
    }

    #[test]
    fn unit_normalize() {
        let mut v = CsVec::new(0, Vec::<usize>::new(), Vec::<f32>::new());
        v.unit_normalize();
        assert_eq!(0, v.nnz());
        assert!(v.indices.is_empty());
        assert!(v.data.is_empty());

        let mut v = CsVec::new(8, vec![1, 3, 5], vec![0., 0., 0.]);
        v.unit_normalize();
        assert_eq!(3, v.nnz());
        assert!(v.data.iter().all(|x| x.is_zero()));

        let mut v =
            CsVec::new(8, vec![0, 1, 4, 5, 7], vec![0., 1., 4., 5., 7.]);
        v.unit_normalize();
        let norm = (1f32 + 4. * 4. + 5. * 5. + 7. * 7.).sqrt();
        assert_eq!(
            vec![0., 1. / norm, 4. / norm, 5. / norm, 7. / norm],
            v.data
        );
        assert!((v.l2_norm() - 1.).abs() < 1e-5);
    }

    #[test]
    fn l1_norm() {
        let v = CsVec::new(0, Vec::<usize>::new(), Vec::<f32>::new());
        assert_eq!(0., v.l1_norm());

        let v = CsVec::new(8, vec![0, 1, 4, 5, 7], vec![0, -1, 4, -5, 7]);
        assert_eq!(1 + 4 + 5 + 7, v.l1_norm());
    }

    #[test]
    fn norm() {
        let v = CsVec::new(0, Vec::<usize>::new(), Vec::<f32>::new());
        assert_eq!(0., v.norm(std::f32::INFINITY)); // Here we choose the same behavior as Eigen
        assert_eq!(0., v.norm(0.));
        assert_eq!(0., v.norm(5.));

        let v = CsVec::new(8, vec![0, 1, 4, 5, 7], vec![0., 1., -4., 5., -7.]);
        assert_eq!(7., v.norm(std::f32::INFINITY));
        assert_eq!(0., v.norm(std::f32::NEG_INFINITY));
        assert_eq!(4., v.norm(0.));
        assert_eq!(v.l1_norm(), v.norm(1.));
        assert_eq!(v.l2_norm(), v.norm(2.));
    }

    #[test]
    fn nnz_index() {
        let vec = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);
        assert_eq!(vec.nnz_index(1), None);
        assert_eq!(vec.nnz_index(9), None);
        assert_eq!(vec.nnz_index(0), Some(super::NnzIndex(0)));
        assert_eq!(vec.nnz_index(4), Some(super::NnzIndex(2)));

        let index = vec.nnz_index(2).unwrap();

        assert_eq!(vec[index], 1.);
        let mut vec = vec;
        vec[index] = 2.;
        assert_eq!(vec[index], 2.);
    }

    #[test]
    fn get_mut() {
        let mut vec = CsVec::new(8, vec![0, 2, 4, 6], vec![1.; 4]);

        *vec.get_mut(4).unwrap() = 2.;

        let expected = CsVec::new(8, vec![0, 2, 4, 6], vec![1., 1., 2., 1.]);

        assert_eq!(vec, expected);

        vec[6] = 3.;

        let expected = CsVec::new(8, vec![0, 2, 4, 6], vec![1., 1., 2., 3.]);

        assert_eq!(vec, expected);
    }

    #[test]
    fn indexing() {
        let vec = CsVec::new(8, vec![0, 2, 4, 6], vec![1., 2., 3., 4.]);
        assert_eq!(vec[0], 1.);
        assert_eq!(vec[2], 2.);
        assert_eq!(vec[4], 3.);
        assert_eq!(vec[6], 4.);
    }

    #[test]
    fn map_inplace() {
        let mut vec = CsVec::new(8, vec![0, 2, 4, 6], vec![1., 2., 3., 4.]);
        vec.map_inplace(|&x| x + 1.);
        let expected = CsVec::new(8, vec![0, 2, 4, 6], vec![2., 3., 4., 5.]);
        assert_eq!(vec, expected);
    }

    #[test]
    fn map() {
        let vec = CsVec::new(8, vec![0, 2, 4, 6], vec![1., 2., 3., 4.]);
        let res = vec.map(|&x| x * 2.);
        let expected = CsVec::new(8, vec![0, 2, 4, 6], vec![2., 4., 6., 8.]);
        assert_eq!(res, expected);
    }

    #[test]
    fn iter_mut() {
        let mut vec = CsVec::new(8, vec![0, 2, 4, 6], vec![1., 2., 3., 4.]);
        for (ind, val) in vec.iter_mut() {
            if ind == 2 {
                *val += 1.;
            } else {
                *val *= 2.;
            }
        }
        let expected = CsVec::new(8, vec![0, 2, 4, 6], vec![2., 3., 6., 8.]);
        assert_eq!(vec, expected);
    }

    #[test]
    fn adds_vectors_by_value() {
        let (a, b, expected_sum) = addition_sample();
        assert_eq!(expected_sum, a + b);
    }

    #[test]
    fn adds_vectors_by_left_value_and_right_reference() {
        let (a, b, expected_sum) = addition_sample();
        assert_eq!(expected_sum, a + &b);
    }

    #[test]
    fn adds_vectors_by_left_reference_and_right_value() {
        let (a, b, expected_sum) = addition_sample();
        assert_eq!(expected_sum, &a + b);
    }

    #[test]
    fn adds_vectors_by_reference() {
        let (a, b, expected_sum) = addition_sample();
        assert_eq!(expected_sum, &a + &b);
    }

    fn addition_sample() -> (CsVec<f64>, CsVec<f64>, CsVec<f64>) {
        let dim = 8;
        let a = CsVec::new(dim, vec![0, 3, 5, 7], vec![2., -3., 7., -1.]);
        let b = CsVec::new(dim, vec![1, 3, 4, 5], vec![4., 2., -3., 1.]);
        let expected_sum = CsVec::new(
            dim,
            vec![0, 1, 3, 4, 5, 7],
            vec![2., 4., -1., -3., 8., -1.],
        );
        (a, b, expected_sum)
    }

    #[test]
    fn negates_vectors() {
        let vector = CsVec::new(4, vec![0, 3], vec![2., -3.]);
        let negated = CsVec::new(4, vec![0, 3], vec![-2., 3.]);
        assert_eq!(-vector, negated);
    }

    #[test]
    fn can_construct_zero_sized_vectors() {
        CsVec::<f64>::new(0, vec![], vec![]);
    }

    #[test]
    fn zero_element_vanishes_when_added() {
        let zero = CsVec::<f64>::zero();
        let vector = CsVec::new(3, vec![0, 2], vec![1., 2.]);
        assert_eq!(&vector + &zero, vector);
    }

    #[test]
    fn zero_element_is_identified_as_zero() {
        assert!(CsVec::<f32>::zero().is_zero());
    }

    #[test]
    fn larger_zero_vector_is_identified_as_zero() {
        let vector = CsVec::new(3, vec![1, 2], vec![0., 0.]);
        assert!(vector.is_zero());
    }

    #[test]
    fn mul_assign() {
        let mut vector = CsVec::new(4, vec![1, 2, 3], vec![1_i32, 3, 4]);
        vector *= 2;
        assert_eq!(vector, CsVec::new(4, vec![1, 2, 3], vec![2_i32, 6, 8]));
    }

    #[test]
    fn div_assign() {
        let mut vector = CsVec::new(4, vec![1, 2, 3], vec![1_i32, 3, 4]);
        vector /= 2;
        assert_eq!(vector, CsVec::new(4, vec![1, 2, 3], vec![0_i32, 1, 2]));
    }

    #[test]
    fn scatter() {
        let vector = CsVec::new(4, vec![1, 2, 3], vec![1_i32, 3, 4]);
        let mut res = vec![0; 4];
        vector.scatter(&mut res);
        assert_eq!(res, &[0, 1, 3, 4]);
        let mut res = Array::zeros(4);
        vector.scatter(&mut res);
        assert_eq!(res, ndarray::arr1(&[0, 1, 3, 4]));
        let res: &mut [i32] = &mut [0; 4];
        vector.scatter(res);
        assert_eq!(res, &[0, 1, 3, 4]);
    }

    #[test]
    fn add_sub_complex() {
        use num_complex::Complex32;
        let vector = CsVec::new(
            4,
            vec![1, 2, 3],
            vec![
                Complex32::new(0., 1.),
                Complex32::new(3., 1.),
                Complex32::new(4., 0.),
            ],
        );
        let doubled = &vector + &vector;
        let expected = CsVec::new(
            4,
            vec![1, 2, 3],
            vec![
                Complex32::new(0., 2.),
                Complex32::new(6., 2.),
                Complex32::new(8., 0.),
            ],
        );
        assert_eq!(doubled, expected);
        let subtracted = &doubled - &vector;
        assert_eq!(subtracted, vector);
    }

    #[cfg(feature = "approx")]
    mod approx {
        use crate::*;

        #[test]
        fn approx_abs_diff_eq() {
            let v1 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 3]);
            let v2 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 3]);
            ::approx::assert_abs_diff_eq!(v1, v2);

            let v2 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 4]);
            ::approx::assert_abs_diff_eq!(v1, v2, epsilon = 1);
            let v2 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 4]);
            ::approx::assert_abs_diff_ne!(v1, v2, epsilon = 0);

            let v1 = CsVec::new(5, vec![0, 2, 4], vec![1.0_f32, 2.0, 3.0]);
            let v2 = CsVec::new(5, vec![0, 2, 4], vec![1.0_f32, 2.0, 3.0]);
            ::approx::assert_abs_diff_eq!(v1, v2);
            let v2 = CsVec::new(5, vec![0, 2, 4], vec![1.0_f32, 2.0, 3.1]);
            ::approx::assert_abs_diff_ne!(v1, v2);

            let v1 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 3]);
            let v2 = CsVec::new(5, vec![0, 3, 4], vec![1_u8, 2, 3]);
            ::approx::assert_abs_diff_ne!(v1, v2);

            let v1 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 3]);
            let v2 = CsVec::new(6, vec![0, 2, 4], vec![1_u8, 2, 3]);
            ::approx::assert_abs_diff_ne!(v1, v2);

            // Zero sized vector
            let v2 = CsVec::new(0, vec![], vec![]);
            ::approx::assert_abs_diff_ne!(v1, v2);
        }

        #[test]
        /// Testing if views can be compared
        fn approx_view() {
            let v1 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 3]);
            let v2 = CsVec::new(5, vec![0, 2, 4], vec![1_u8, 2, 3]);
            ::approx::assert_abs_diff_eq!(v1, v2);
            ::approx::assert_abs_diff_eq!(v1.view(), v2.view());

            let v1 = CsVec::new(5, vec![0, 2, 4], vec![1.0_f32, 2.0, 3.0]);
            let v2 = CsVec::new(5, vec![0, 2, 4], vec![1.0_f32, 2.0, 3.0]);
            ::approx::assert_abs_diff_eq!(v1, v2);
            ::approx::assert_abs_diff_eq!(v1.view(), v2.view());
        }
    }
}
