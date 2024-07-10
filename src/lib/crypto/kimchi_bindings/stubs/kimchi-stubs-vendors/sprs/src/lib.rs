/*!

sprs is a sparse linear algebra library for Rust.

It features a sparse matrix type, [**`CsMat`**](struct.CsMatBase.html), and a sparse vector type,
[**`CsVec`**](struct.CsVecBase.html), both based on the
[compressed storage scheme](https://en.wikipedia.org/wiki/Sparse_matrix#Compressed_sparse_row_.28CSR.2C_CRS_or_Yale_format.29).

## Features

- sparse matrix/sparse matrix addition, multiplication.
- sparse vector/sparse vector addition, dot product.
- sparse matrix/dense matrix addition, multiplication.
- sparse triangular solves.
- powerful iteration over the sparse structure, enabling easy extension of the library.
- matrix construction using the [triplet format](struct.TriMatBase.html),
  vertical and horizontal stacking, block construction.
- sparse cholesky solver in the separate crate `sprs-ldl`.
- fully generic integer type for the storage of indices, enabling compact
  representations.
- planned interoperability with existing sparse solvers such as `SuiteSparse`.

## Quick Examples


Matrix construction:

```rust
use sprs::{CsMat, TriMat};

let mut a = TriMat::new((4, 4));
a.add_triplet(0, 0, 3.0_f64);
a.add_triplet(1, 2, 2.0);
a.add_triplet(3, 0, -2.0);

// This matrix type does not allow computations, and must to
// converted to a compatible sparse type, using for example
let b: CsMat<_> = a.to_csr();
```

Constructing matrix using the more efficient direct sparse constructor

```rust
use sprs::{CsMat, CsVec};
let eye : CsMat<f64> = CsMat::eye(3);
let a = CsMat::new_csc((3, 3),
                       vec![0, 2, 4, 5],
                       vec![0, 1, 0, 2, 2],
                       vec![1., 2., 3., 4., 5.]);
```

Matrix vector multiplication:

```rust
use sprs::{CsMat, CsVec};
let eye = CsMat::eye(5);
let x = CsVec::new(5, vec![0, 2, 4], vec![1., 2., 3.]);
let y = &eye * &x;
assert_eq!(x, y);
```

Matrix matrix multiplication, addition:

```rust
use sprs::{CsMat, CsVec};
let eye = CsMat::eye(3);
let a = CsMat::new_csc((3, 3),
                       vec![0, 2, 4, 5],
                       vec![0, 1, 0, 2, 2],
                       vec![1., 2., 3., 4., 5.]);
let b = &eye * &a;
assert_eq!(a, b.to_csc());
```

*/
#![allow(clippy::redundant_slicing)]

pub mod array_backend;
mod dense_vector;
pub mod errors;
pub mod indexing;
pub mod io;
mod mul_acc;
pub mod num_kinds;
pub mod num_matrixmarket;
mod range;
mod sparse;
pub mod stack;

pub type Ix1 = ndarray::Ix1;
pub type Ix2 = ndarray::Ix2;

pub use crate::indexing::SpIndex;

pub use crate::sparse::{
    csmat::CsIter,
    indptr::{IndPtr, IndPtrBase, IndPtrView},
    kronecker::kronecker_product,
    CsMat, CsMatBase, CsMatI, CsMatVecView, CsMatView, CsMatViewI,
    CsMatViewMut, CsMatViewMutI, CsStructure, CsStructureI, CsStructureView,
    CsStructureViewI, CsVec, CsVecBase, CsVecI, CsVecView, CsVecViewI,
    CsVecViewMut, CsVecViewMutI, SparseMat, TriMat, TriMatBase, TriMatI,
    TriMatIter, TriMatView, TriMatViewI, TriMatViewMut, TriMatViewMutI,
};

pub use crate::dense_vector::{DenseVector, DenseVectorMut};
pub use crate::mul_acc::MulAcc;

pub use crate::sparse::symmetric::is_symmetric;

pub use crate::sparse::permutation::{
    perm_is_valid, transform_mat_papt, PermOwned, PermOwnedI, PermView,
    PermViewI, Permutation,
};

pub use crate::sparse::CompressedStorage::{self, CSC, CSR};

pub use crate::sparse::binop;
pub use crate::sparse::linalg;
pub use crate::sparse::prod;
pub use crate::sparse::smmp;
pub use crate::sparse::special_mats;
pub use crate::sparse::visu;

pub mod vec {
    pub use crate::sparse::{CsVec, CsVecBase, CsVecView, CsVecViewMut};

    pub use crate::sparse::vec::{
        IntoSparseVecIter, NnzEither, NnzIndex, NnzOrZip, SparseIterTools,
        VecDim, VectorIterator, VectorIteratorMut,
    };
}

pub use crate::sparse::construct::{bmat, hstack, vstack};

pub use crate::sparse::to_dense::assign_to_dense;

/// The shape of a matrix. This a 2-tuple with the first element indicating
/// the number of rows, and the second element indicating the number of
/// columns.
pub type Shape = (usize, usize); // FIXME: maybe we could use Ix2 here?

/// Configuration enum to ask for symmetry checks in algorithms
#[derive(Copy, Clone, Eq, PartialEq, Debug)]
pub enum SymmetryCheck {
    CheckSymmetry,
    DontCheckSymmetry,
}
pub use SymmetryCheck::*;

/// Configuration enum to ask for permutation checks in algorithms
#[derive(Copy, Clone, Eq, PartialEq, Debug)]
pub enum PermutationCheck {
    CheckPerm,
    DontCheckPerm,
}
pub use PermutationCheck::*;

/// The different kinds of fill-in-reduction algorithms supported by sprs
#[derive(Copy, Clone, Eq, PartialEq, Debug)]
#[non_exhaustive]
pub enum FillInReduction {
    NoReduction,
    ReverseCuthillMcKee,
    #[allow(clippy::upper_case_acronyms)]
    CAMDSuiteSparse,
}

#[cfg(feature = "approx")]
/// Traits for comparing vectors and matrices using the approx traits
///
/// Comparisons of sparse matrices with different storages might be slow.
/// It is advised to compare using the same storage order for efficiency
///
/// These traits requires the `approx` feature to be activated
pub mod approx {
    pub use approx::{AbsDiffEq, RelativeEq, UlpsEq};
}

#[cfg(test)]
mod test_data;

#[cfg(test)]
mod test {
    use super::CsMat;

    #[test]
    fn iter_rbr() {
        let mat = CsMat::new(
            (3, 3),
            vec![0, 2, 3, 3],
            vec![1, 2, 0],
            vec![0.1, 0.2, 0.3],
        );
        let view = mat.view();
        let mut iter = view.iter();
        assert_eq!(iter.next(), Some((&0.1, (0, 1))));
        assert_eq!(iter.next(), Some((&0.2, (0, 2))));
        assert_eq!(iter.next(), Some((&0.3, (1, 0))));
        assert_eq!(iter.next(), None);
    }
}
