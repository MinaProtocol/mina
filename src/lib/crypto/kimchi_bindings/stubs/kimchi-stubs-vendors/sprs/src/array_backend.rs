//! Fixed size arrays usable for sparse matrices.
//!
//! Mainly useful to create a sparse matrix view over a sparse vector
//! without allocation.

use std::ops::{Deref, DerefMut};

/// Wrapper around a size 2 array, with `Deref` implementation.
#[derive(Debug, Copy, Clone)]
pub struct Array2<T> {
    pub data: [T; 2],
}

impl<T> Deref for Array2<T> {
    type Target = [T];

    fn deref(&self) -> &[T] {
        &self.data[..]
    }
}

impl<T> DerefMut for Array2<T> {
    fn deref_mut(&mut self) -> &mut [T] {
        &mut self.data[..]
    }
}
