use crate::Ix1;
use ndarray::{self, ArrayBase};
use num_traits::identities::Zero;

/// A trait for types representing dense vectors, useful for expressing
/// algorithms such as sparse-dense dot product, or linear solves.
///
/// This trait is sealed, and cannot be implemented outside of the `sprs`
/// crate.
pub trait DenseVector: seal::Sealed {
    type Owned;
    type Scalar;

    /// The dimension of the vector
    fn dim(&self) -> usize;

    /// Random access to an element in the vector.
    ///
    /// # Panics
    ///
    /// If the index is out of bounds
    fn index(&self, idx: usize) -> &Self::Scalar;

    /// Create an owned version of this dense vector type, filled with zeros
    fn zeros(dim: usize) -> Self::Owned;

    /// Copies this vector into an owned version
    fn to_owned(&self) -> Self::Owned;
}

impl<N: Zero + Clone> DenseVector for [N] {
    type Owned = Vec<N>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.len()
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[idx]
    }

    fn zeros(dim: usize) -> Self::Owned {
        vec![N::zero(); dim]
    }

    fn to_owned(&self) -> Self::Owned {
        self.to_vec()
    }
}

impl<'a, N: 'a + Zero + Clone> DenseVector for &'a [N] {
    type Owned = Vec<N>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.len()
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[idx]
    }

    fn zeros(dim: usize) -> Self::Owned {
        vec![N::zero(); dim]
    }

    fn to_owned(&self) -> Self::Owned {
        self.to_vec()
    }
}

impl<'a, N: 'a + Zero + Clone> DenseVector for &'a mut [N] {
    type Owned = Vec<N>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.len()
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[idx]
    }

    fn zeros(dim: usize) -> Self::Owned {
        vec![N::zero(); dim]
    }

    fn to_owned(&self) -> Self::Owned {
        self.to_vec()
    }
}

impl<N: Zero + Clone> DenseVector for Vec<N> {
    type Owned = Self;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.len()
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[idx]
    }

    fn zeros(dim: usize) -> Self::Owned {
        vec![N::zero(); dim]
    }

    fn to_owned(&self) -> Self::Owned {
        self.clone()
    }
}

impl<'a, N: 'a + Zero + Clone> DenseVector for &'a Vec<N> {
    type Owned = Vec<N>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.len()
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[idx]
    }

    fn zeros(dim: usize) -> Self::Owned {
        vec![N::zero(); dim]
    }

    fn to_owned(&self) -> Self::Owned {
        (*self).clone()
    }
}

impl<'a, N: 'a + Zero + Clone> DenseVector for &'a mut Vec<N> {
    type Owned = Vec<N>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.len()
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[idx]
    }

    fn zeros(dim: usize) -> Self::Owned {
        vec![N::zero(); dim]
    }

    fn to_owned(&self) -> Self::Owned {
        (**self).clone()
    }
}

impl<N, S> DenseVector for ArrayBase<S, Ix1>
where
    S: ndarray::Data<Elem = N>,
    N: Zero + Clone,
{
    type Owned = ndarray::Array<N, Ix1>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.shape()[0]
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[[idx]]
    }

    fn zeros(dim: usize) -> Self::Owned {
        ndarray::Array::zeros(dim)
    }

    fn to_owned(&self) -> Self::Owned {
        self.to_owned()
    }
}

impl<'a, N, S> DenseVector for &'a ArrayBase<S, Ix1>
where
    S: ndarray::Data<Elem = N>,
    N: 'a + Zero + Clone,
{
    type Owned = ndarray::Array<N, Ix1>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.shape()[0]
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[[idx]]
    }

    fn zeros(dim: usize) -> Self::Owned {
        ndarray::Array::zeros(dim)
    }

    fn to_owned(&self) -> Self::Owned {
        ArrayBase::to_owned(self)
    }
}

impl<'a, N, S> DenseVector for &'a mut ArrayBase<S, Ix1>
where
    S: ndarray::Data<Elem = N>,
    N: 'a + Zero + Clone,
{
    type Owned = ndarray::Array<N, Ix1>;
    type Scalar = N;

    fn dim(&self) -> usize {
        self.shape()[0]
    }

    #[inline(always)]
    fn index(&self, idx: usize) -> &N {
        &self[[idx]]
    }

    fn zeros(dim: usize) -> Self::Owned {
        ndarray::Array::zeros(dim)
    }

    fn to_owned(&self) -> Self::Owned {
        ArrayBase::to_owned(self)
    }
}

/// Trait for dense vectors that can be modified, useful for expressing
/// algorithms which compute a resulting dense vector, such as solvers.
///
/// This trait is sealed, and cannot be implemented outside of the `sprs`
/// crate.
pub trait DenseVectorMut: DenseVector {
    /// Random mutable access to an element in the vector.
    ///
    /// # Panics
    ///
    /// If the index is out of bounds
    fn index_mut(&mut self, idx: usize) -> &mut Self::Scalar;
}

impl<'a, N: 'a + Zero + Clone> DenseVectorMut for [N] {
    #[inline(always)]
    fn index_mut(&mut self, idx: usize) -> &mut N {
        &mut self[idx]
    }
}

impl<'a, N: 'a + Zero + Clone> DenseVectorMut for &'a mut [N] {
    #[inline(always)]
    fn index_mut(&mut self, idx: usize) -> &mut N {
        &mut self[idx]
    }
}

impl<N: Zero + Clone> DenseVectorMut for Vec<N> {
    #[inline(always)]
    fn index_mut(&mut self, idx: usize) -> &mut N {
        &mut self[idx]
    }
}

impl<'a, N: 'a + Zero + Clone> DenseVectorMut for &'a mut Vec<N> {
    #[inline(always)]
    fn index_mut(&mut self, idx: usize) -> &mut N {
        &mut self[idx]
    }
}

impl<N, S> DenseVectorMut for ArrayBase<S, Ix1>
where
    S: ndarray::DataMut<Elem = N>,
    N: Zero + Clone,
{
    #[inline(always)]
    fn index_mut(&mut self, idx: usize) -> &mut N {
        &mut self[[idx]]
    }
}

impl<'a, N, S> DenseVectorMut for &'a mut ArrayBase<S, Ix1>
where
    S: ndarray::DataMut<Elem = N>,
    N: 'a + Zero + Clone,
{
    #[inline(always)]
    fn index_mut(&mut self, idx: usize) -> &mut N {
        &mut self[[idx]]
    }
}

mod seal {
    pub trait Sealed {}

    impl<N> Sealed for [N] {}
    impl<'a, N: 'a> Sealed for &'a [N] {}
    impl<'a, N: 'a> Sealed for &'a mut [N] {}
    impl<N> Sealed for Vec<N> {}
    impl<'a, N: 'a> Sealed for &'a Vec<N> {}
    impl<'a, N: 'a> Sealed for &'a mut Vec<N> {}
    impl<N, S: ndarray::Data<Elem = N>> Sealed
        for ndarray::ArrayBase<S, crate::Ix1>
    {
    }
    impl<'a, N: 'a, S: ndarray::Data<Elem = N>> Sealed
        for &'a ndarray::ArrayBase<S, crate::Ix1>
    {
    }
    impl<'a, N: 'a, S: ndarray::Data<Elem = N>> Sealed
        for &'a mut ndarray::ArrayBase<S, crate::Ix1>
    {
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use ndarray::{arr1, Array1};

    // Tests on primitive arrays
    #[test]
    fn test_dim_of_empty_array() {
        let vec: [i32; 0] = [];
        assert_eq!(vec.dim(), 0);
    }

    #[test]
    fn test_dim_of_non_empty_array() {
        let vec = [10, 20];
        assert_eq!(vec.dim(), 2);
    }

    #[test]
    fn test_indexing_array() {
        let vec: [i32; 3] = [10, 20, 30];
        assert_eq!(*(vec.index(0)), 10);
        assert_eq!(*(vec.index(1)), 20);
        assert_eq!(*(vec.index(2)), 30);
    }

    #[test]
    fn test_zeros_on_array() {
        const DIM: usize = 5;
        let vec = <[i32] as DenseVector>::zeros(DIM);
        for i in 0..DIM {
            assert_eq!(vec[i], 0);
        }
    }

    // Tests on vectors
    #[test]
    fn test_dim_of_empty_vector() {
        let vec: Vec<i32> = vec![];
        assert_eq!(vec.dim(), 0);
    }

    #[test]
    fn test_dim_of_non_empty_vector() {
        let vec = vec![10, 20];
        assert_eq!(vec.dim(), 2);
    }

    #[test]
    fn test_dim_of_varying_size_vector() {
        let mut vec: Vec<i32> = vec![];
        assert_eq!(vec.dim(), 0);
        vec.push(10);
        assert_eq!(vec.dim(), 1);
        vec.push(20);
        assert_eq!(vec.dim(), 2);
        vec.clear();
        assert_eq!(vec.dim(), 0);
    }

    #[test]
    fn test_indexing_vector() {
        let vec = vec![10, 20, 30];
        assert_eq!(*(vec.index(0)), 10);
        assert_eq!(*(vec.index(1)), 20);
        assert_eq!(*(vec.index(2)), 30);
    }

    #[test]
    fn test_zeros_on_vector() {
        const DIM: usize = 5;
        let vec = Vec::<i32>::zeros(DIM);
        for i in 0..DIM {
            assert_eq!(vec[i], 0);
        }
    }

    // Tests on ArrayBase
    #[test]
    fn test_dim_of_empty_ndarray() {
        let array = Array1::<i32>::zeros(0);
        assert_eq!(array.dim(), 0);
    }

    #[test]
    fn test_dim_of_non_empty_ndarray() {
        let array = Array1::<i32>::zeros(3);
        assert_eq!(array.dim(), 3);
    }

    #[test]
    fn test_indexing_ndarray() {
        let array = arr1(&[10, 20, 30]);
        assert_eq!(*(array.index(0)), 10);
        assert_eq!(*(array.index(1)), 20);
        assert_eq!(*(array.index(2)), 30);
    }

    #[test]
    fn test_zeros_on_ndarray() {
        const DIM: usize = 5;
        let array = <Array1<i32> as DenseVector>::zeros(DIM);
        for i in 0..DIM {
            assert_eq!(array[i], 0);
        }
    }
}
