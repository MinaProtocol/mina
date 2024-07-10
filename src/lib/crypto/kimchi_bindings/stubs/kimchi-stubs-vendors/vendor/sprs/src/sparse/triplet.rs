use crate::indexing::SpIndex;
use crate::sparse::prelude::*;

///! Triplet format matrix
///!
///! Useful for building a matrix, but not for computations. Therefore this
///! struct is mainly used to initialize a matrix before converting to
///! to a [`CsMat`](CsMatBase).
///!
///! A triplet format matrix is formed of three arrays of equal length, storing
///! the row indices, the column indices, and the values of the non-zero
///! entries. By convention, duplicate locations are summed up when converting
///! into `CsMat`.
use std::ops::{Add, Deref, DerefMut};
use std::slice::Iter;

/// Indexing type into a Triplet
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TripletIndex(pub usize);

impl<'a, N, I, IS, DS> IntoIterator for &'a TriMatBase<IS, DS>
where
    I: 'a + SpIndex,
    N: 'a,
    IS: Deref<Target = [I]>,
    DS: Deref<Target = [N]>,
{
    type Item = (&'a N, (I, I));
    type IntoIter = TriMatIter<Iter<'a, I>, Iter<'a, I>, Iter<'a, N>>;
    fn into_iter(self) -> Self::IntoIter {
        self.triplet_iter()
    }
}

impl<'a, N, I> IntoIterator for TriMatViewI<'a, N, I>
where
    I: SpIndex,
{
    type Item = (&'a N, (I, I));
    type IntoIter = TriMatIter<Iter<'a, I>, Iter<'a, I>, Iter<'a, N>>;
    fn into_iter(self) -> Self::IntoIter {
        self.triplet_iter_rbr()
    }
}

impl<N, I, IS, DS> SparseMat for TriMatBase<IS, DS>
where
    I: SpIndex,
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

impl<'a, N, I, IS, DS> SparseMat for &'a TriMatBase<IS, DS>
where
    I: 'a + SpIndex,
    N: 'a,
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

/// # Methods for creating triplet matrices that own their data.
impl<N, I: SpIndex> TriMatI<N, I> {
    /// Create a new triplet matrix of shape `(nb_rows, nb_cols)`
    pub fn new(shape: (usize, usize)) -> Self {
        Self {
            rows: shape.0,
            cols: shape.1,
            row_inds: Vec::new(),
            col_inds: Vec::new(),
            data: Vec::new(),
        }
    }

    /// Create a new triplet matrix of shape `(nb_rows, nb_cols)`, and
    /// pre-allocate `cap` elements on the backing storage
    pub fn with_capacity(shape: (usize, usize), cap: usize) -> Self {
        Self {
            rows: shape.0,
            cols: shape.1,
            row_inds: Vec::with_capacity(cap),
            col_inds: Vec::with_capacity(cap),
            data: Vec::with_capacity(cap),
        }
    }

    /// Create a triplet matrix from its raw components. All arrays should
    /// have the same length.
    ///
    /// # Panics
    ///
    /// - if the arrays don't have the same length
    /// - if either the row or column indices are out of bounds.
    pub fn from_triplets(
        shape: (usize, usize),
        row_inds: Vec<I>,
        col_inds: Vec<I>,
        data: Vec<N>,
    ) -> Self {
        assert_eq!(
            row_inds.len(),
            col_inds.len(),
            "all inputs should have the same length"
        );
        assert_eq!(
            data.len(),
            col_inds.len(),
            "all inputs should have the same length"
        );
        assert_eq!(
            row_inds.len(),
            data.len(),
            "all inputs should have the same length"
        );
        assert!(
            row_inds.iter().all(|&i| i.index() < shape.0),
            "row indices should be within shape"
        );
        assert!(
            col_inds.iter().all(|&j| j.index() < shape.1),
            "col indices should be within shape"
        );
        Self {
            rows: shape.0,
            cols: shape.1,
            row_inds,
            col_inds,
            data,
        }
    }

    /// Append a non-zero triplet to this matrix.
    pub fn add_triplet(&mut self, row: usize, col: usize, val: N) {
        assert!(row < self.rows);
        assert!(col < self.cols);
        self.row_inds.push(I::from_usize(row));
        self.col_inds.push(I::from_usize(col));
        self.data.push(val);
    }

    /// Reserve `cap` additional non-zeros
    pub fn reserve(&mut self, cap: usize) {
        self.row_inds.reserve(cap);
        self.col_inds.reserve(cap);
        self.data.reserve(cap);
    }

    /// Reserve exactly `cap` non-zeros
    pub fn reserve_exact(&mut self, cap: usize) {
        self.row_inds.reserve_exact(cap);
        self.col_inds.reserve_exact(cap);
        self.data.reserve_exact(cap);
    }
}

/// # Common methods shared by all variants of triplet matrices
impl<N, I: SpIndex, IStorage, DStorage> TriMatBase<IStorage, DStorage>
where
    IStorage: Deref<Target = [I]>,
    DStorage: Deref<Target = [N]>,
{
    /// The number of rows of the matrix
    pub fn rows(&self) -> usize {
        self.rows
    }

    /// The number of cols of the matrix
    pub fn cols(&self) -> usize {
        self.cols
    }

    /// The shape of the matrix, as a `(rows, cols)` tuple
    pub fn shape(&self) -> (usize, usize) {
        (self.rows, self.cols)
    }

    /// The number of non-zero entries
    pub fn nnz(&self) -> usize {
        self.data.len()
    }

    /// The non-zero row indices
    pub fn row_inds(&self) -> &[I] {
        &self.row_inds[..]
    }

    /// The non-zero column indices
    pub fn col_inds(&self) -> &[I] {
        &self.col_inds[..]
    }

    /// The non-zero values
    pub fn data(&self) -> &[N] {
        &self.data[..]
    }

    /// Find all non-zero entries at the location given by `row` and `col`
    pub fn find_locations(&self, row: usize, col: usize) -> Vec<TripletIndex> {
        self.row_inds
            .iter()
            .zip(self.col_inds.iter())
            .enumerate()
            .filter_map(|(ind, (&i, &j))| {
                if i.index_unchecked() == row && j.index_unchecked() == col {
                    Some(TripletIndex(ind))
                } else {
                    None
                }
            })
            .collect()
    }

    /// Get a transposed view of this matrix
    pub fn transpose_view(&self) -> TriMatViewI<N, I> {
        TriMatViewI {
            rows: self.cols,
            cols: self.rows,
            row_inds: &self.col_inds[..],
            col_inds: &self.row_inds[..],
            data: &self.data[..],
        }
    }

    /// Get an iterator over non-zero elements stored by this matrix
    pub fn triplet_iter(&self) -> TriMatIter<Iter<I>, Iter<I>, Iter<N>> {
        TriMatIter {
            rows: self.rows,
            cols: self.cols,
            nnz: self.nnz(),
            row_inds: self.row_inds.iter(),
            col_inds: self.col_inds.iter(),
            data: self.data.iter(),
        }
    }

    /// Create a CSC matrix from this triplet matrix
    pub fn to_csc<Iptr: SpIndex>(&self) -> CsMatI<N, I, Iptr>
    where
        N: Clone + Add<Output = N>,
    {
        self.triplet_iter().into_csc()
    }

    /// Create a CSR matrix from this triplet matrix
    pub fn to_csr<Iptr: SpIndex>(&self) -> CsMatI<N, I, Iptr>
    where
        N: Clone + Add<Output = N>,
    {
        self.triplet_iter().into_csr()
    }

    pub fn view(&self) -> TriMatViewI<N, I> {
        TriMatViewI {
            rows: self.rows,
            cols: self.cols,
            row_inds: &self.row_inds[..],
            col_inds: &self.col_inds[..],
            data: &self.data[..],
        }
    }
}

impl<'a, N, I: SpIndex> TriMatBase<&'a [I], &'a [N]> {
    /// Get an iterator over non-zero elements stored by this matrix
    ///
    /// Reborrowing version of `triplet_iter()`.
    pub fn triplet_iter_rbr(
        &self,
    ) -> TriMatIter<Iter<'a, I>, Iter<'a, I>, Iter<'a, N>> {
        TriMatIter {
            rows: self.rows,
            cols: self.cols,
            nnz: self.nnz(),
            row_inds: self.row_inds.iter(),
            col_inds: self.col_inds.iter(),
            data: self.data.iter(),
        }
    }
}

impl<N, I: SpIndex, IStorage, DStorage> TriMatBase<IStorage, DStorage>
where
    IStorage: DerefMut<Target = [I]>,
    DStorage: DerefMut<Target = [N]>,
{
    /// Replace a non-zero value at the given index.
    /// Indices can be obtained using [`find_locations`](Self::find_locations).
    pub fn set_triplet(
        &mut self,
        TripletIndex(triplet_ind): TripletIndex,
        row: usize,
        col: usize,
        val: N,
    ) {
        self.row_inds[triplet_ind] = I::from_usize(row);
        self.col_inds[triplet_ind] = I::from_usize(col);
        self.data[triplet_ind] = val;
    }

    pub fn view_mut(&mut self) -> TriMatViewMutI<N, I> {
        TriMatViewMutI {
            rows: self.rows,
            cols: self.cols,
            row_inds: &mut self.row_inds[..],
            col_inds: &mut self.col_inds[..],
            data: &mut self.data[..],
        }
    }
}

#[cfg(test)]
mod test {

    use super::{TriMat, TriMatI};
    use crate::sparse::{CsMat, CsMatI};

    #[test]
    fn triplet_incremental() {
        let mut triplet_mat = TriMatI::with_capacity((4, 4), 6);
        // |1 2    |
        // |3      |
        // |      4|
        // |    5 6|
        triplet_mat.add_triplet(0, 0, 1.);
        triplet_mat.add_triplet(0, 1, 2.);
        triplet_mat.add_triplet(1, 0, 3.);
        triplet_mat.add_triplet(2, 3, 4.);
        triplet_mat.add_triplet(3, 2, 5.);
        triplet_mat.add_triplet(3, 3, 6.);

        let csc: CsMatI<_, i32> = triplet_mat.to_csc();
        let expected = CsMatI::new_csc(
            (4, 4),
            vec![0, 2, 3, 4, 6],
            vec![0, 1, 0, 3, 2, 3],
            vec![1., 3., 2., 5., 4., 6.],
        );
        assert_eq!(csc, expected);
    }

    #[test]
    fn triplet_unordered() {
        let mut triplet_mat = TriMat::with_capacity((4, 4), 6);
        // |1 2    |
        // |3      |
        // |      4|
        // |    5 6|

        // the only difference with the triplet_incremental test is that
        // the triplets are added with non-sorted indices, therefore
        // testing the ability of the conversion to yield sorted output
        triplet_mat.add_triplet(0, 1, 2.);
        triplet_mat.add_triplet(0, 0, 1.);
        triplet_mat.add_triplet(1, 0, 3.);
        triplet_mat.add_triplet(2, 3, 4.);
        triplet_mat.add_triplet(3, 3, 6.);
        triplet_mat.add_triplet(3, 2, 5.);

        let expected = CsMat::new_csc(
            (4, 4),
            vec![0, 2, 3, 4, 6],
            vec![0, 1, 0, 3, 2, 3],
            vec![1., 3., 2., 5., 4., 6.],
        );

        let csc = triplet_mat.to_csc();
        assert_eq!(csc, expected);

        let csr_to_csc = triplet_mat.to_csr().to_csc();
        assert_eq!(csr_to_csc, expected);
    }

    #[test]
    fn triplet_additions() {
        let mut triplet_mat = TriMat::with_capacity((4, 4), 6);
        // |1 2    |
        // |3      |
        // |      4|
        // |    5 6|

        // here we test the additive properties of triples
        // the (3, 2) nnz element is specified twice
        triplet_mat.add_triplet(0, 1, 2.);
        triplet_mat.add_triplet(0, 0, 1.);
        triplet_mat.add_triplet(3, 2, 3.);
        triplet_mat.add_triplet(1, 0, 3.);
        triplet_mat.add_triplet(2, 3, 4.);
        triplet_mat.add_triplet(3, 3, 6.);
        triplet_mat.add_triplet(3, 2, 2.);

        let csc = triplet_mat.to_csc();
        let csr = triplet_mat.to_csr();
        let expected = CsMat::new_csc(
            (4, 4),
            vec![0, 2, 3, 4, 6],
            vec![0, 1, 0, 3, 2, 3],
            vec![1., 3., 2., 5., 4., 6.],
        );
        assert_eq!(csc, expected);
        assert_eq!(csr, expected.to_csr());
    }

    #[test]
    fn triplet_from_vecs() {
        // |1 2    |
        // |3      |
        // |      4|
        // |    5 6|
        // |  7   8|
        let row_inds = vec![0, 0, 1, 2, 3, 3, 4, 4];
        let col_inds = vec![0, 1, 0, 3, 2, 3, 1, 3];
        let data = vec![1, 2, 3, 4, 5, 6, 7, 8];

        let triplet_mat =
            super::TriMat::from_triplets((5, 4), row_inds, col_inds, data);

        let csc = triplet_mat.to_csc();
        let csr = triplet_mat.to_csr();
        let expected = CsMat::new_csc(
            (5, 4),
            vec![0, 2, 4, 5, 8],
            vec![0, 1, 0, 4, 3, 2, 3, 4],
            vec![1, 3, 2, 7, 5, 4, 6, 8],
        );

        assert_eq!(csc, expected);
        assert_eq!(csr, expected.to_csr());
    }

    #[test]
    fn triplet_mutate_entry() {
        let mut triplet_mat = TriMat::with_capacity((4, 4), 6);
        triplet_mat.add_triplet(0, 0, 1.);
        triplet_mat.add_triplet(0, 1, 2.);
        triplet_mat.add_triplet(1, 0, 3.);
        triplet_mat.add_triplet(2, 3, 4.);
        triplet_mat.add_triplet(3, 2, 5.);
        triplet_mat.add_triplet(3, 3, 6.);

        let locations = triplet_mat.find_locations(2, 3);
        assert_eq!(locations.len(), 1);
        triplet_mat.set_triplet(locations[0], 2, 3, 0.);

        let csc = triplet_mat.to_csc();
        let csr = triplet_mat.to_csr();
        let expected = CsMat::new_csc(
            (4, 4),
            vec![0, 2, 3, 4, 6],
            vec![0, 1, 0, 3, 2, 3],
            vec![1., 3., 2., 5., 0., 6.],
        );
        assert_eq!(csc, expected);
        assert_eq!(csr, expected.to_csr());
    }

    #[test]
    fn triplet_to_csr() {
        let mut triplet_mat = TriMat::with_capacity((4, 4), 6);
        // |1 2    |
        // |3      |
        // |      4|
        // |    5 6|

        // here we test the additive properties of triples
        // the (3, 2) nnz element is specified twice
        triplet_mat.add_triplet(0, 1, 2.);
        triplet_mat.add_triplet(0, 0, 1.);
        triplet_mat.add_triplet(3, 2, 3.);
        triplet_mat.add_triplet(1, 0, 3.);
        triplet_mat.add_triplet(2, 3, 4.);
        triplet_mat.add_triplet(3, 3, 6.);
        triplet_mat.add_triplet(3, 2, 2.);

        let csr = triplet_mat.to_csr();
        let csc = triplet_mat.to_csc();

        let expected = CsMat::new_csc(
            (4, 4),
            vec![0, 2, 3, 4, 6],
            vec![0, 1, 0, 3, 2, 3],
            vec![1., 3., 2., 5., 4., 6.],
        );

        assert_eq!(csc, expected);
        assert_eq!(csr, expected.to_csr());
    }

    #[test]
    fn triplet_complex() {
        // |1       6       2|
        // |1         1     2|
        // |1 2   3     3   2|
        // |1   9     4     2|
        // |1     5         2|
        // |1         7   8 2|
        let mut triplet_mat = TriMat::with_capacity((6, 9), 22);

        triplet_mat.add_triplet(5, 8, 1); // (a) push 1 later
        triplet_mat.add_triplet(0, 0, 1);
        triplet_mat.add_triplet(0, 8, 2);
        triplet_mat.add_triplet(0, 4, 2); // (b) push 4 later
        triplet_mat.add_triplet(2, 0, 1);
        triplet_mat.add_triplet(2, 1, 2);
        triplet_mat.add_triplet(2, 3, 2); // (c) push 1 later
        triplet_mat.add_triplet(2, 6, 3);
        triplet_mat.add_triplet(2, 8, 2);
        triplet_mat.add_triplet(1, 0, 1);
        triplet_mat.add_triplet(1, 5, 1);
        triplet_mat.add_triplet(1, 8, 1); // (d) push 1 later
        triplet_mat.add_triplet(0, 4, 4); // push the missing 4 (b)
        triplet_mat.add_triplet(3, 8, 2);
        triplet_mat.add_triplet(3, 5, 4);
        triplet_mat.add_triplet(5, 8, 1); // push the missing 1 (a)
        triplet_mat.add_triplet(3, 2, 9);
        triplet_mat.add_triplet(3, 0, 1);
        triplet_mat.add_triplet(4, 0, 1);
        triplet_mat.add_triplet(4, 8, 2);
        triplet_mat.add_triplet(1, 8, 1); // push the missing 1 (d)
        triplet_mat.add_triplet(4, 3, 5);
        triplet_mat.add_triplet(5, 0, 1);
        triplet_mat.add_triplet(5, 5, 7);
        triplet_mat.add_triplet(2, 3, 1); // push the missing 1 (c)
        triplet_mat.add_triplet(5, 7, 8);

        let csc = triplet_mat.to_csc();

        let expected = CsMat::new_csc(
            (6, 9),
            vec![0, 6, 7, 8, 10, 11, 14, 15, 16, 22],
            vec![
                0, 1, 2, 3, 4, 5, 2, 3, 2, 4, 0, 1, 3, 5, 2, 5, 0, 1, 2, 3, 4,
                5,
            ],
            vec![
                1, 1, 1, 1, 1, 1, 2, 9, 3, 5, 6, 1, 4, 7, 3, 8, 2, 2, 2, 2, 2,
                2,
            ],
        );

        assert_eq!(csc, expected);

        let csr = triplet_mat.to_csr();
        assert_eq!(csr, expected.to_csr());
    }

    #[test]
    fn triplet_empty_lines() {
        // regression test for https://github.com/vbarrielle/sprs/issues/170
        let tri_mat = TriMatI::new((2, 4));
        let m: CsMat<u64> = tri_mat.to_csr();
        assert_eq!(m.indptr(), &[0, 0, 0][..]);
        assert_eq!(m.indices(), &[]);
        assert_eq!(m.data(), &[]);

        let m: CsMat<u64> = tri_mat.to_csc();
        assert_eq!(m.indptr(), &[0, 0, 0, 0, 0][..]);
        assert_eq!(m.indices(), &[]);
        assert_eq!(m.data(), &[]);

        // More complex matrix with empty lines/cols inside
        // |1 . . . 6 . . . 2|
        // |. . . . . . . . .|
        // |1 2 . 3 . . . . 2|
        // |1 . . . . 4 . . 2|
        // |1 . . 5 . . . . 2|
        // |1 . . . . 7 . . 2|
        let mut triplet_mat = TriMat::with_capacity((6, 9), 22);

        triplet_mat.add_triplet(5, 8, 1); // (a) push 1 later
        triplet_mat.add_triplet(0, 0, 1);
        triplet_mat.add_triplet(0, 8, 2);
        triplet_mat.add_triplet(0, 4, 2); // (b) push 4 later
        triplet_mat.add_triplet(2, 0, 1);
        triplet_mat.add_triplet(2, 1, 2);
        triplet_mat.add_triplet(2, 3, 2); // (c) push 1 later
        triplet_mat.add_triplet(2, 8, 2);
        triplet_mat.add_triplet(0, 4, 4); // push the missing 4 (b)
        triplet_mat.add_triplet(3, 8, 2);
        triplet_mat.add_triplet(3, 5, 4);
        triplet_mat.add_triplet(5, 8, 1); // push the missing 1 (a)
        triplet_mat.add_triplet(3, 0, 1);
        triplet_mat.add_triplet(4, 0, 1);
        triplet_mat.add_triplet(4, 8, 2);
        triplet_mat.add_triplet(4, 3, 5);
        triplet_mat.add_triplet(5, 0, 1);
        triplet_mat.add_triplet(5, 5, 7);
        triplet_mat.add_triplet(2, 3, 1); // push the missing 1 (c)

        let csc = triplet_mat.to_csc();

        let expected = CsMat::new_csc(
            (6, 9),
            vec![0, 5, 6, 6, 8, 9, 11, 11, 11, 16],
            vec![0, 2, 3, 4, 5, 2, 2, 4, 0, 3, 5, 0, 2, 3, 4, 5],
            vec![1, 1, 1, 1, 1, 2, 3, 5, 6, 4, 7, 2, 2, 2, 2, 2],
        );

        assert_eq!(csc, expected);

        let csr = triplet_mat.to_csr();
        assert_eq!(csr, expected.to_csr());

        // Matrix ending with several empty lines/columns
        // |. . . 2 . . |
        // |. 1 . . . . |
        // |. . . . . . |
        // |. . . . . . |
        let mut triplet_mat = TriMat::with_capacity((4, 6), 2);

        triplet_mat.add_triplet(1, 1, 1);
        triplet_mat.add_triplet(0, 3, 2);

        let m = triplet_mat.to_csc();
        assert_eq!(m.indptr(), &[0, 0, 1, 1, 2, 2, 2][..]);
        assert_eq!(m.indices(), &[1, 0]);
        assert_eq!(m.data(), &[1, 2]);
    }
}
