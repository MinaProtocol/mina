//! A structure for iterating over the non-zero values of any kind of
//! sparse matrix.

use std::ops::Add;

use crate::indexing::SpIndex;
use crate::sparse::{CsMatI, TriMatIter};
use crate::CompressedStorage;

impl<'a, N, I, RI, CI, DI> Iterator for TriMatIter<RI, CI, DI>
where
    I: 'a + SpIndex,
    N: 'a,
    RI: Iterator<Item = &'a I>,
    CI: Iterator<Item = &'a I>,
    DI: Iterator<Item = &'a N>,
{
    type Item = (&'a N, (I, I));

    fn next(&mut self) -> Option<<Self as Iterator>::Item> {
        match (self.row_inds.next(), self.col_inds.next(), self.data.next()) {
            (Some(row), Some(col), Some(val)) => Some((val, (*row, *col))),
            _ => None,
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.row_inds.size_hint() // FIXME merge hints?
    }
}

impl<'a, N, I, RI, CI, DI> TriMatIter<RI, CI, DI>
where
    I: 'a + SpIndex,
    N: 'a,
    RI: Iterator<Item = &'a I>,
    CI: Iterator<Item = &'a I>,
    DI: Iterator<Item = &'a N>,
{
    /// Create a new `TriMatIter` from iterators
    pub fn new(
        shape: (usize, usize),
        nnz: usize,
        row_inds: RI,
        col_inds: CI,
        data: DI,
    ) -> Self {
        Self {
            rows: shape.0,
            cols: shape.1,
            nnz,
            row_inds,
            col_inds,
            data,
        }
    }

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
        self.nnz
    }

    pub fn into_row_inds(self) -> RI {
        self.row_inds
    }

    pub fn into_col_inds(self) -> CI {
        self.col_inds
    }

    pub fn into_data(self) -> DI {
        self.data
    }

    pub fn transpose_into(self) -> TriMatIter<CI, RI, DI> {
        TriMatIter {
            rows: self.cols,
            cols: self.rows,
            nnz: self.nnz,
            row_inds: self.col_inds,
            col_inds: self.row_inds,
            data: self.data,
        }
    }
}

impl<'a, N, I, RI, CI, DI> TriMatIter<RI, CI, DI>
where
    I: 'a + SpIndex,
    N: 'a + Clone,
    RI: Clone + Iterator<Item = &'a I>,
    CI: Clone + Iterator<Item = &'a I>,
    DI: Clone + Iterator<Item = &'a N>,
{
    /// Consume `TriMatIter` and produce a CSC matrix
    pub fn into_csc<Iptr: SpIndex>(self) -> CsMatI<N, I, Iptr>
    where
        N: Add<Output = N>,
    {
        self.into_cs(CompressedStorage::CSC)
    }

    /// Consume `TriMatIter` and produce a CSR matrix
    pub fn into_csr<Iptr: SpIndex>(self) -> CsMatI<N, I, Iptr>
    where
        N: Add<Output = N>,
    {
        self.into_cs(CompressedStorage::CSR)
    }

    /// Consume `TriMatIter` and produce a `CsMat` matrix with the chosen storage
    pub fn into_cs<Iptr: SpIndex>(
        self,
        storage: crate::CompressedStorage,
    ) -> CsMatI<N, I, Iptr>
    where
        N: Add<Output = N>,
    {
        // (i,j, input position, output position)
        let mut rc: Vec<(I, I, N)> = Vec::new();

        let mut nnz_max = 0;
        for (v, (i, j)) in self.clone() {
            rc.push((i, j, v.clone()));
            nnz_max += 1;
        }

        match storage {
            CompressedStorage::CSR => {
                rc.sort_unstable_by_key(|i| (i.0, i.1));
            }
            CompressedStorage::CSC => {
                rc.sort_unstable_by_key(|i| (i.1, i.0));
            }
        }

        let outer_idx = |idx_r: I, idx_c: I| match storage {
            CompressedStorage::CSR => idx_r,
            CompressedStorage::CSC => idx_c,
        };

        let outer_dims = match storage {
            CompressedStorage::CSR => self.rows(),
            CompressedStorage::CSC => self.cols(),
        };

        let mut slot = 0;
        let mut indptr = vec![Iptr::zero(); outer_dims + 1];
        let mut cur_outer = I::zero();

        for rec in 0..nnz_max {
            if rec > 0 {
                if rc[rec - 1].0 == rc[rec].0 && rc[rec - 1].1 == rc[rec].1 {
                    // got a duplicate - add the value in the current slot.
                    rc[slot].2 = rc[slot].2.clone() + rc[rec].2.clone();
                } else {
                    // new cell -- fill it out
                    slot += 1;
                    rc[slot] = rc[rec].clone();
                }
            }

            let new_outer = outer_idx(rc[rec].0, rc[rec].1);

            while new_outer > cur_outer {
                indptr[cur_outer.index() + 1] = Iptr::from_usize(slot);
                cur_outer += I::one();
            }
        }

        // Ensure that slot == nnz
        if nnz_max > 0 {
            slot += 1;
        }
        // fill indptr up to the end
        while I::from_usize(outer_dims) > cur_outer {
            indptr[cur_outer.index() + 1] = Iptr::from_usize(slot);
            cur_outer += I::one();
        }

        rc.truncate(slot);

        let mut data: Vec<N> = Vec::with_capacity(slot);
        let mut indices: Vec<I> = vec![I::zero(); slot];

        for (n, (i, j, v)) in rc.into_iter().enumerate() {
            assert!({
                let outer = outer_idx(i, j);
                n >= indptr[outer.index()].index()
                    && n < indptr[outer.index() + 1].index()
            });

            data.push(v);

            match storage {
                CompressedStorage::CSR => indices[n] = j,
                CompressedStorage::CSC => indices[n] = i,
            }
        }

        CsMatI {
            storage,
            nrows: self.rows,
            ncols: self.cols,
            indptr: crate::IndPtr::new_trusted(indptr),
            indices,
            data,
        }
    }
}
