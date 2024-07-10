use ndarray::ArrayView;
use num_traits::{Float, Num, Signed, Zero};
#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};
use std::cmp;
///! A sparse matrix in the Compressed Sparse Row/Column format
///
/// In the CSR format, a matrix is a structure containing three vectors:
/// indptr, indices, and data
/// These vectors satisfy the relation
/// for i in [0, nrows],
/// A(i, indices[indptr[i]..indptr[i+1]]) = data[indptr[i]..indptr[i+1]]
/// In the CSC format, the relation is
/// A(indices[indptr[i]..indptr[i+1]], i) = data[indptr[i]..indptr[i+1]]
use std::default::Default;
use std::iter::{Enumerate, Zip};
use std::mem;
use std::ops::{Add, Deref, DerefMut, Index, IndexMut, Mul, MulAssign};
use std::slice::Iter;

use crate::{Ix1, Ix2, Shape};
use ndarray::linalg::Dot;
use ndarray::{self, Array, ArrayBase, ShapeBuilder};

use crate::indexing::SpIndex;

use crate::errors::StructureError;
use crate::sparse::binop;
use crate::sparse::permutation::PermViewI;
use crate::sparse::prelude::*;
use crate::sparse::prod;
use crate::sparse::smmp;
use crate::sparse::to_dense::assign_to_dense;
use crate::sparse::utils;
use crate::sparse::vec;

/// Describe the storage of a `CsMat`
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
#[allow(clippy::upper_case_acronyms)]
pub enum CompressedStorage {
    /// Compressed row storage
    CSR,
    /// Compressed column storage
    CSC,
}

impl CompressedStorage {
    /// Get the other storage, ie return CSC if we were CSR, and vice versa
    pub fn other_storage(self) -> Self {
        match self {
            CSR => CSC,
            CSC => CSR,
        }
    }
}

pub fn outer_dimension(
    storage: CompressedStorage,
    rows: usize,
    cols: usize,
) -> usize {
    match storage {
        CSR => rows,
        CSC => cols,
    }
}

pub fn inner_dimension(
    storage: CompressedStorage,
    rows: usize,
    cols: usize,
) -> usize {
    match storage {
        CSR => cols,
        CSC => rows,
    }
}

pub use self::CompressedStorage::{CSC, CSR};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
/// Hold the index of a non-zero element in the compressed storage
///
/// An `NnzIndex` can be used to later access the non-zero element in constant
/// time.
pub struct NnzIndex(pub usize);

pub struct CsIter<'a, N: 'a, I: 'a, Iptr: 'a = I>
where
    I: SpIndex,
    Iptr: SpIndex,
{
    storage: CompressedStorage,
    cur_outer: I,
    indptr: crate::IndPtrView<'a, Iptr>,
    inner_iter: Enumerate<Zip<Iter<'a, I>, Iter<'a, N>>>,
}

impl<'a, N, I, Iptr> Iterator for CsIter<'a, N, I, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    N: 'a,
{
    type Item = (&'a N, (I, I));
    fn next(&mut self) -> Option<<Self as Iterator>::Item> {
        match self.inner_iter.next() {
            None => None,
            Some((nnz_index, (&inner_ind, val))) => {
                // loop to find the correct outer dimension. Looping
                // is necessary because there can be several adjacent
                // empty outer dimensions.
                loop {
                    let nnz_end = self
                        .indptr
                        .outer_inds_sz(self.cur_outer.index_unchecked())
                        .end;
                    if nnz_index == nnz_end.index_unchecked() {
                        self.cur_outer += I::one();
                    } else {
                        break;
                    }
                }
                let (row, col) = match self.storage {
                    CSR => (self.cur_outer, inner_ind),
                    CSC => (inner_ind, self.cur_outer),
                };
                Some((val, (row, col)))
            }
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner_iter.size_hint()
    }
}

impl<N, I: SpIndex, Iptr: SpIndex, IptrStorage, IStorage, DStorage>
    CsMatBase<N, I, IptrStorage, IStorage, DStorage, Iptr>
where
    IptrStorage: Deref<Target = [Iptr]>,
    IStorage: Deref<Target = [I]>,
    DStorage: Deref<Target = [N]>,
{
    pub(crate) fn new_checked(
        storage: CompressedStorage,
        shape: (usize, usize),
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Result<Self, (IptrStorage, IStorage, DStorage, StructureError)> {
        let (nrows, ncols) = shape;
        let (inner, outer) = match storage {
            CSR => (ncols, nrows),
            CSC => (nrows, ncols),
        };
        if data.len() != indices.len() {
            return Err((
                indptr,
                indices,
                data,
                StructureError::SizeMismatch(
                    "data and indices have different sizes",
                ),
            ));
        }
        match crate::sparse::utils::check_compressed_structure(
            inner,
            outer,
            indptr.as_ref(),
            indices.as_ref(),
        ) {
            Err(e) => Err((indptr, indices, data, e)),
            Ok(_) => Ok(Self {
                storage,
                nrows,
                ncols,
                indptr: crate::IndPtrBase::new_trusted(indptr),
                indices,
                data,
            }),
        }
    }

    /// Create a new `CSR` sparse matrix
    ///
    /// See `new_csc` for the `CSC` equivalent
    ///
    /// This constructor can be used to construct all
    /// sparse matrix types.
    /// By using the type aliases one helps constrain the resulting type,
    /// as shown below
    ///
    /// # Example
    ///
    /// ```rust
    /// # use sprs::*;
    /// // This creates an owned matrix
    /// let owned_matrix = CsMat::new((2, 2), vec![0, 1, 1], vec![1], vec![4_u8]);
    /// // This creates a matrix which only borrows the elements
    /// let borrow_matrix = CsMatView::new((2, 2), &[0, 1, 1], &[1], &[4_u8]);
    /// // A combination of storage types may also be used for a
    /// // general sparse matrix
    /// let mixed_matrix = CsMatBase::new((2, 2), &[0, 1, 1] as &[_], vec![1_i64].into_boxed_slice(), vec![4_u8]);
    /// ```
    pub fn new(
        shape: (usize, usize),
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Self {
        Self::new_checked(CompressedStorage::CSR, shape, indptr, indices, data)
            .map_err(|(_, _, _, e)| e)
            .unwrap()
    }

    /// Create a new `CSC` sparse matrix
    ///
    /// See `new` for the `CSR` equivalent
    pub fn new_csc(
        shape: (usize, usize),
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Self {
        Self::new_checked(CompressedStorage::CSC, shape, indptr, indices, data)
            .map_err(|(_, _, _, e)| e)
            .unwrap()
    }

    /// Try to create a new `CSR` sparse matrix
    ///
    /// See `try_new_csc` for the `CSC` equivalent
    pub fn try_new(
        shape: (usize, usize),
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Result<Self, (IptrStorage, IStorage, DStorage, StructureError)> {
        Self::new_checked(CompressedStorage::CSR, shape, indptr, indices, data)
    }

    /// Try to create a new `CSC` sparse matrix
    ///
    /// See `new` for the `CSR` equivalent
    pub fn try_new_csc(
        shape: (usize, usize),
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Result<Self, (IptrStorage, IStorage, DStorage, StructureError)> {
        Self::new_checked(CompressedStorage::CSC, shape, indptr, indices, data)
    }

    /// Create a `CsMat` matrix from raw data,
    /// without checking their validity
    ///
    /// # Safety
    /// This is unsafe because algorithms are free to assume
    /// that properties guaranteed by
    /// [`check_compressed_structure`](Self::check_compressed_structure) are enforced.
    /// For instance, non out-of-bounds indices can be relied upon to
    /// perform unchecked slice access.
    pub unsafe fn new_unchecked(
        storage: CompressedStorage,
        shape: Shape,
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Self {
        let (nrows, ncols) = shape;
        Self {
            storage,
            nrows,
            ncols,
            indptr: crate::IndPtrBase::new_trusted(indptr),
            indices,
            data,
        }
    }

    /// Internal analog to `new_unchecked` which is not marked as `unsafe` as
    /// we should always construct valid matrices internally
    pub(crate) fn new_trusted(
        storage: CompressedStorage,
        shape: Shape,
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Self {
        let (nrows, ncols) = shape;
        Self {
            storage,
            nrows,
            ncols,
            indptr: crate::IndPtrBase::new_trusted(indptr),
            indices,
            data,
        }
    }
}

impl<N, I: SpIndex, Iptr: SpIndex, IptrStorage, IStorage, DStorage>
    CsMatBase<N, I, IptrStorage, IStorage, DStorage, Iptr>
where
    IptrStorage: Deref<Target = [Iptr]>,
    IStorage: DerefMut<Target = [I]>,
    DStorage: DerefMut<Target = [N]>,
{
    fn new_from_unsorted_checked(
        storage: CompressedStorage,
        shape: (usize, usize),
        indptr: IptrStorage,
        mut indices: IStorage,
        mut data: DStorage,
    ) -> Result<Self, (IptrStorage, IStorage, DStorage, StructureError)>
    where
        N: Clone,
    {
        let (nrows, ncols) = shape;
        let (inner, outer) = match storage {
            CSR => (ncols, nrows),
            CSC => (nrows, ncols),
        };
        if data.len() != indices.len() {
            return Err((
                indptr,
                indices,
                data,
                StructureError::SizeMismatch(
                    "data and indices have different sizes",
                ),
            ));
        }
        let mut buf = Vec::new();
        for start_stop in indptr.windows(2) {
            let start = start_stop[0].to_usize().unwrap();
            let stop = start_stop[1].to_usize().unwrap();
            let indices = &mut indices[start..stop];
            if utils::sorted_indices(indices) {
                continue;
            }
            let data = &mut data[start..stop];
            let len = stop - start;
            let indices = &mut indices[..len];
            let data = &mut data[..len];
            utils::sort_indices_data_slices(indices, data, &mut buf);
        }

        match crate::sparse::utils::check_compressed_structure(
            inner,
            outer,
            indptr.as_ref(),
            indices.as_ref(),
        ) {
            Err(e) => Err((indptr, indices, data, e)),
            Ok(_) => Ok(Self {
                storage,
                nrows,
                ncols,
                indptr: crate::IndPtrBase::new_trusted(indptr),
                indices,
                data,
            }),
        }
    }

    /// Try create a `CSR` matrix which acts as an owner of its data.
    ///
    /// A `CSC` matrix can be created with `new_from_unsorted_csc()`.
    ///
    /// If necessary, the indices will be sorted in place.
    pub fn new_from_unsorted(
        shape: Shape,
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Result<Self, (IptrStorage, IStorage, DStorage, StructureError)>
    where
        N: Clone,
    {
        Self::new_from_unsorted_checked(CSR, shape, indptr, indices, data)
    }

    /// Try create a `CSC` matrix which acts as an owner of its data.
    ///
    /// A `CSR` matrix can be created with `new_from_unsorted_csr()`.
    ///
    /// If necessary, the indices will be sorted in place.
    pub fn new_from_unsorted_csc(
        shape: Shape,
        indptr: IptrStorage,
        indices: IStorage,
        data: DStorage,
    ) -> Result<Self, (IptrStorage, IStorage, DStorage, StructureError)>
    where
        N: Clone,
    {
        Self::new_from_unsorted_checked(CSC, shape, indptr, indices, data)
    }
}

/// # Constructor methods for owned sparse matrices
impl<N, I: SpIndex, Iptr: SpIndex> CsMatI<N, I, Iptr> {
    /// Identity matrix, stored as a CSR matrix.
    ///
    /// ```rust
    /// use sprs::{CsMat, CsVec};
    /// let eye = CsMat::eye(5);
    /// assert!(eye.is_csr());
    /// let x = CsVec::new(5, vec![0, 2, 4], vec![1., 2., 3.]);
    /// let y = &eye * &x;
    /// assert_eq!(x, y);
    /// ```
    pub fn eye(dim: usize) -> Self
    where
        N: Num + Clone,
    {
        let _ = (I::from_usize(dim), Iptr::from_usize(dim)); // Make sure dim fits in type I & Iptr
        let n = dim;
        let indptr = (0..=n).map(Iptr::from_usize_unchecked).collect();
        let indices = (0..n).map(I::from_usize_unchecked).collect();
        let data = vec![N::one(); n];
        Self::new_trusted(CSR, (n, n), indptr, indices, data)
    }

    /// Identity matrix, stored as a CSC matrix.
    ///
    /// ```rust
    /// use sprs::{CsMat, CsVec};
    /// let eye = CsMat::eye_csc(5);
    /// assert!(eye.is_csc());
    /// let x = CsVec::new(5, vec![0, 2, 4], vec![1., 2., 3.]);
    /// let y = &eye * &x;
    /// assert_eq!(x, y);
    /// ```
    pub fn eye_csc(dim: usize) -> Self
    where
        N: Num + Clone,
    {
        let _ = (I::from_usize(dim), Iptr::from_usize(dim)); // Make sure dim fits in type I & Iptr
        let n = dim;
        let indptr = (0..=n).map(Iptr::from_usize_unchecked).collect();
        let indices = (0..n).map(I::from_usize_unchecked).collect();
        let data = vec![N::one(); n];
        Self::new_trusted(CSC, (n, n), indptr, indices, data)
    }
    /// Create an empty `CsMat` for building purposes
    pub fn empty(storage: CompressedStorage, inner_size: usize) -> Self {
        let shape = match storage {
            CSR => (0, inner_size),
            CSC => (inner_size, 0),
        };
        Self::new_trusted(
            storage,
            shape,
            vec![Iptr::zero(); 1],
            Vec::new(),
            Vec::new(),
        )
    }

    /// Create a new `CsMat` representing the zero matrix.
    /// Hence it has no non-zero elements.
    pub fn zero(shape: Shape) -> Self {
        let (nrows, _ncols) = shape;
        Self::new_trusted(
            CSR,
            shape,
            vec![Iptr::zero(); nrows + 1],
            Vec::new(),
            Vec::new(),
        )
    }

    /// Reserve the storage for the given additional number of nonzero data
    pub fn reserve_outer_dim(&mut self, outer_dim_additional: usize) {
        self.indptr.reserve(outer_dim_additional);
    }

    /// Reserve the storage for the given additional number of nonzero data
    pub fn reserve_nnz(&mut self, nnz_additional: usize) {
        self.indices.reserve(nnz_additional);
        self.data.reserve(nnz_additional);
    }

    /// Reserve the storage for the given number of nonzero data
    pub fn reserve_outer_dim_exact(&mut self, outer_dim_lim: usize) {
        self.indptr.reserve_exact(outer_dim_lim + 1);
    }

    /// Reserve the storage for the given number of nonzero data
    pub fn reserve_nnz_exact(&mut self, nnz_lim: usize) {
        self.indices.reserve_exact(nnz_lim);
        self.data.reserve_exact(nnz_lim);
    }

    /// Create a CSR matrix from a dense matrix, ignoring elements lower than `epsilon`.
    ///
    /// If epsilon is negative, it will be clamped to zero.
    pub fn csr_from_dense(m: ArrayView<N, Ix2>, epsilon: N) -> Self
    where
        N: Num + Clone + cmp::PartialOrd + Signed,
    {
        let epsilon = if epsilon > N::zero() {
            epsilon
        } else {
            N::zero()
        };
        let nrows = m.shape()[0];
        let ncols = m.shape()[1];

        let mut indptr = vec![Iptr::zero(); nrows + 1];
        let mut nnz = 0;
        for (row, row_count) in m.outer_iter().zip(&mut indptr[1..]) {
            nnz += row.iter().filter(|&x| x.abs() > epsilon).count();
            *row_count = Iptr::from_usize(nnz);
        }

        let mut indices = Vec::with_capacity(nnz);
        let mut data = Vec::with_capacity(nnz);
        for row in m.outer_iter() {
            for (col_ind, x) in row.iter().enumerate() {
                if x.abs() > epsilon {
                    indices.push(I::from_usize(col_ind));
                    data.push(x.clone());
                }
            }
        }
        Self {
            storage: CompressedStorage::CSR,
            nrows,
            ncols,
            indptr: crate::IndPtr::new_trusted(indptr),
            indices,
            data,
        }
    }

    /// Create a CSC matrix from a dense matrix, ignoring elements lower than `epsilon`.
    ///
    /// If epsilon is negative, it will be clamped to zero.
    pub fn csc_from_dense(m: ArrayView<N, Ix2>, epsilon: N) -> Self
    where
        N: Num + Clone + cmp::PartialOrd + Signed,
    {
        Self::csr_from_dense(m.reversed_axes(), epsilon).transpose_into()
    }

    /// Append an outer dim to an existing matrix, compressing it in the process
    pub fn append_outer(self, data: &[N]) -> Self
    where
        N: Clone + Zero,
    {
        // Safety: enumerate is monotonically increasing
        unsafe {
            self.append_outer_iter_unchecked(
                data.iter()
                    .cloned()
                    .enumerate()
                    .filter(|(_, val)| !val.is_zero()),
            )
        }
    }

    /// Append an outer dim to an existing matrix, increasing the size along the outer
    /// dimension by one.
    ///
    /// # Panics
    ///
    /// if the iterator index is **not** monotonically increasing
    pub fn append_outer_iter<Iter>(self, iter: Iter) -> Self
    where
        N: Zero,
        Iter: Iterator<Item = (usize, N)>,
    {
        unsafe {
            self.append_outer_iter_unchecked(AssertOrderedIterator {
                prev: None,
                iter: iter.filter(|(_, val)| !val.is_zero()),
            })
        }
    }

    /// Append an outer dim to an existing matrix, increasing the size along the outer
    /// dimension by one.
    ///
    /// # Safety
    ///
    /// This is unsafe since indices for each inner dim should be monotonically increasing
    /// which is not checked. The data values are additionally not checked for zero.
    /// See `append_outer_iter` for the checked version
    pub unsafe fn append_outer_iter_unchecked<Iter>(
        mut self,
        iter: Iter,
    ) -> Self
    where
        Iter: Iterator<Item = (usize, N)>,
    {
        if let (_, Some(nnz)) = iter.size_hint() {
            self.reserve_nnz(nnz)
        }
        let mut nnz = self.nnz();
        for (inner_ind, val) in iter {
            self.indices.push(I::from_usize(inner_ind));
            self.data.push(val);
            nnz += 1;
        }
        if let Some(last_inner_ind) = self.indices.last() {
            assert!(
                last_inner_ind.index_unchecked() < self.inner_dims(),
                "inner index out of range"
            );
        }
        match self.storage {
            CSR => self.nrows += 1,
            CSC => self.ncols += 1,
        }
        self.indptr.push(Iptr::from_usize(nnz));
        self
    }

    /// Append an outer dim to an existing matrix, provided by a sparse vector
    pub fn append_outer_csvec(self, vec: CsVecViewI<N, I>) -> Self
    where
        N: Clone,
    {
        assert_eq!(self.inner_dims(), vec.dim());
        // Safety: CsVec has monotonically increasing indices
        unsafe {
            self.append_outer_iter_unchecked(
                vec.iter().map(|(i, val)| (i, val.clone())),
            )
        }
    }

    /// Insert an element in the matrix. If the element is already present,
    /// its value is overwritten.
    ///
    /// Warning: this is not an efficient operation, as it requires
    /// a non-constant lookup followed by two `Vec` insertions.
    ///
    /// The insertion will be efficient, however, if the elements are inserted
    /// according to the matrix's order, eg following the row order for a CSR
    /// matrix.
    pub fn insert(&mut self, row: usize, col: usize, val: N) {
        match self.storage() {
            CSR => self.insert_outer_inner(row, col, val),
            CSC => self.insert_outer_inner(col, row, val),
        }
    }

    fn insert_outer_inner(
        &mut self,
        outer_ind: usize,
        inner_ind: usize,
        val: N,
    ) {
        let outer_dims = self.outer_dims();
        let inner_ind_idx = I::from_usize(inner_ind);
        if outer_ind >= outer_dims {
            // we need to add a new outer dimension
            let last_nnz = self.indptr.nnz_i();
            self.indptr.resize(outer_ind + 1, last_nnz);
            self.set_outer_dims(outer_ind + 1);
            self.indptr.push(last_nnz + Iptr::one());
            self.indices.push(inner_ind_idx);
            self.data.push(val);
        } else {
            // we need to search for an insertion spot
            let range = self.indptr.outer_inds_sz(outer_ind);
            let location =
                self.indices[range.clone()].binary_search(&inner_ind_idx);
            match location {
                Ok(ind) => {
                    let ind = range.start + ind.index_unchecked();
                    self.data[ind] = val;
                    return;
                }
                Err(ind) => {
                    let ind = range.start + ind.index_unchecked();
                    self.indices.insert(ind, inner_ind_idx);
                    self.data.insert(ind, val);
                    self.indptr.record_new_element(outer_ind);
                }
            }
        }

        if inner_ind >= self.inner_dims() {
            self.set_inner_dims(inner_ind + 1);
        }
    }

    fn set_outer_dims(&mut self, outer_dims: usize) {
        match self.storage() {
            CSR => self.nrows = outer_dims,
            CSC => self.ncols = outer_dims,
        }
    }

    fn set_inner_dims(&mut self, inner_dims: usize) {
        match self.storage() {
            CSR => self.ncols = inner_dims,
            CSC => self.nrows = inner_dims,
        }
    }
}

pub(crate) struct AssertOrderedIterator<Iter> {
    prev: Option<usize>,
    iter: Iter,
}

impl<N, Iter: Iterator<Item = (usize, N)>> Iterator
    for AssertOrderedIterator<Iter>
{
    type Item = (usize, N);

    fn next(&mut self) -> Option<Self::Item> {
        let (idx, n) = self.iter.next()?;

        if let Some(prev_idx) = self.prev {
            assert!(
                prev_idx < idx,
                "index out of order. {} followed {}",
                idx,
                prev_idx
            );
        }
        self.prev = Some(idx);
        Some((idx, n))
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.iter.size_hint()
    }
}

/// # Constructor methods for sparse matrix views
///
/// These constructors can be used to create views over non-matrix data
/// such as slices.
impl<'a, N: 'a, I: 'a + SpIndex, Iptr: 'a + SpIndex>
    CsMatViewI<'a, N, I, Iptr>
{
    /// Get a view into count contiguous outer dimensions, starting from i.
    ///
    /// eg this gets the rows from i to i + count in a CSR matrix
    ///
    /// This function is now deprecated, as using an index and a count is not
    /// ergonomic. The replacement, `slice_outer`, leverages the
    /// `std::ops::Range` family of types, which is better integrated into the
    /// ecosystem.
    #[deprecated(
        since = "0.10.0",
        note = "Please use the `slice_outer` method instead"
    )]
    pub fn middle_outer_views(
        &self,
        i: usize,
        count: usize,
    ) -> CsMatViewI<'a, N, I, Iptr> {
        let iend = i.checked_add(count).unwrap();
        let (nrows, ncols) = match self.storage {
            CSR => (count, self.cols()),
            CSC => (self.rows(), count),
        };
        let data_range = self.indptr.outer_inds_slice(i, iend);
        CsMatViewI {
            storage: self.storage,
            nrows,
            ncols,
            indptr: self.indptr.middle_slice_rbr(i..iend),
            indices: &self.indices[data_range.clone()],
            data: &self.data[data_range],
        }
    }

    /// Get an iterator that yields the non-zero locations and values stored in
    /// this matrix, in the fastest iteration order.
    ///
    /// This method will yield the correct lifetime for iterating over a sparse
    /// matrix view.
    pub fn iter_rbr(&self) -> CsIter<'a, N, I, Iptr> {
        CsIter {
            storage: self.storage,
            cur_outer: I::zero(),
            indptr: self.indptr.reborrow(),
            inner_iter: self.indices.iter().zip(self.data.iter()).enumerate(),
        }
    }
}

/// # Common methods for all variants of compressed sparse matrices.
impl<N, I, Iptr, IptrStorage, IndStorage, DataStorage>
    CsMatBase<N, I, IptrStorage, IndStorage, DataStorage, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IptrStorage: Deref<Target = [Iptr]>,
    IndStorage: Deref<Target = [I]>,
    DataStorage: Deref<Target = [N]>,
{
    /// The underlying storage of this matrix
    pub fn storage(&self) -> CompressedStorage {
        self.storage
    }

    /// The number of rows of this matrix
    pub fn rows(&self) -> usize {
        self.nrows
    }

    /// The number of cols of this matrix
    pub fn cols(&self) -> usize {
        self.ncols
    }

    /// The shape of the matrix.
    /// Equivalent to `let shape = (a.rows(), a.cols())`.
    pub fn shape(&self) -> Shape {
        (self.nrows, self.ncols)
    }

    /// The number of non-zero elements this matrix stores.
    /// This is often relevant for the complexity of most sparse matrix
    /// algorithms, which are often linear in the number of non-zeros.
    pub fn nnz(&self) -> usize {
        self.indptr.nnz()
    }

    /// The density of the sparse matrix, defined as the number of non-zero
    /// elements divided by the maximum number of elements
    pub fn density(&self) -> f64 {
        let rows = self.nrows as f64;
        let cols = self.ncols as f64;
        let nnz = self.nnz() as f64;
        nnz / (rows * cols)
    }

    /// Number of outer dimensions, that ie equal to self.rows() for a CSR
    /// matrix, and equal to self.cols() for a CSC matrix
    pub fn outer_dims(&self) -> usize {
        outer_dimension(self.storage, self.nrows, self.ncols)
    }

    /// Number of inner dimensions, that ie equal to self.cols() for a CSR
    /// matrix, and equal to self.rows() for a CSC matrix
    pub fn inner_dims(&self) -> usize {
        match self.storage {
            CSC => self.nrows,
            CSR => self.ncols,
        }
    }

    /// Access the element located at row i and column j.
    /// Will return None if there is no non-zero element at this location.
    ///
    /// This access is logarithmic in the number of non-zeros
    /// in the corresponding outer slice. It is therefore advisable not to rely
    /// on this for algorithms, and prefer [`outer_iterator`](Self::outer_iterator)
    /// which accesses elements in storage order.
    pub fn get(&self, i: usize, j: usize) -> Option<&N> {
        match self.storage {
            CSR => self.get_outer_inner(i, j),
            CSC => self.get_outer_inner(j, i),
        }
    }

    /// The array of offsets in the indices() and data() slices.
    /// The elements of the slice at outer dimension i
    /// are available between the elements indptr\[i\] and indptr\[i+1\]
    /// in the indices() and data() slices.
    ///
    /// # Example
    ///
    /// ```rust
    /// use sprs::{CsMat};
    /// let eye : CsMat<f64> = CsMat::eye(5);
    /// // get the element of row 3
    /// // there is only one element in this row, with a column index of 3
    /// // and a value of 1.
    /// let range = eye.indptr().outer_inds_sz(3);
    /// assert_eq!(range.start, 3);
    /// assert_eq!(range.end, 4);
    /// assert_eq!(eye.indices()[range.start], 3);
    /// assert_eq!(eye.data()[range.start], 1.);
    /// ```
    pub fn indptr(&self) -> crate::IndPtrView<Iptr> {
        crate::IndPtrView::new_trusted(self.indptr.raw_storage())
    }

    /// Get an indptr representation suitable for ffi, cloning if necessary to
    /// get a compatible representation.
    ///
    /// # Warning
    ///
    /// For ffi usage, one needs to call `Cow::as_ptr`, but it's important
    /// to keep the `Cow` alive during the lifetime of the pointer. Example
    /// of a correct and incorrect ffi usage:
    ///
    /// ```rust
    /// let mat: sprs::CsMat<f64> = sprs::CsMat::eye(5);
    /// let mid = mat.view().middle_outer_views(1, 2);
    /// let ptr = {
    ///     let indptr_proper = mid.proper_indptr();
    ///     println!(
    ///         "ptr {:?} is valid as long as _indptr_proper_owned is in scope",
    ///         indptr_proper.as_ptr()
    ///     );
    ///     indptr_proper.as_ptr()
    /// };
    /// // This line is UB.
    /// // println!("ptr deref: {}", *ptr);
    /// ```
    pub fn proper_indptr(&self) -> std::borrow::Cow<[Iptr]> {
        self.indptr.to_proper()
    }

    /// The inner dimension location for each non-zero value. See
    /// the documentation of indptr() for more explanations.
    pub fn indices(&self) -> &[I] {
        &self.indices[..]
    }

    /// The non-zero values. See the documentation of indptr()
    /// for more explanations.
    pub fn data(&self) -> &[N] {
        &self.data[..]
    }

    /// Destruct the matrix object and recycle its storage containers.
    ///
    /// # Example
    ///
    /// ```rust
    /// use sprs::{CsMat};
    /// let (indptr, indices, data) = CsMat::<i32>::eye(3).into_raw_storage();
    /// assert_eq!(indptr, vec![0, 1, 2, 3]);
    /// assert_eq!(indices, vec![0, 1, 2]);
    /// assert_eq!(data, vec![1, 1, 1]);
    /// ```
    pub fn into_raw_storage(self) -> (IptrStorage, IndStorage, DataStorage) {
        let Self {
            indptr,
            indices,
            data,
            ..
        } = self;
        (indptr.into_raw_storage(), indices, data)
    }

    /// Test whether the matrix is in CSC storage
    pub fn is_csc(&self) -> bool {
        self.storage == CSC
    }

    /// Test whether the matrix is in CSR storage
    pub fn is_csr(&self) -> bool {
        self.storage == CSR
    }

    /// Transpose a matrix in place
    /// No allocation required (this is simply a storage order change)
    pub fn transpose_mut(&mut self) {
        mem::swap(&mut self.nrows, &mut self.ncols);
        self.storage = self.storage.other_storage();
    }

    /// Transpose a matrix in place
    /// No allocation required (this is simply a storage order change)
    pub fn transpose_into(mut self) -> Self {
        self.transpose_mut();
        self
    }

    /// Transposed view of this matrix
    /// No allocation required (this is simply a storage order change)
    pub fn transpose_view(&self) -> CsMatViewI<N, I, Iptr> {
        CsMatViewI {
            storage: self.storage.other_storage(),
            nrows: self.ncols,
            ncols: self.nrows,
            indptr: crate::IndPtrView::new_trusted(self.indptr.raw_storage()),
            indices: &self.indices[..],
            data: &self.data[..],
        }
    }

    /// Get an owned version of this matrix. If the matrix was already
    /// owned, this will make a deep copy.
    pub fn to_owned(&self) -> CsMatI<N, I, Iptr>
    where
        N: Clone,
    {
        CsMatI {
            storage: self.storage,
            nrows: self.nrows,
            ncols: self.ncols,
            indptr: self.indptr.to_owned(),
            indices: self.indices.to_vec(),
            data: self.data.to_vec(),
        }
    }

    /// Generate a one-hot matrix, compressing the inner dimension.
    ///
    /// Returns a matrix with the same size, the same CSR/CSC type,
    /// and a single value of 1.0 within each populated inner vector.
    ///
    /// See [`into_csc`](CsMatBase::into_csc) and [`into_csr`](CsMatBase::into_csr)
    /// if you need to prepare a matrix
    /// for one-hot compression.
    pub fn to_inner_onehot(&self) -> CsMatI<N, I, Iptr>
    where
        N: Clone + Float + PartialOrd,
    {
        let mut indptr_counter = 0_usize;
        let mut indptr: Vec<Iptr> = Vec::with_capacity(self.indptr.len());

        let max_data_len = self.indptr.len().min(self.data.len());
        let mut indices: Vec<I> = Vec::with_capacity(max_data_len);
        let mut data = Vec::with_capacity(max_data_len);

        for (_, inner_vec) in self.outer_iterator().enumerate() {
            let hot_element = inner_vec
                .iter()
                .filter(|e| !e.1.is_nan())
                .max_by(|a, b| {
                    a.1.partial_cmp(b.1)
                        .expect("Unexpected NaN value was found")
                })
                .map(|a| a.0);

            indptr.push(Iptr::from_usize(indptr_counter));

            if let Some(inner_id) = hot_element {
                indices.push(I::from_usize(inner_id));
                data.push(N::one());
                indptr_counter += 1;
            }
        }

        indptr.push(Iptr::from_usize(indptr_counter));
        CsMatI {
            storage: self.storage,
            nrows: self.rows(),
            ncols: self.cols(),
            indptr: crate::IndPtr::new_trusted(indptr),
            indices,
            data,
        }
    }

    /// Clone the matrix with another integer type for indptr and indices
    ///
    /// # Panics
    ///
    /// If the indices or indptr values cannot be represented by the requested
    /// integer type.
    pub fn to_other_types<I2, N2, Iptr2>(&self) -> CsMatI<N2, I2, Iptr2>
    where
        N: Clone + Into<N2>,
        I2: SpIndex,
        Iptr2: SpIndex,
    {
        let indptr = crate::IndPtr::new_trusted(
            self.indptr
                .raw_storage()
                .iter()
                .map(|i| Iptr2::from_usize(i.index_unchecked()))
                .collect(),
        );
        let indices = self
            .indices
            .iter()
            .map(|i| I2::from_usize(i.index_unchecked()))
            .collect();
        let data = self.data.iter().map(|x| x.clone().into()).collect();
        CsMatI {
            storage: self.storage,
            nrows: self.nrows,
            ncols: self.ncols,
            indptr,
            indices,
            data,
        }
    }

    /// Return a view into the current matrix
    pub fn view(&self) -> CsMatViewI<N, I, Iptr> {
        CsMatViewI {
            storage: self.storage,
            nrows: self.nrows,
            ncols: self.ncols,
            indptr: crate::IndPtrView::new_trusted(self.indptr.raw_storage()),
            indices: &self.indices[..],
            data: &self.data[..],
        }
    }

    pub fn structure_view(&self) -> CsStructureViewI<I, Iptr> {
        // Safety: std::slice::from_raw_parts requires its passed
        // pointer to be valid for the whole length of the slice. We have a
        // zero-sized type, so the length is zero, and since we cast
        // a non-null pointer, the pointer is valid as all pointers to zero-sized
        // types are valid if they are not null.
        let zst_data = unsafe {
            std::slice::from_raw_parts(
                self.data.as_ptr().cast::<()>(),
                self.data.len(),
            )
        };
        CsStructureViewI {
            storage: self.storage,
            nrows: self.nrows,
            ncols: self.ncols,
            indptr: crate::IndPtrView::new_trusted(self.indptr.raw_storage()),
            indices: &self.indices[..],
            data: zst_data,
        }
    }

    pub fn to_dense(&self) -> Array<N, Ix2>
    where
        N: Clone + Zero,
    {
        let mut res = Array::zeros((self.rows(), self.cols()));
        assign_to_dense(res.view_mut(), self.view());
        res
    }

    /// Return an outer iterator for the matrix
    ///
    /// This can be used for iterating over the rows (resp. cols) of
    /// a CSR (resp. CSC) matrix.
    ///
    /// ```rust
    /// use sprs::{CsMat};
    /// let eye = CsMat::eye(5);
    /// for (row_ind, row_vec) in eye.outer_iterator().enumerate() {
    ///     let (col_ind, &val): (_, &f64) = row_vec.iter().next().unwrap();
    ///     assert_eq!(row_ind, col_ind);
    ///     assert_eq!(val, 1.);
    /// }
    /// ```
    pub fn outer_iterator(
        &self,
    ) -> impl std::iter::DoubleEndedIterator<Item = CsVecViewI<N, I>>
           + std::iter::ExactSizeIterator<Item = CsVecViewI<N, I>>
           + '_ {
        self.indptr.iter_outer_sz().map(move |range| {
            CsVecViewI::new_trusted(
                self.inner_dims(),
                // TODO: unsafe slice indexing
                &self.indices[range.clone()],
                &self.data[range],
            )
        })
    }

    /// Return an outer iterator over P*A*P^T, where it is necessary to use
    /// `CsVec::iter_perm(perm.inv())` to iterate over the inner dimension.
    /// Unstable, this is a convenience function for the crate `sprs-ldl`
    /// for now.
    #[doc(hidden)]
    pub fn outer_iterator_papt<'a, 'perm: 'a>(
        &'a self,
        perm: PermViewI<'perm, I>,
    ) -> impl std::iter::DoubleEndedIterator<Item = (usize, CsVecViewI<N, I>)>
           + std::iter::ExactSizeIterator<Item = (usize, CsVecViewI<N, I>)>
           + '_ {
        (0..self.outer_dims()).map(move |outer_ind| {
            let outer_ind_perm = perm.at(outer_ind);
            let range = self.indptr.outer_inds_sz(outer_ind_perm);
            let indices = &self.indices[range.clone()];
            let data = &self.data[range];
            // CsMat invariants imply CsVec invariants
            let vec = CsVecBase::new_trusted(self.inner_dims(), indices, data);
            (outer_ind_perm, vec)
        })
    }

    /// Get the max number of nnz for each outer dim
    pub fn max_outer_nnz(&self) -> usize {
        self.outer_iterator()
            .map(|outer| outer.indices().len())
            .max()
            .unwrap_or(0)
    }

    /// Get the degrees of each vertex on a symmetric matrix
    ///
    /// The nonzero pattern of a symmetric matrix can be interpreted as
    /// an undirected graph. In such a graph, a vertex i is connected to another
    /// vertex j if there is a corresponding nonzero entry in the matrix at
    /// location (i, j).
    ///
    /// This function returns a vector containing the degree of each vertex,
    /// that is to say the number of neighbor of each vertex. We do not
    /// count diagonal entries as a neighbor.
    pub fn degrees(&self) -> Vec<usize> {
        self.outer_iterator()
            .enumerate()
            .map(|(outer_dim, outer)| {
                outer
                    .indices()
                    .iter()
                    .filter(|ind| ind.index() != outer_dim)
                    .count()
            })
            .collect()
    }

    /// Get a view into the i-th outer dimension (eg i-th row for a CSR matrix)
    pub fn outer_view(&self, i: usize) -> Option<CsVecViewI<N, I>> {
        if i >= self.outer_dims() {
            return None;
        }
        let range = self.indptr.outer_inds_sz(i);
        // CsMat invariants imply CsVec invariants
        Some(CsVecViewI::new_trusted(
            self.inner_dims(),
            // TODO: unsafe slice indexing
            &self.indices[range.clone()],
            &self.data[range],
        ))
    }

    /// Get the diagonal of a sparse matrix
    pub fn diag(&self) -> CsVecI<N, I>
    where
        N: Clone,
    {
        let shape = self.shape();
        let smallest_dim: usize = cmp::min(shape.0, shape.1);
        // Assuming most matrices have dense diagonals, it seems prudent
        // to allocate a bit of memory up front
        let heuristic = smallest_dim / 2;
        let mut index_vec = Vec::with_capacity(heuristic);
        let mut data_vec = Vec::with_capacity(heuristic);

        for i in 0..smallest_dim {
            let optional_index = self.nnz_index(i, i);
            if let Some(idx) = optional_index {
                data_vec.push(self[idx].clone());
                index_vec.push(I::from_usize(i));
            }
        }
        data_vec.shrink_to_fit();
        index_vec.shrink_to_fit();
        CsVecI::new_trusted(smallest_dim, index_vec, data_vec)
    }

    /// Iteration over all entries on the diagonal
    pub fn diag_iter(
        &self,
    ) -> impl ExactSizeIterator<Item = Option<&N>>
           + DoubleEndedIterator<Item = Option<&N>> {
        let smallest_dim = cmp::min(self.ncols, self.nrows);
        (0..smallest_dim).map(move |i| self.get_outer_inner(i, i))
    }

    /// Iteration on outer blocks of size `block_size`
    ///
    /// # Panics
    ///
    /// If the block size is 0.
    pub fn outer_block_iter(
        &self,
        block_size: usize,
    ) -> impl std::iter::DoubleEndedIterator<Item = CsMatViewI<N, I, Iptr>>
           + std::iter::ExactSizeIterator<Item = CsMatViewI<N, I, Iptr>>
           + '_ {
        (0..self.outer_dims()).step_by(block_size).map(move |i| {
            let count = if i + block_size > self.outer_dims() {
                self.outer_dims() - i
            } else {
                block_size
            };
            self.view().slice_outer_rbr(i..i + count)
        })
    }

    /// Return a new sparse matrix with the same sparsity pattern, with all non-zero values mapped by the function `f`.
    pub fn map<F, N2>(&self, f: F) -> CsMatI<N2, I, Iptr>
    where
        F: FnMut(&N) -> N2,
    {
        let data: Vec<N2> = self.data.iter().map(f).collect();

        CsMatI {
            storage: self.storage,
            nrows: self.nrows,
            ncols: self.ncols,
            indptr: self.indptr.to_owned(),
            indices: self.indices.to_vec(),
            data,
        }
    }

    /// Access an element given its `outer_ind` and `inner_ind`.
    /// Will return None if there is no non-zero element at this location.
    ///
    /// This access is logarithmic in the number of non-zeros
    /// in the corresponding outer slice. It is therefore advisable not to rely
    /// on this for algorithms, and prefer [`outer_iterator`](Self::outer_iterator)
    /// which accesses elements in storage order.
    pub fn get_outer_inner(
        &self,
        outer_ind: usize,
        inner_ind: usize,
    ) -> Option<&N> {
        self.outer_view(outer_ind)
            .and_then(|vec| vec.get_rbr(inner_ind))
    }

    /// Find the non-zero index of the element specified by row and col
    ///
    /// Searching this index is logarithmic in the number of non-zeros
    /// in the corresponding outer slice.
    /// Once it is available, the `NnzIndex` enables retrieving the data with
    /// O(1) complexity.
    pub fn nnz_index(&self, row: usize, col: usize) -> Option<NnzIndex> {
        match self.storage() {
            CSR => self.nnz_index_outer_inner(row, col),
            CSC => self.nnz_index_outer_inner(col, row),
        }
    }

    /// Find the non-zero index of the element specified by `outer_ind` and
    /// `inner_ind`.
    ///
    /// Searching this index is logarithmic in the number of non-zeros
    /// in the corresponding outer slice.
    pub fn nnz_index_outer_inner(
        &self,
        outer_ind: usize,
        inner_ind: usize,
    ) -> Option<NnzIndex> {
        if outer_ind >= self.outer_dims() {
            return None;
        }
        let offset = self.indptr.outer_inds_sz(outer_ind).start;
        self.outer_view(outer_ind)
            .and_then(|vec| vec.nnz_index(inner_ind))
            .map(|vec::NnzIndex(ind)| NnzIndex(ind + offset))
    }

    /// Check the structure of `CsMat` components
    /// This will ensure that:
    /// * indptr is of length `outer_dim() + 1`
    /// * indices and data have the same length, `nnz == indptr[outer_dims()]`
    /// * indptr is sorted
    /// * indptr values do not exceed [`usize::MAX`](usize::MAX)`/ 2`, as that would mean
    ///   indices and indptr would take more space than the addressable memory
    /// * indices is sorted for each outer slice
    /// * indices are lower than `inner_dims()`
    pub fn check_compressed_structure(&self) -> Result<(), StructureError> {
        let inner = self.inner_dims();
        let outer = self.outer_dims();

        if self.indices.len() != self.data.len() {
            return Err(StructureError::SizeMismatch(
                "Indices and data lengths do not match",
            ));
        }

        utils::check_compressed_structure(
            inner,
            outer,
            self.indptr.raw_storage(),
            &self.indices,
        )
    }

    /// Get an iterator that yields the non-zero locations and values stored in
    /// this matrix, in the fastest iteration order.
    pub fn iter(&self) -> CsIter<N, I, Iptr> {
        CsIter {
            storage: self.storage,
            cur_outer: I::zero(),
            indptr: crate::IndPtrView::new_trusted(self.indptr.raw_storage()),
            inner_iter: self.indices.iter().zip(self.data.iter()).enumerate(),
        }
    }
}

/// # Methods to convert between storage orders
impl<N, I, Iptr, IptrStorage, IndStorage, DataStorage>
    CsMatBase<N, I, IptrStorage, IndStorage, DataStorage, Iptr>
where
    N: Default,
    I: SpIndex,
    Iptr: SpIndex,
    IptrStorage: Deref<Target = [Iptr]>,
    IndStorage: Deref<Target = [I]>,
    DataStorage: Deref<Target = [N]>,
{
    /// Create a matrix mathematically equal to this one, but with the
    /// opposed storage (a CSC matrix will be converted to CSR, and vice versa)
    pub fn to_other_storage(&self) -> CsMatI<N, I, Iptr>
    where
        N: Clone,
    {
        let mut indptr = vec![Iptr::zero(); self.inner_dims() + 1];
        let mut indices = vec![I::zero(); self.nnz()];
        let mut data = vec![N::default(); self.nnz()];
        raw::convert_mat_storage(
            self.view(),
            &mut indptr,
            &mut indices,
            &mut data,
        );
        CsMatI {
            storage: self.storage().other_storage(),
            nrows: self.nrows,
            ncols: self.ncols,
            indptr: crate::IndPtr::new_trusted(indptr),
            indices,
            data,
        }
    }

    /// Create a new CSC matrix equivalent to this one.
    /// A new matrix will be created even if this matrix was already CSC.
    pub fn to_csc(&self) -> CsMatI<N, I, Iptr>
    where
        N: Clone,
    {
        match self.storage {
            CSR => self.to_other_storage(),
            CSC => self.to_owned(),
        }
    }

    /// Create a new CSR matrix equivalent to this one.
    /// A new matrix will be created even if this matrix was already CSR.
    pub fn to_csr(&self) -> CsMatI<N, I, Iptr>
    where
        N: Clone,
    {
        match self.storage {
            CSR => self.to_owned(),
            CSC => self.to_other_storage(),
        }
    }
}

impl<N, I, Iptr> CsMatI<N, I, Iptr>
where
    N: Default,

    I: SpIndex,
    Iptr: SpIndex,
{
    /// Create a new CSC matrix equivalent to this one.
    /// If this matrix is CSR, it is converted to CSC
    /// If this matrix is CSC, it is returned by value
    pub fn into_csc(self) -> Self
    where
        N: Clone,
    {
        match self.storage {
            CSR => self.to_other_storage(),
            CSC => self,
        }
    }

    /// Create a new CSR matrix equivalent to this one.
    /// If this matrix is CSC, it is converted to CSR
    /// If this matrix is CSR, it is returned by value
    pub fn into_csr(self) -> Self
    where
        N: Clone,
    {
        match self.storage {
            CSR => self,
            CSC => self.to_other_storage(),
        }
    }
}

/// # Methods for sparse matrices holding mutable access to their values.
impl<N, I, Iptr, IptrStorage, IndStorage, DataStorage>
    CsMatBase<N, I, IptrStorage, IndStorage, DataStorage, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IptrStorage: Deref<Target = [Iptr]>,
    IndStorage: Deref<Target = [I]>,
    DataStorage: DerefMut<Target = [N]>,
{
    /// Mutable access to the non zero values
    ///
    /// This enables changing the values without changing the matrix's
    /// structure. To also change the matrix's structure,
    /// see [modify](fn.modify.html)
    pub fn data_mut(&mut self) -> &mut [N] {
        &mut self.data[..]
    }

    /// Sparse matrix self-multiplication by a scalar
    pub fn scale(&mut self, val: N)
    where
        for<'r> N: MulAssign<&'r N>,
    {
        for data in self.data_mut() {
            *data *= &val;
        }
    }

    /// Get a mutable view into the i-th outer dimension
    /// (eg i-th row for a CSR matrix)
    pub fn outer_view_mut(&mut self, i: usize) -> Option<CsVecViewMutI<N, I>> {
        if i >= self.outer_dims() {
            return None;
        }
        let range = self.indptr.outer_inds_sz(i);
        // CsMat invariants imply CsVec invariants
        Some(CsVecBase::new_trusted(
            self.inner_dims(),
            &self.indices[range.clone()],
            &mut self.data[range],
        ))
    }

    /// Get a mutable reference to the element located at row i and column j.
    /// Will return None if there is no non-zero element at this location.
    ///
    /// This access is logarithmic in the number of non-zeros
    /// in the corresponding outer slice. It is therefore advisable not to rely
    /// on this for algorithms, and prefer [`outer_iterator_mut`](Self::outer_iterator_mut)
    /// which accesses elements in storage order.
    /// TODO: `outer_iterator_mut` is not yet implemented
    pub fn get_mut(&mut self, i: usize, j: usize) -> Option<&mut N> {
        match self.storage {
            CSR => self.get_outer_inner_mut(i, j),
            CSC => self.get_outer_inner_mut(j, i),
        }
    }

    /// Get a mutable reference to an element given its `outer_ind` and `inner_ind`.
    /// Will return None if there is no non-zero element at this location.
    ///
    /// This access is logarithmic in the number of non-zeros
    /// in the corresponding outer slice. It is therefore advisable not to rely
    /// on this for algorithms, and prefer [`outer_iterator_mut`](Self::outer_iterator_mut)
    /// which accesses elements in storage order.
    pub fn get_outer_inner_mut(
        &mut self,
        outer_ind: usize,
        inner_ind: usize,
    ) -> Option<&mut N> {
        if let Some(NnzIndex(index)) =
            self.nnz_index_outer_inner(outer_ind, inner_ind)
        {
            Some(&mut self.data[index])
        } else {
            None
        }
    }

    /// Set the value of the non-zero element located at (row, col)
    ///
    /// # Panics
    ///
    /// - on out-of-bounds access
    /// - if no non-zero element exists at the given location
    pub fn set(&mut self, row: usize, col: usize, val: N) {
        let outer = outer_dimension(self.storage(), row, col);
        let inner = inner_dimension(self.storage(), row, col);
        let vec::NnzIndex(index) = self
            .outer_view(outer)
            .and_then(|vec| vec.nnz_index(inner))
            .unwrap();
        self.data[index] = val;
    }

    /// Apply a function to every non-zero element
    pub fn map_inplace<F>(&mut self, mut f: F)
    where
        F: FnMut(&N) -> N,
    {
        for val in &mut self.data[..] {
            *val = f(val);
        }
    }

    /// Return a mutable outer iterator for the matrix
    ///
    /// This iterator yields mutable sparse vector views for each outer
    /// dimension. Only the non-zero values can be modified, the
    /// structure is kept immutable.
    pub fn outer_iterator_mut(
        &mut self,
    ) -> impl std::iter::DoubleEndedIterator<Item = CsVecViewMutI<N, I>>
           + std::iter::ExactSizeIterator<Item = CsVecViewMutI<N, I>>
           + '_ {
        let inner_dim = self.inner_dims();
        let indices = &self.indices[..];
        let data_ptr: *mut N = self.data.as_mut_ptr();
        self.indptr.iter_outer_sz().map(move |range| {
            // # Safety
            // * ranges always point to exclusive parts of data
            // * lifetime bound to &mut self
            let data: &mut [N] = unsafe {
                std::slice::from_raw_parts_mut(
                    data_ptr.add(range.start),
                    range.end - range.start,
                )
            };

            CsVecViewMutI::new_trusted(inner_dim, &indices[range], data)
        })
    }

    /// Return a mutable view into the current matrix
    pub fn view_mut(&mut self) -> CsMatViewMutI<N, I, Iptr> {
        CsMatViewMutI {
            storage: self.storage,
            nrows: self.nrows,
            ncols: self.ncols,
            indptr: crate::IndPtrView::new_trusted(self.indptr.raw_storage()),
            indices: &self.indices[..],
            data: &mut self.data[..],
        }
    }

    /// Iteration over all entries on the diagonal
    pub fn diag_iter_mut(
        &mut self,
    ) -> impl ExactSizeIterator<Item = Option<&mut N>>
           + DoubleEndedIterator<Item = Option<&mut N>>
           + '_ {
        let data_ptr: *mut N = self.data[..].as_mut_ptr();
        let smallest_dim = cmp::min(self.ncols, self.nrows);
        (0..smallest_dim).map(move |i| {
            let idx = self.nnz_index_outer_inner(i, i);
            if let Some(NnzIndex(idx)) = idx {
                // To obtain multiple mutable references to different
                // locations in data we must use a pointer and some unsafe.
                // # Safety
                // This is safe as
                // * NnzIndex provides bounds checking
                // * diagonal entries are never overlapping in memory
                // * no entries are requested more than once
                // * nnz_index_outer_inner does not modify or read from entries in self.data
                Some(unsafe { &mut *data_ptr.add(idx) })
            } else {
                None
            }
        })
    }
}

impl<N, I, Iptr, IptrStorage, IndStorage, DataStorage>
    CsMatBase<N, I, IptrStorage, IndStorage, DataStorage, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IptrStorage: DerefMut<Target = [Iptr]>,
    IndStorage: DerefMut<Target = [I]>,
    DataStorage: DerefMut<Target = [N]>,
{
    /// Modify the matrix's structure without changing its nonzero count.
    ///
    /// The coherence of the structure will be checked afterwards.
    ///
    /// # Panics
    ///
    /// If the resulting matrix breaks the `CsMat` invariants
    /// (sorted indices, no out of bounds indices).
    ///
    /// # Example
    ///
    /// ```rust
    /// use sprs::CsMat;
    /// // |   1   |
    /// // | 1     |
    /// // |   1 1 |
    /// let mut mat = CsMat::new_csc((3, 3),
    ///                                   vec![0, 1, 3, 4],
    ///                                   vec![1, 0, 2, 2],
    ///                                   vec![1.; 4]);
    ///
    /// // | 1 2   |
    /// // | 1     |
    /// // |   1   |
    /// mat.modify(|indptr, indices, data| {
    ///     indptr[1] = 2;
    ///     indptr[2] = 4;
    ///     indices[0] = 0;
    ///     indices[1] = 1;
    ///     indices[2] = 0;
    ///     data[2] = 2.;
    /// });
    /// ```
    pub fn modify<F>(&mut self, mut f: F)
    where
        F: FnMut(&mut [Iptr], &mut [I], &mut [N]),
    {
        f(
            self.indptr.raw_storage_mut(),
            &mut self.indices[..],
            &mut self.data[..],
        );
        // This is safe as long as we do the check, if we panic
        // the structure can not be retrieved, as &mut self can not pass
        // safely across an unwind boundary
        self.check_compressed_structure().unwrap();
    }
}

/// Raw functions acting directly on the compressed structure.
pub mod raw {
    use crate::indexing::SpIndex;
    use crate::sparse::prelude::*;
    use std::mem::swap;

    /*
        /// Copy-convert a compressed matrix into the oppposite storage.
        ///
        /// The input compressed matrix does not need to have its indices sorted,
        /// but the output compressed matrix will have its indices sorted.
        ///
        /// Can be used to implement CSC <-> CSR conversions, or to implement
        /// same-storage (copy) transposition.
        ///
        /// # Panics
        ///
        /// Panics if indptr contains non-zero values
        ///
        /// Panics if the output slices don't match the input matrices'
        /// corresponding slices.
        pub fn convert_storage<N, I>(
            in_storage: super::CompressedStorage,
            shape: Shape,
            in_indtpr: &[I],
            in_indices: &[I],
            in_data: &[N],
            indptr: &mut [I],
            indices: &mut [I],
            data: &mut [N],
        ) where
            N: Clone,
            I: SpIndex,
        {
            // we're building a csmat even though the indices are not sorted,
            // but it's not a problem since we don't rely on this property.
            // FIXME: this would be better with an explicit unsorted matrix type
            let mat = CsMatBase {
                storage: in_storage,
                nrows: shape.0,
                ncols: shape.1,
                indptr: in_indtpr,
                indices: in_indices,
                data: in_data,
            };

            convert_mat_storage(mat, indptr, indices, data);
        }
    */

    /// Copy-convert a csmat into the oppposite storage.
    ///
    /// Can be used to implement CSC <-> CSR conversions, or to implement
    /// same-storage (copy) transposition.
    ///
    /// # Panics
    ///
    /// Panics if indptr contains non-zero values
    ///
    /// Panics if the output slices don't match the input matrices'
    /// corresponding slices.
    pub fn convert_mat_storage<N: Clone, I: SpIndex, Iptr: SpIndex>(
        mat: CsMatViewI<N, I, Iptr>,
        indptr: &mut [Iptr],
        indices: &mut [I],
        data: &mut [N],
    ) {
        assert_eq!(indptr.len(), mat.inner_dims() + 1);
        assert_eq!(indices.len(), mat.indices().len());
        assert_eq!(data.len(), mat.data().len());

        assert!(indptr.iter().all(num_traits::Zero::is_zero));

        for vec in mat.outer_iterator() {
            for (inner_dim, _) in vec.iter() {
                indptr[inner_dim] += Iptr::one();
            }
        }

        let mut cumsum = Iptr::zero();
        for iptr in indptr.iter_mut() {
            let tmp = *iptr;
            *iptr = cumsum;
            cumsum += tmp;
        }
        if let Some(last_iptr) = indptr.last() {
            assert_eq!(last_iptr.index(), mat.nnz());
        }

        for (outer_dim, vec) in mat.outer_iterator().enumerate() {
            for (inner_dim, val) in vec.iter() {
                let dest = indptr[inner_dim].index();
                data[dest] = val.clone();
                indices[dest] = I::from_usize_unchecked(outer_dim);
                indptr[inner_dim] += Iptr::one();
            }
        }

        let mut last = Iptr::zero();
        for iptr in indptr.iter_mut() {
            swap(iptr, &mut last);
        }
    }
}

impl<'a, I, Iptr, IpStorage, IStorage, DStorage, T> std::ops::MulAssign<T>
    for CsMatBase<T, I, IpStorage, IStorage, DStorage, Iptr>
where
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpStorage: 'a + Deref<Target = [Iptr]>,
    IStorage: 'a + Deref<Target = [I]>,
    DStorage: 'a + DerefMut<Target = [T]>,
    T: std::ops::MulAssign<T> + Clone,
{
    fn mul_assign(&mut self, rhs: T) {
        self.data_mut()
            .iter_mut()
            .for_each(|v| v.mul_assign(rhs.clone()));
    }
}

impl<'a, I, Iptr, IpStorage, IStorage, DStorage, T> std::ops::DivAssign<T>
    for CsMatBase<T, I, IpStorage, IStorage, DStorage, Iptr>
where
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpStorage: 'a + Deref<Target = [Iptr]>,
    IStorage: 'a + Deref<Target = [I]>,
    DStorage: 'a + DerefMut<Target = [T]>,
    T: std::ops::DivAssign<T> + Clone,
{
    fn div_assign(&mut self, rhs: T) {
        self.data_mut()
            .iter_mut()
            .for_each(|v| v.div_assign(rhs.clone()));
    }
}

impl<'a, 'b, N, I, Iptr, IpS1, IS1, DS1, IpS2, IS2, DS2>
    Mul<&'b CsMatBase<N, I, IpS2, IS2, DS2, Iptr>>
    for &'a CsMatBase<N, I, IpS1, IS1, DS1, Iptr>
where
    N: 'a + Clone + crate::MulAcc + num_traits::Zero + Default + Send + Sync,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpS1: 'a + Deref<Target = [Iptr]>,
    IS1: 'a + Deref<Target = [I]>,
    DS1: 'a + Deref<Target = [N]>,
    IpS2: 'b + Deref<Target = [Iptr]>,
    IS2: 'b + Deref<Target = [I]>,
    DS2: 'b + Deref<Target = [N]>,
{
    type Output = CsMatI<N, I, Iptr>;

    fn mul(
        self,
        rhs: &'b CsMatBase<N, I, IpS2, IS2, DS2, Iptr>,
    ) -> CsMatI<N, I, Iptr> {
        csmat_mul_csmat(self, rhs)
    }
}

/// Multiply two sparse matrices.

/// This function is generic over `MulAcc`, and supports accumulating
/// into a different output type. This is not the default for `Mul`,
/// as type inference fails for intermediaries
pub fn csmat_mul_csmat<
    'a,
    'b,
    N,
    A,
    B,
    I,
    Iptr,
    IpS1,
    IS1,
    DS1,
    IpS2,
    IS2,
    DS2,
>(
    lhs: &'a CsMatBase<A, I, IpS1, IS1, DS1, Iptr>,
    rhs: &'b CsMatBase<B, I, IpS2, IS2, DS2, Iptr>,
) -> CsMatI<N, I, Iptr>
where
    N: 'a
        + Clone
        + crate::MulAcc<A, B>
        + crate::MulAcc<B, A>
        + num_traits::Zero
        + Default
        + Send
        + Sync,
    A: 'a + Clone + num_traits::Zero + Default + Send + Sync,
    B: 'a + Clone + num_traits::Zero + Default + Send + Sync,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpS1: 'a + Deref<Target = [Iptr]>,
    IS1: 'a + Deref<Target = [I]>,
    DS1: 'a + Deref<Target = [A]>,
    IpS2: 'b + Deref<Target = [Iptr]>,
    IS2: 'b + Deref<Target = [I]>,
    DS2: 'b + Deref<Target = [B]>,
{
    match (lhs.storage(), rhs.storage()) {
        (CSR, CSR) => smmp::mul_csr_csr(lhs.view(), rhs.view()),
        (CSR, CSC) => {
            let rhs_csr = rhs.to_other_storage();
            smmp::mul_csr_csr(lhs.view(), rhs_csr.view())
        }
        (CSC, CSR) => {
            let rhs_csc = rhs.to_other_storage();
            smmp::mul_csr_csr(rhs_csc.transpose_view(), lhs.transpose_view())
                .transpose_into()
        }
        (CSC, CSC) => {
            smmp::mul_csr_csr(rhs.transpose_view(), lhs.transpose_view())
                .transpose_into()
        }
    }
}

impl<'a, 'b, N, I, Iptr, IpS, IS, DS, DS2> Add<&'b ArrayBase<DS2, Ix2>>
    for &'a CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    N: 'a + Copy + Num + Default,
    for<'r> &'r N: Mul<Output = N>,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpS: 'a + Deref<Target = [Iptr]>,
    IS: 'a + Deref<Target = [I]>,
    DS: 'a + Deref<Target = [N]>,
    DS2: 'b + ndarray::Data<Elem = N>,
{
    type Output = Array<N, Ix2>;

    fn add(self, rhs: &'b ArrayBase<DS2, Ix2>) -> Array<N, Ix2> {
        let is_standard_layout =
            utils::fastest_axis(rhs.view()) == ndarray::Axis(1);
        let neuter_element = N::one();
        match (self.storage(), is_standard_layout) {
            (CSR, true) | (CSC, false) => binop::add_dense_mat_same_ordering(
                self,
                rhs,
                neuter_element,
                neuter_element,
            ),
            (CSR, false) | (CSC, true) => {
                let lhs = self.to_other_storage();
                binop::add_dense_mat_same_ordering(
                    &lhs,
                    rhs,
                    neuter_element,
                    neuter_element,
                )
            }
        }
    }
}

impl<'a, 'b, N, I, Iptr, IpS, IS, DS, DS2> Mul<&'b ArrayBase<DS2, Ix2>>
    for &'a CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    N: 'a + crate::MulAcc + num_traits::Zero + Clone,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpS: 'a + Deref<Target = [Iptr]>,
    IS: 'a + Deref<Target = [I]>,
    DS: 'a + Deref<Target = [N]>,
    DS2: 'b + ndarray::Data<Elem = N>,
{
    type Output = Array<N, Ix2>;

    fn mul(self, rhs: &'b ArrayBase<DS2, Ix2>) -> Array<N, Ix2> {
        let rows = self.rows();
        let cols = rhs.shape()[1];
        // when the number of colums is small, it is more efficient
        // to perform the product by iterating over the columns of
        // the rhs, otherwise iterating by rows can take advantage of
        // vectorized axpy.
        match (self.storage(), cols >= 8) {
            (CSR, true) => {
                let mut res = Array::zeros((rows, cols));
                prod::csr_mulacc_dense_rowmaj(
                    self.view(),
                    rhs.view(),
                    res.view_mut(),
                );
                res
            }
            (CSR, false) => {
                let mut res = Array::zeros((rows, cols).f());
                prod::csr_mulacc_dense_colmaj(
                    self.view(),
                    rhs.view(),
                    res.view_mut(),
                );
                res
            }
            (CSC, true) => {
                let mut res = Array::zeros((rows, cols));
                prod::csc_mulacc_dense_rowmaj(
                    self.view(),
                    rhs.view(),
                    res.view_mut(),
                );
                res
            }
            (CSC, false) => {
                let mut res = Array::zeros((rows, cols).f());
                prod::csc_mulacc_dense_colmaj(
                    self.view(),
                    rhs.view(),
                    res.view_mut(),
                );
                res
            }
        }
    }
}

impl<'a, 'b, N, I, IpS, IS, DS, DS2> Dot<CsMatBase<N, I, IpS, IS, DS>>
    for ArrayBase<DS2, Ix2>
where
    N: 'a + Clone + crate::MulAcc + num_traits::Zero + std::fmt::Debug,
    I: 'a + SpIndex,
    IpS: 'a + Deref<Target = [I]>,
    IS: 'a + Deref<Target = [I]>,
    DS: 'a + Deref<Target = [N]>,
    DS2: 'b + ndarray::Data<Elem = N>,
{
    type Output = Array<N, Ix2>;

    fn dot(&self, rhs: &CsMatBase<N, I, IpS, IS, DS>) -> Array<N, Ix2> {
        let rhs_t = rhs.transpose_view();
        let lhs_t = self.t();

        let rows = rhs_t.rows();
        let cols = lhs_t.ncols();
        // when the number of colums is small, it is more efficient
        // to perform the product by iterating over the columns of
        // the rhs, otherwise iterating by rows can take advantage of
        // vectorized axpy.
        let rres = match (rhs_t.storage(), cols >= 8) {
            (CSR, true) => {
                let mut res = Array::zeros((rows, cols));
                prod::csr_mulacc_dense_rowmaj(rhs_t, lhs_t, res.view_mut());
                res.reversed_axes()
            }
            (CSR, false) => {
                let mut res = Array::zeros((rows, cols).f());
                prod::csr_mulacc_dense_colmaj(rhs_t, lhs_t, res.view_mut());
                res.reversed_axes()
            }
            (CSC, true) => {
                let mut res = Array::zeros((rows, cols));
                prod::csc_mulacc_dense_rowmaj(rhs_t, lhs_t, res.view_mut());
                res.reversed_axes()
            }
            (CSC, false) => {
                let mut res = Array::zeros((rows, cols).f());
                prod::csc_mulacc_dense_colmaj(rhs_t, lhs_t, res.view_mut());
                res.reversed_axes()
            }
        };

        assert_eq!(self.shape()[0], rres.shape()[0]);
        assert_eq!(rhs.cols(), rres.shape()[1]);
        rres
    }
}

impl<'a, 'b, N, I, Iptr, IpS, IS, DS, DS2> Dot<ArrayBase<DS2, Ix2>>
    for CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    N: 'a + Clone + crate::MulAcc + num_traits::Zero,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpS: 'a + Deref<Target = [Iptr]>,
    IS: 'a + Deref<Target = [I]>,
    DS: 'a + Deref<Target = [N]>,
    DS2: 'b + ndarray::Data<Elem = N>,
{
    type Output = Array<N, Ix2>;

    fn dot(&self, rhs: &ArrayBase<DS2, Ix2>) -> Array<N, Ix2> {
        Mul::mul(self, rhs)
    }
}

impl<'a, 'b, N, I, Iptr, IpS, IS, DS, DS2> Mul<&'b ArrayBase<DS2, Ix1>>
    for &'a CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    N: 'a + Clone + crate::MulAcc + num_traits::Zero,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpS: 'a + Deref<Target = [Iptr]>,
    IS: 'a + Deref<Target = [I]>,
    DS: 'a + Deref<Target = [N]>,
    DS2: 'b + ndarray::Data<Elem = N>,
{
    type Output = Array<N, Ix1>;

    fn mul(self, rhs: &'b ArrayBase<DS2, Ix1>) -> Array<N, Ix1> {
        let rows = self.rows();
        let cols = rhs.shape()[0];
        let rhs_reshape = rhs.view().into_shape((cols, 1)).unwrap();
        let mut res = Array::zeros(rows);
        {
            let res_reshape = res.view_mut().into_shape((rows, 1)).unwrap();
            match self.storage() {
                CSR => {
                    prod::csr_mulacc_dense_colmaj(
                        self.view(),
                        rhs_reshape,
                        res_reshape,
                    );
                }
                CSC => {
                    prod::csc_mulacc_dense_colmaj(
                        self.view(),
                        rhs_reshape,
                        res_reshape,
                    );
                }
            }
        }
        res
    }
}

impl<'a, 'b, N, I, Iptr, IpS, IS, DS, DS2> Dot<ArrayBase<DS2, Ix1>>
    for CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    N: 'a + Clone + crate::MulAcc + num_traits::Zero,
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    IpS: 'a + Deref<Target = [Iptr]>,
    IS: 'a + Deref<Target = [I]>,
    DS: 'a + Deref<Target = [N]>,
    DS2: 'b + ndarray::Data<Elem = N>,
{
    type Output = Array<N, Ix1>;

    fn dot(&self, rhs: &ArrayBase<DS2, Ix1>) -> Array<N, Ix1> {
        Mul::mul(self, rhs)
    }
}

impl<N, I, Iptr, IpS, IS, DS> Index<[usize; 2]>
    for CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IpS: Deref<Target = [Iptr]>,
    IS: Deref<Target = [I]>,
    DS: Deref<Target = [N]>,
{
    type Output = N;

    fn index(&self, index: [usize; 2]) -> &N {
        let i = index[0];
        let j = index[1];
        self.get(i, j).unwrap()
    }
}

impl<N, I, Iptr, IpS, IS, DS> IndexMut<[usize; 2]>
    for CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IpS: Deref<Target = [Iptr]>,
    IS: Deref<Target = [I]>,
    DS: DerefMut<Target = [N]>,
{
    fn index_mut(&mut self, index: [usize; 2]) -> &mut N {
        let i = index[0];
        let j = index[1];
        self.get_mut(i, j).unwrap()
    }
}

impl<N, I, Iptr, IpS, IS, DS> Index<NnzIndex>
    for CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IpS: Deref<Target = [Iptr]>,
    IS: Deref<Target = [I]>,
    DS: Deref<Target = [N]>,
{
    type Output = N;

    fn index(&self, index: NnzIndex) -> &N {
        let NnzIndex(i) = index;
        self.data().get(i).unwrap()
    }
}

impl<N, I, Iptr, IpS, IS, DS> IndexMut<NnzIndex>
    for CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IpS: Deref<Target = [Iptr]>,
    IS: Deref<Target = [I]>,
    DS: DerefMut<Target = [N]>,
{
    fn index_mut(&mut self, index: NnzIndex) -> &mut N {
        let NnzIndex(i) = index;
        self.data_mut().get_mut(i).unwrap()
    }
}

impl<N, I, Iptr, IpS, IS, DS> SparseMat for CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IpS: Deref<Target = [Iptr]>,
    IS: Deref<Target = [I]>,
    DS: Deref<Target = [N]>,
{
    fn rows(&self) -> usize {
        self.rows()
    }

    fn cols(&self) -> usize {
        self.cols()
    }

    fn nnz(&self) -> usize {
        self.nnz()
    }
}

impl<'a, N, I, Iptr, IpS, IS, DS> SparseMat
    for &'a CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    N: 'a,
    IpS: Deref<Target = [Iptr]>,
    IS: Deref<Target = [I]>,
    DS: Deref<Target = [N]>,
{
    fn rows(&self) -> usize {
        (*self).rows()
    }

    fn cols(&self) -> usize {
        (*self).cols()
    }

    fn nnz(&self) -> usize {
        (*self).nnz()
    }
}

impl<'a, N, I, IpS, IS, DS, Iptr> IntoIterator
    for &'a CsMatBase<N, I, IpS, IS, DS, Iptr>
where
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    N: 'a,
    IpS: Deref<Target = [Iptr]>,
    IS: Deref<Target = [I]>,
    DS: Deref<Target = [N]>,
{
    type Item = (&'a N, (I, I));
    type IntoIter = CsIter<'a, N, I, Iptr>;
    fn into_iter(self) -> Self::IntoIter {
        self.iter()
    }
}

impl<'a, N, I, Iptr> IntoIterator for CsMatViewI<'a, N, I, Iptr>
where
    I: 'a + SpIndex,
    Iptr: 'a + SpIndex,
    N: 'a,
{
    type Item = (&'a N, (I, I));
    type IntoIter = CsIter<'a, N, I, Iptr>;
    fn into_iter(self) -> Self::IntoIter {
        self.iter_rbr()
    }
}

#[cfg(test)]
mod test {
    use super::CompressedStorage::CSR;
    use crate::errors::StructureErrorKind;
    use crate::sparse::{CsMat, CsMatI, CsMatView, CsVec};
    use crate::test_data::{mat1, mat1_csc, mat1_times_2};
    use ndarray::{arr2, Array};

    #[test]
    fn test_copy() {
        let m = mat1();
        let view1 = m.view();
        let view2 = view1; // this shouldn't move
        assert_eq!(view1, view2);
    }

    #[test]
    fn test_new_csr_success() {
        let indptr_ok: &[usize] = &[0, 1, 2, 3];
        let indices_ok: &[usize] = &[0, 1, 2];
        let data_ok: &[f64] = &[1., 1., 1.];
        let m = CsMatView::try_new((3, 3), indptr_ok, indices_ok, data_ok);
        assert!(m.is_ok());
    }

    #[test]
    #[should_panic]
    fn test_new_csr_bad_indptr_length() {
        let indptr_fail1: &[usize] = &[0, 1, 2];
        let indices_ok: &[usize] = &[0, 1, 2];
        let data_ok: &[f64] = &[1., 1., 1.];
        let res = CsMatView::try_new((3, 3), indptr_fail1, indices_ok, data_ok);
        res.unwrap(); // unreachable
    }

    #[test]
    #[should_panic]
    fn test_new_csr_out_of_bounds_index() {
        let indptr_ok: &[usize] = &[0, 1, 2, 3];
        let data_ok: &[f64] = &[1., 1., 1.];
        let indices_fail2: &[usize] = &[0, 1, 4];
        let res = CsMatView::try_new((3, 3), indptr_ok, indices_fail2, data_ok);
        res.unwrap(); //unreachable
    }

    #[test]
    #[should_panic]
    fn test_new_csr_bad_nnz_count() {
        let indices_ok: &[usize] = &[0, 1, 2];
        let data_ok: &[f64] = &[1., 1., 1.];
        let indptr_fail2: &[usize] = &[0, 1, 2, 4];
        let res = CsMatView::try_new((3, 3), indptr_fail2, indices_ok, data_ok);
        res.unwrap(); //unreachable
    }

    #[test]
    #[should_panic]
    fn test_new_csr_data_indices_mismatch1() {
        let indptr_ok: &[usize] = &[0, 1, 2, 3];
        let data_ok: &[f64] = &[1., 1., 1.];
        let indices_fail1: &[usize] = &[0, 1];
        let res = CsMatView::try_new((3, 3), indptr_ok, indices_fail1, data_ok);
        res.unwrap(); //unreachable
    }

    #[test]
    #[should_panic]
    fn test_new_csr_data_indices_mismatch2() {
        let indptr_ok: &[usize] = &[0, 1, 2, 3];
        let indices_ok: &[usize] = &[0, 1, 2];
        let data_fail1: &[f64] = &[1., 1., 1., 1.];
        let res = CsMatView::try_new((3, 3), indptr_ok, indices_ok, data_fail1);
        res.unwrap(); //unreachable
    }

    #[test]
    #[should_panic]
    fn test_new_csr_data_indices_mismatch3() {
        let indptr_ok: &[usize] = &[0, 1, 2, 3];
        let indices_ok: &[usize] = &[0, 1, 2];
        let data_fail2: &[f64] = &[1., 1.];
        let res = CsMatView::try_new((3, 3), indptr_ok, indices_ok, data_fail2);
        res.unwrap(); //unreachable
    }

    #[test]
    fn test_new_csr_fails() {
        let indices_ok: &[usize] = &[0, 1, 2];
        let data_ok: &[f64] = &[1., 1., 1.];
        let indptr_fail3: &[usize] = &[0, 2, 1, 3];
        assert_eq!(
            CsMatView::try_new((3, 3), indptr_fail3, indices_ok, data_ok)
                .unwrap_err()
                .3
                .kind(),
            StructureErrorKind::Unsorted
        );
    }

    #[test]
    fn test_new_csr_fail_indices_ordering() {
        let indptr: &[usize] = &[0, 2, 4, 5, 6, 7];
        // good indices would be [2, 3, 3, 4, 2, 1, 3];
        let indices: &[usize] = &[3, 2, 3, 4, 2, 1, 3];
        let data: &[f64] = &[
            0.35310881, 0.42380633, 0.28035896, 0.58082095, 0.53350123,
            0.88132896, 0.72527863,
        ];
        assert_eq!(
            CsMatView::try_new((5, 5), indptr, indices, data)
                .unwrap_err()
                .3
                .kind(),
            StructureErrorKind::Unsorted
        );
    }

    #[test]
    fn test_new_csr_csc_success() {
        let indptr_ok: &[usize] = &[0, 2, 5, 6];
        let indices_ok: &[usize] = &[2, 3, 1, 2, 3, 3];
        let data_ok: &[f64] = &[
            0.05734571, 0.15543348, 0.75628258, 0.83054515, 0.71851547,
            0.46202352,
        ];
        assert!(
            CsMatView::try_new((3, 4), indptr_ok, indices_ok, data_ok).is_ok()
        );
        assert!(
            CsMatView::try_new_csc((4, 3), indptr_ok, indices_ok, data_ok)
                .is_ok()
        );
    }

    #[test]
    #[should_panic]
    fn test_new_csc_bad_indptr_length() {
        let indptr_ok: &[usize] = &[0, 2, 5, 6];
        let indices_ok: &[usize] = &[2, 3, 1, 2, 3, 3];
        let data_ok: &[f64] = &[
            0.05734571, 0.15543348, 0.75628258, 0.83054515, 0.71851547,
            0.46202352,
        ];
        let res =
            CsMatView::try_new_csc((3, 4), indptr_ok, indices_ok, data_ok);
        res.unwrap(); //unreachable
    }

    #[test]
    fn test_new_csr_vec_borrowed() {
        let indptr_ok = vec![0, 1, 2, 3];
        let indices_ok = vec![0, 1, 2];
        let data_ok: Vec<f64> = vec![1., 1., 1.];
        assert!(
            CsMatView::try_new((3, 3), &indptr_ok, &indices_ok, &data_ok)
                .is_ok()
        );
    }

    #[test]
    fn test_new_csr_vec_owned() {
        let indptr_ok = vec![0, 1, 2, 3];
        let indices_ok = vec![0, 1, 2];
        let data_ok: Vec<f64> = vec![1., 1., 1.];
        assert!(CsMat::new_from_unsorted(
            (3, 3),
            indptr_ok,
            indices_ok,
            data_ok
        )
        .is_ok());
    }

    #[test]
    fn test_csr_from_dense() {
        let m = Array::eye(3);
        let m_sparse = CsMat::csr_from_dense(m.view(), 0.);

        assert_eq!(m_sparse, CsMat::eye(3));

        let m = arr2(&[
            [1., 0., 2., 1e-7, 1.],
            [0., 0., 0., 1., 0.],
            [3., 0., 1., 0., 0.],
        ]);
        let m_sparse = CsMat::csr_from_dense(m.view(), 1e-5);

        let expected_output = CsMat::new(
            (3, 5),
            vec![0, 3, 4, 6],
            vec![0, 2, 4, 3, 0, 2],
            vec![1., 2., 1., 1., 3., 1.],
        );

        assert_eq!(m_sparse, expected_output);
    }

    #[test]
    fn test_csc_from_dense() {
        let m = Array::eye(3);
        let m_sparse = CsMat::csc_from_dense(m.view(), 0.);

        assert_eq!(m_sparse, CsMat::eye_csc(3));

        let m = arr2(&[
            [1., 0., 2., 1e-7, 1.],
            [0., 0., 0., 1., 0.],
            [3., 0., 1., 0., 0.],
        ]);
        let m_sparse = CsMat::csc_from_dense(m.view(), 1e-5);

        let expected_output = CsMat::new_csc(
            (3, 5),
            vec![0, 2, 2, 4, 5, 6],
            vec![0, 2, 0, 2, 1, 0],
            vec![1., 3., 2., 1., 1., 1.],
        );

        assert_eq!(m_sparse, expected_output);
    }

    #[test]
    fn owned_csr_unsorted_indices() {
        let indptr = vec![0, 3, 3, 5, 6, 7];
        let indices_sorted = &[1, 2, 3, 2, 3, 4, 4];
        let indices_shuffled = vec![1, 3, 2, 2, 3, 4, 4];
        let mut data: Vec<i32> = (0..7).collect();
        let m = CsMat::new_from_unsorted(
            (5, 5),
            indptr,
            indices_shuffled,
            data.clone(),
        )
        .unwrap();
        assert_eq!(m.indices(), indices_sorted);
        data.swap(1, 2);
        assert_eq!(m.data(), &data[..]);
    }

    #[test]
    fn new_csr_with_empty_row() {
        let indptr: &[usize] = &[0, 3, 3, 5, 6, 7];
        let indices: &[usize] = &[1, 2, 3, 2, 3, 4, 4];
        let data: &[f64] = &[
            0.75672424, 0.1649078, 0.30140296, 0.10358244, 0.6283315,
            0.39244208, 0.57202407,
        ];
        assert!(CsMatView::try_new((5, 5), indptr, indices, data).is_ok());
    }

    #[test]
    fn csr_to_csc() {
        let a = mat1();
        let a_csc_ground_truth = mat1_csc();
        let a_csc = a.to_other_storage();
        assert_eq!(a_csc, a_csc_ground_truth);
    }

    #[test]
    fn test_self_smul() {
        let mut a = mat1();
        a.scale(2.);
        let c_true = mat1_times_2();
        assert_eq!(a.indptr(), c_true.indptr());
        assert_eq!(a.indices(), c_true.indices());
        assert_eq!(a.data(), c_true.data());
    }

    #[test]
    fn outer_block_iter() {
        let mat: CsMat<f64> = CsMat::eye(11);
        let mut block_iter = mat.outer_block_iter(3);
        assert_eq!(block_iter.next().unwrap().rows(), 3);
        assert_eq!(block_iter.next().unwrap().rows(), 3);
        assert_eq!(block_iter.next().unwrap().rows(), 3);
        assert_eq!(block_iter.next().unwrap().rows(), 2);
        assert_eq!(block_iter.next(), None);

        let mut block_iter = mat.outer_block_iter(4);
        assert_eq!(block_iter.next().unwrap().cols(), 11);
        block_iter.next().unwrap();
        block_iter.next().unwrap();
        assert_eq!(block_iter.next(), None);
    }

    #[test]
    fn middle_outer_views() {
        let size = 11;
        let csr: CsMat<f64> = CsMat::eye(size);
        #[allow(deprecated)]
        let v = csr.view().middle_outer_views(1, 3);
        assert_eq!(v.shape(), (3, size));
        assert_eq!(v.nnz(), 3);

        let csc = csr.to_other_storage();
        #[allow(deprecated)]
        let v = csc.view().middle_outer_views(1, 3);
        assert_eq!(v.shape(), (size, 3));
        assert_eq!(v.nnz(), 3);
    }

    #[test]
    fn nnz_index() {
        let mat: CsMat<f64> = CsMat::eye(11);

        assert_eq!(mat.nnz_index(2, 3), None);
        assert_eq!(mat.nnz_index(5, 7), None);
        assert_eq!(mat.nnz_index(0, 11), None);
        assert_eq!(mat.nnz_index(0, 0), Some(super::NnzIndex(0)));
        assert_eq!(mat.nnz_index(7, 7), Some(super::NnzIndex(7)));
        assert_eq!(mat.nnz_index(10, 10), Some(super::NnzIndex(10)));

        let index = mat.nnz_index(8, 8).unwrap();
        assert_eq!(mat[index], 1.);
        let mut mat = mat;
        mat[index] = 2.;
        assert_eq!(mat[index], 2.);
    }

    #[test]
    fn index() {
        // | 0 2 0 |
        // | 1 0 0 |
        // | 0 3 4 |
        let mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1., 2., 3., 4.],
        );
        assert_eq!(mat[[1, 0]], 1.);
        assert_eq!(mat[[0, 1]], 2.);
        assert_eq!(mat[[2, 1]], 3.);
        assert_eq!(mat[[2, 2]], 4.);
        assert_eq!(mat.get(0, 0), None);
        assert_eq!(mat.get(4, 4), None);
    }

    #[test]
    fn get_mut() {
        // | 0 1 0 |
        // | 1 0 0 |
        // | 0 1 1 |
        let mut mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );

        *mat.get_mut(2, 1).unwrap() = 3.;

        let exp = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1., 1., 3., 1.],
        );

        assert_eq!(mat, exp);

        mat[[2, 2]] = 5.;
        let exp = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1., 1., 3., 5.],
        );

        assert_eq!(mat, exp);
    }

    #[test]
    fn map() {
        // | 0 1 0 |
        // | 1 0 0 |
        // | 0 1 1 |
        let mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );

        let mut res = mat.map(|&x| x + 2.);
        let expected = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![3.; 4],
        );
        assert_eq!(res, expected);

        res.map_inplace(|&x| x / 3.);
        assert_eq!(res, mat);
    }

    #[test]
    fn insert() {
        // | 0 1 0 |
        // | 1 0 0 |
        // | 0 1 1 |
        let mut mat = CsMat::empty(CSR, 0);
        mat.reserve_outer_dim(3);
        mat.reserve_nnz(4);
        // exercise the fast and easy path where the elements are added
        // in row order for a CSR matrix
        mat.insert(0, 1, 1.);
        mat.insert(1, 0, 1.);
        mat.insert(2, 1, 1.);
        mat.insert(2, 2, 1.);

        let expected =
            CsMat::new((3, 3), vec![0, 1, 2, 4], vec![1, 0, 1, 2], vec![1.; 4]);
        assert_eq!(mat, expected);

        // | 2 1 0 |
        // | 1 0 0 |
        // | 0 1 1 |
        // exercise adding inside an already formed row (ie a search needs
        // to be performed)
        mat.insert(0, 0, 2.);
        let expected = CsMat::new(
            (3, 3),
            vec![0, 2, 3, 5],
            vec![0, 1, 0, 1, 2],
            vec![2., 1., 1., 1., 1.],
        );
        assert_eq!(mat, expected);

        // | 2 1 0 |
        // | 3 0 0 |
        // | 0 1 1 |
        // exercise the fact that inserting in an existing element
        // should change this element's value
        mat.insert(1, 0, 3.);
        let expected = CsMat::new(
            (3, 3),
            vec![0, 2, 3, 5],
            vec![0, 1, 0, 1, 2],
            vec![2., 1., 3., 1., 1.],
        );
        assert_eq!(mat, expected);
    }

    #[test]
    /// Non-regression test for https://github.com/vbarrielle/sprs/issues/129
    fn bug_129() {
        let mut mat = CsMat::zero((3, 100));
        mat.insert(2, 3, 42);
        let mut iter = mat.iter();
        assert_eq!(iter.next(), Some((&42, (2, 3))));
        assert_eq!(iter.next(), None);
    }

    #[test]
    fn iter_mut() {
        // | 0 1 0 |
        // | 1 0 0 |
        // | 0 1 1 |
        let mut mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );

        for mut col_vec in mat.outer_iterator_mut() {
            for (row_ind, val) in col_vec.iter_mut() {
                *val = row_ind as f64 + 1.;
            }
        }

        let expected = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![2., 1., 3., 3.],
        );
        assert_eq!(mat, expected);
    }

    #[test]
    #[should_panic]
    fn modify_fail() {
        let mut mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );

        // we panic because we forget to modify the last index, which gets
        // pushed in the same col as its predecessor, yet has the same value
        mat.modify(|indptr, indices, data| {
            indptr[1] = 2;
            indptr[2] = 4;
            indices[0] = 0;
            indices[1] = 1;
            data[2] = 2.;
        });
    }

    #[test]
    fn convert_types() {
        let mat: CsMat<f32> = CsMat::eye(3);
        let mat_: CsMatI<f64, u32> = mat.to_other_types();
        assert_eq!(mat_.indptr(), &[0, 1, 2, 3][..]);

        let mat = CsMatI::new_csc(
            (3, 3),
            vec![0u32, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );
        let mat_: CsMatI<f32, usize, u32> = mat.to_other_types();
        assert_eq!(mat_.indptr(), &[0, 1, 3, 4][..]);
        assert_eq!(mat_.data(), &[1.0f32, 1., 1., 1.]);
    }

    #[test]
    fn iter() {
        let mat = CsMat::new_csc(
            (3, 3),
            vec![0, 1, 3, 4],
            vec![1, 0, 2, 2],
            vec![1.; 4],
        );
        let mut iter = mat.iter();
        assert_eq!(iter.next(), Some((&1., (1, 0))));
        assert_eq!(iter.next(), Some((&1., (0, 1))));
        assert_eq!(iter.next(), Some((&1., (2, 1))));
        assert_eq!(iter.next(), Some((&1., (2, 2))));
        assert_eq!(iter.next(), None);
    }

    #[test]
    fn degrees() {
        // | 1 0 0 3 1 |
        // | 0 2 0 0 0 |
        // | 0 0 0 1 0 |
        // | 3 0 1 1 0 |
        // | 1 0 0 0 1 |
        let mat = CsMat::new_csc(
            (5, 5),
            vec![0, 3, 4, 5, 8, 10],
            vec![0, 3, 4, 1, 3, 0, 2, 3, 0, 4],
            vec![1, 3, 1, 2, 1, 3, 1, 1, 1, 1],
        );

        let degrees = mat.degrees();
        assert_eq!(&degrees, &[2, 0, 1, 2, 1],);
    }

    #[test]
    fn diag() {
        // | 1 0 0 3 1 |
        // | 0 2 0 0 0 |
        // | 0 0 0 1 0 |
        // | 3 0 1 1 0 |
        // | 1 0 0 0 1 |
        let mat = CsMat::new_csc(
            (5, 5),
            vec![0, 3, 4, 5, 8, 10],
            vec![0, 3, 4, 1, 3, 0, 2, 3, 0, 4],
            vec![1, 3, 1, 2, 1, 3, 1, 1, 1, 1],
        );

        let diag = mat.diag();
        let expected = CsVec::new(5, vec![0, 1, 3, 4], vec![1, 2, 1, 1]);
        assert_eq!(diag, expected);

        let mut iter = mat.diag_iter();
        assert_eq!(iter.next().unwrap(), Some(&1));
        assert_eq!(iter.next().unwrap(), Some(&2));
        assert_eq!(iter.next().unwrap(), None);
        assert_eq!(iter.next().unwrap(), Some(&1));
        assert_eq!(iter.next().unwrap(), Some(&1));
        assert_eq!(iter.next(), None);
    }

    #[test]
    #[cfg_attr(miri, ignore)]
    fn diag_mut() {
        // | 1 0 0 3 1 |
        // | 0 2 0 0 0 |
        // | 0 0 0 1 0 |
        // | 3 0 1 1 0 |
        // | 1 0 0 0 1 |
        let mut mat = CsMat::new_csc(
            (5, 5),
            vec![0, 3, 4, 5, 8, 10],
            vec![0, 3, 4, 1, 3, 0, 2, 3, 0, 4],
            vec![1, 3, 1, 2, 1, 3, 1, 1, 1, 1],
        );

        let mut diags = mat.diag_iter_mut().collect::<Vec<_>>();
        diags[4].as_mut().map(|x| **x *= 3);
        diags[3].as_mut().map(|x| **x -= 4);
        let expected = CsVec::new(5, vec![0, 1, 3, 4], vec![1, 2, -3, 3]);
        assert_eq!(mat.diag(), expected);
    }

    #[test]
    fn diag_rectangular() {
        // | 1 0 0 3 1 3|
        // | 0 2 0 0 0 0|
        // | 0 0 0 1 0 1|
        // | 3 0 1 1 0 0|
        // | 1 0 0 0 1 0|
        let mat = CsMat::new_csc(
            (5, 6),
            vec![0, 3, 4, 5, 8, 10, 12],
            vec![0, 3, 4, 1, 3, 0, 2, 3, 0, 4, 0, 2],
            vec![1, 3, 1, 2, 1, 3, 1, 1, 1, 1, 3, 1],
        );

        let diag = mat.diag();
        let expected = CsVec::new(5, vec![0, 1, 3, 4], vec![1, 2, 1, 1]);
        assert_eq!(diag, expected);

        let mut iter = mat.diag_iter();
        assert_eq!(iter.next().unwrap(), Some(&1));
        assert_eq!(iter.next().unwrap(), Some(&2));
        assert_eq!(iter.next().unwrap(), None);
        assert_eq!(iter.next().unwrap(), Some(&1));
        assert_eq!(iter.next().unwrap(), Some(&1));
        assert_eq!(iter.next(), None);
    }

    #[test]
    fn onehot_zero() {
        let onehot: CsMat<f32> = CsMat::zero((3, 3)).to_inner_onehot();

        assert!(onehot.is_csr());
        assert_eq!(CsMat::zero((3, 3)), onehot);
    }

    #[test]
    fn onehot_eye() {
        let mat = CsMat::new(
            (2, 2),
            vec![0, 2, 4],
            vec![0, 1, 0, 1],
            vec![2.0, 0.0, 0.0, 2.0],
        );

        let onehot = mat.to_inner_onehot();

        assert!(onehot.is_csr());
        assert_eq!(CsMat::eye(2), onehot);
    }

    #[test]
    fn onehot_sparse_csc() {
        let mat = CsMat::new_csc((2, 3), vec![0, 0, 1, 1], vec![1], vec![2.0]);

        let onehot = mat.to_inner_onehot();

        let expected =
            CsMat::new_csc((2, 3), vec![0, 0, 1, 1], vec![1], vec![1.0]);

        assert!(onehot.is_csc());
        assert_eq!(expected, onehot);
    }

    #[test]
    fn onehot_ignores_nan() {
        let mat = CsMat::new(
            (2, 2),
            vec![0, 2, 3],
            vec![0, 1, 1],
            vec![2.0, std::f64::NAN, 2.0],
        );

        let onehot = mat.to_inner_onehot();

        assert!(onehot.is_csr());
        assert_eq!(CsMat::eye(2), onehot);
    }

    #[test]
    fn mul_assign() {
        let mut m1 = crate::TriMat::new((6, 9));
        m1.add_triplet(1, 1, 8_i32);
        m1.add_triplet(1, 2, 7);
        m1.add_triplet(0, 1, 6);
        m1.add_triplet(0, 8, 5);
        m1.add_triplet(4, 2, 4);
        let mut m1: CsMat<_> = m1.to_csr();

        m1 *= 2;
        for (&v, (j, i)) in m1.iter() {
            match (j, i) {
                (1, 1) => assert_eq!(v, 16),
                (1, 2) => assert_eq!(v, 14),
                (0, 1) => assert_eq!(v, 12),
                (0, 8) => assert_eq!(v, 10),
                (4, 2) => assert_eq!(v, 8),
                _ => panic!(),
            }
        }
    }

    #[test]
    fn div_assign() {
        let mut m1 = crate::TriMat::new((6, 9));
        m1.add_triplet(1, 1, 8_i32);
        m1.add_triplet(1, 2, 7);
        m1.add_triplet(0, 1, 6);
        m1.add_triplet(0, 8, 5);
        m1.add_triplet(4, 2, 4);
        let mut m1: CsMat<_> = m1.to_csr();

        m1 /= 2;
        for (&v, (j, i)) in m1.iter() {
            match (j, i) {
                (1, 1) => assert_eq!(v, 4),
                (1, 2) => assert_eq!(v, 3),
                (0, 1) => assert_eq!(v, 3),
                (0, 8) => assert_eq!(v, 2),
                (4, 2) => assert_eq!(v, 2),
                _ => panic!(),
            }
        }
    }

    #[test]
    fn issue_99() {
        let a = crate::TriMat::<i32>::new((10, 1)).to_csc::<usize>();
        let b = crate::TriMat::<i32>::new((1, 9)).to_csr();
        let _c = &a * &b;
    }
}

#[cfg(feature = "approx")]
mod approx_impls {
    use super::*;
    use approx::*;

    impl<N, I, Iptr, IS1, DS1, ISptr1, IS2, ISptr2, DS2>
        AbsDiffEq<CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>>
        for CsMatBase<N, I, ISptr1, IS1, DS1, Iptr>
    where
        I: SpIndex,
        Iptr: SpIndex,
        CsMatBase<N, I, ISptr1, IS1, DS1, Iptr>:
            std::cmp::PartialEq<CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>>,
        IS1: Deref<Target = [I]>,
        IS2: Deref<Target = [I]>,
        ISptr1: Deref<Target = [Iptr]>,
        ISptr2: Deref<Target = [Iptr]>,
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
            other: &CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>,
            epsilon: N::Epsilon,
        ) -> bool {
            if self.shape() != other.shape() {
                return false;
            }
            if self.storage() == other.storage() {
                self.outer_iterator()
                    .zip(other.outer_iterator())
                    .all(|(r1, r2)| r1.abs_diff_eq(&r2, epsilon.clone()))
            } else {
                // Checks if all elements in self has a matching element
                // in other
                let all_matching = self.iter().all(|(n, (i, j))| {
                    n.abs_diff_eq(
                        other
                            .get(i.to_usize().unwrap(), j.to_usize().unwrap())
                            .unwrap_or(&N::zero()),
                        epsilon.clone(),
                    )
                });
                if !all_matching {
                    return false;
                }

                // Must also check if all elements in other matches self
                other.iter().all(|(n, (i, j))| {
                    n.abs_diff_eq(
                        self.get(i.to_usize().unwrap(), j.to_usize().unwrap())
                            .unwrap_or(&N::zero()),
                        epsilon.clone(),
                    )
                })
            }
        }
    }
    impl<N, I, Iptr, IS1, DS1, ISptr1, IS2, ISptr2, DS2>
        UlpsEq<CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>>
        for CsMatBase<N, I, ISptr1, IS1, DS1, Iptr>
    where
        I: SpIndex,
        Iptr: SpIndex,
        CsMatBase<N, I, ISptr1, IS1, DS1, Iptr>:
            std::cmp::PartialEq<CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>>,
        IS1: Deref<Target = [I]>,
        IS2: Deref<Target = [I]>,
        ISptr1: Deref<Target = [Iptr]>,
        ISptr2: Deref<Target = [Iptr]>,
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
            other: &CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>,
            epsilon: N::Epsilon,
            max_ulps: u32,
        ) -> bool {
            if self.shape() != other.shape() {
                return false;
            }
            if self.storage() == other.storage() {
                self.outer_iterator()
                    .zip(other.outer_iterator())
                    .all(|(r1, r2)| r1.ulps_eq(&r2, epsilon.clone(), max_ulps))
            } else {
                // Checks if all elements in self has a matching element
                // in other
                let all_matches = self.iter().all(|(n, (i, j))| {
                    n.ulps_eq(
                        other
                            .get(i.to_usize().unwrap(), j.to_usize().unwrap())
                            .unwrap_or(&N::zero()),
                        epsilon.clone(),
                        max_ulps,
                    )
                });
                if !all_matches {
                    return false;
                }

                // Must also check if all elements in other matches self
                other.iter().all(|(n, (i, j))| {
                    n.ulps_eq(
                        self.get(i.to_usize().unwrap(), j.to_usize().unwrap())
                            .unwrap_or(&N::zero()),
                        epsilon.clone(),
                        max_ulps,
                    )
                })
            }
        }
    }
    impl<N, I, Iptr, IS1, DS1, ISptr1, IS2, ISptr2, DS2>
        RelativeEq<CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>>
        for CsMatBase<N, I, ISptr1, IS1, DS1, Iptr>
    where
        I: SpIndex,
        Iptr: SpIndex,
        CsMatBase<N, I, ISptr1, IS1, DS1, Iptr>:
            std::cmp::PartialEq<CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>>,
        IS1: Deref<Target = [I]>,
        IS2: Deref<Target = [I]>,
        ISptr1: Deref<Target = [Iptr]>,
        ISptr2: Deref<Target = [Iptr]>,
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
            other: &CsMatBase<N, I, ISptr2, IS2, DS2, Iptr>,
            epsilon: N::Epsilon,
            max_relative: Self::Epsilon,
        ) -> bool {
            if self.shape() != other.shape() {
                return false;
            }
            if self.storage() == other.storage() {
                self.outer_iterator().zip(other.outer_iterator()).all(
                    |(r1, r2)| {
                        r1.relative_eq(
                            &r2,
                            epsilon.clone(),
                            max_relative.clone(),
                        )
                    },
                )
            } else {
                // Checks if all elements in self has a matching element
                // in other
                let all_matches = self.iter().all(|(n, (i, j))| {
                    n.relative_eq(
                        other
                            .get(i.to_usize().unwrap(), j.to_usize().unwrap())
                            .unwrap_or(&N::zero()),
                        epsilon.clone(),
                        max_relative.clone(),
                    )
                });
                if !all_matches {
                    return false;
                }

                // Must also check if all elements in other matches self
                other.iter().all(|(n, (i, j))| {
                    n.relative_eq(
                        self.get(i.to_usize().unwrap(), j.to_usize().unwrap())
                            .unwrap_or(&N::zero()),
                        epsilon.clone(),
                        max_relative.clone(),
                    )
                })
            }
        }
    }

    #[cfg(test)]
    mod tests {
        use crate::*;

        #[test]
        fn different_shapes() {
            let mut m1 = TriMat::new((3, 2));
            m1.add_triplet(1, 1, 8_u8);
            let m1: CsMat<_> = m1.to_csr();
            let mut m2 = TriMat::new((2, 3));
            m2.add_triplet(1, 1, 8_u8);
            let m2 = m2.to_csr();

            ::approx::assert_abs_diff_ne!(m1, m2);
            ::approx::assert_abs_diff_ne!(m1, m2.to_csc());
            ::approx::assert_abs_diff_ne!(m1.to_csc(), m2);
            ::approx::assert_abs_diff_ne!(m1.to_csc(), m2.to_csc());
        }

        #[test]
        fn equal_elements() {
            let mut m1 = TriMat::new((6, 9));
            m1.add_triplet(1, 1, 8_u8);
            m1.add_triplet(1, 2, 7_u8);
            m1.add_triplet(0, 1, 6_u8);
            m1.add_triplet(0, 8, 5_u8);
            m1.add_triplet(4, 2, 4_u8);

            let m1: CsMat<_> = m1.to_csr();
            let m2 = m1.clone();

            ::approx::assert_abs_diff_eq!(m1, m2, epsilon = 0);
            ::approx::assert_abs_diff_eq!(m1.to_csc(), m2, epsilon = 0);
            ::approx::assert_abs_diff_eq!(m1, m2.to_csc(), epsilon = 0);
            ::approx::assert_abs_diff_eq!(
                m1.to_csc(),
                m2.to_csc(),
                epsilon = 0
            );

            let mut m1 = TriMat::new((6, 9));
            m1.add_triplet(1, 1, 8.0_f32);
            m1.add_triplet(1, 2, 7.0);
            m1.add_triplet(0, 1, 6.0);
            m1.add_triplet(0, 8, 5.0);
            m1.add_triplet(4, 2, 4.0);

            let m1: CsMat<_> = m1.to_csr();
            let m2 = m1.clone();

            ::approx::assert_abs_diff_eq!(m1, m2);
            ::approx::assert_abs_diff_eq!(m1.to_csc(), m2);
            ::approx::assert_abs_diff_eq!(m1, m2.to_csc());
            ::approx::assert_abs_diff_eq!(m1.to_csc(), m2.to_csc());

            ::approx::assert_relative_eq!(m1, m2);
            ::approx::assert_relative_eq!(m1.to_csc(), m2);
            ::approx::assert_relative_eq!(m1, m2.to_csc());
            ::approx::assert_relative_eq!(m1.to_csc(), m2.to_csc());

            ::approx::assert_ulps_eq!(m1, m2);
            ::approx::assert_ulps_eq!(m1.to_csc(), m2);
            ::approx::assert_ulps_eq!(m1, m2.to_csc());
            ::approx::assert_ulps_eq!(m1.to_csc(), m2.to_csc());
        }

        #[test]
        fn almost_equal_elements() {
            let mut m1 = TriMat::new((6, 9));
            m1.add_triplet(1, 1, 8.0_f32);
            m1.add_triplet(1, 2, 7.0);
            m1.add_triplet(0, 1, 6.0);
            m1.add_triplet(0, 8, 5.0);
            m1.add_triplet(4, 2, 4.0);
            let m1: CsMat<_> = m1.to_csr();

            let mut m2 = TriMat::new((6, 9));
            m2.add_triplet(1, 1, 8.0_f32);
            m2.add_triplet(1, 2, 7.0 - 0.5); // 0.5 subtracted
            m2.add_triplet(0, 1, 6.0);
            m2.add_triplet(0, 8, 5.0);
            m2.add_triplet(4, 2, 4.0);
            m2.add_triplet(4, 3, 0.2); // extra element
            let m2 = m2.to_csr();

            ::approx::assert_abs_diff_eq!(m1, m2, epsilon = 0.6);
            ::approx::assert_abs_diff_eq!(m1.to_csc(), m2, epsilon = 0.6);
            ::approx::assert_abs_diff_eq!(m1, m2.to_csc(), epsilon = 0.6);
            ::approx::assert_abs_diff_eq!(
                m1.to_csc(),
                m2.to_csc(),
                epsilon = 0.6
            );

            ::approx::assert_abs_diff_ne!(m1, m2, epsilon = 0.4);
            ::approx::assert_abs_diff_ne!(m1.to_csc(), m2, epsilon = 0.4);
            ::approx::assert_abs_diff_ne!(m1, m2.to_csc(), epsilon = 0.4);
            ::approx::assert_abs_diff_ne!(
                m1.to_csc(),
                m2.to_csc(),
                epsilon = 0.4
            );
        }
    }
}
