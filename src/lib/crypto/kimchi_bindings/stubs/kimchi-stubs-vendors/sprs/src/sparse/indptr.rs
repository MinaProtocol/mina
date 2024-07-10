//! This module defines the behavior of types suitable to be used
//! as `indptr` storage in a [`CsMatBase`].
//!
//! [`CsMatBase`]: type.CsMatBase.html

#[cfg(feature = "serde")]
use super::serde_traits::IndPtrBaseShadow;
use crate::errors::StructureError;
use crate::indexing::SpIndex;
#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};
use std::ops::Range;
use std::ops::{Deref, DerefMut};

#[derive(Eq, PartialEq, Debug, Copy, Clone, Hash)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
#[cfg_attr(
    feature = "serde",
    serde(try_from = "IndPtrBaseShadow<Iptr, Storage>")
)]
pub struct IndPtrBase<Iptr, Storage>
where
    Iptr: SpIndex,
    Storage: Deref<Target = [Iptr]>,
{
    storage: Storage,
}

pub type IndPtr<Iptr> = IndPtrBase<Iptr, Vec<Iptr>>;
pub type IndPtrView<'a, Iptr> = IndPtrBase<Iptr, &'a [Iptr]>;

impl<Iptr, Storage> IndPtrBase<Iptr, Storage>
where
    Iptr: SpIndex,
    Storage: Deref<Target = [Iptr]>,
{
    pub(crate) fn check_structure(
        storage: &Storage,
    ) -> Result<(), StructureError> {
        for i in storage.iter() {
            if i.try_index().is_none() {
                return Err(StructureError::OutOfRange(
                    "Indptr value out of range of usize",
                ));
            }
        }
        if !storage
            .windows(2)
            .all(|x| x[0].index_unchecked() <= x[1].index_unchecked())
        {
            return Err(StructureError::Unsorted("Unsorted indptr"));
        }
        if storage
            .last()
            .copied()
            .map(Iptr::index_unchecked)
            .map_or(false, |i| i > usize::max_value() / 2)
        {
            // We do not allow indptr values to be larger than half
            // the maximum value of an usize, as that would clearly exhaust
            // all available memory
            // This means we could have an isize, but in practice it's
            // easier to work with usize for indexing.
            return Err(StructureError::OutOfRange(
                "An indptr value is larger than allowed",
            ));
        }
        if storage.len() == 0 {
            // An empty matrix has an inptr of size 1
            return Err(StructureError::SizeMismatch(
                "An indptr should have its len >= 1",
            ));
        }
        Ok(())
    }

    pub fn new_checked(
        storage: Storage,
    ) -> Result<Self, (Storage, StructureError)> {
        match Self::check_structure(&storage) {
            Ok(_) => Ok(Self::new_trusted(storage)),
            Err(e) => Err((storage, e)),
        }
    }

    pub(crate) fn new_trusted(storage: Storage) -> Self {
        Self { storage }
    }

    pub fn view(&self) -> IndPtrView<Iptr> {
        IndPtrView {
            storage: &self.storage[..],
        }
    }

    /// The length of the underlying storage
    pub fn len(&self) -> usize {
        self.storage.len()
    }

    /// Tests whether this indptr is empty
    pub fn is_empty(&self) -> bool {
        // An indptr of len 0 is nonsensical, we should treat that as empty
        // but fail on debug
        debug_assert!(self.storage.len() != 0);
        self.storage.len() <= 1
    }

    /// The number of outer dimensions this indptr represents
    pub fn outer_dims(&self) -> usize {
        if self.storage.len() >= 1 {
            self.storage.len() - 1
        } else {
            0
        }
    }

    /// Indicates whether the underlying storage is proper, which means the
    /// indptr corresponds to a non-sliced matrix.
    ///
    /// An empty matrix is considered non-proper.
    pub fn is_proper(&self) -> bool {
        self.storage.get(0).map_or(false, |i| *i == Iptr::zero())
    }

    /// Return a view on the underlying slice if it is a proper `indptr` slice,
    /// which is the case if its first element is 0. `None` will be returned
    /// otherwise.
    pub fn as_slice(&self) -> Option<&[Iptr]> {
        if self.is_proper() {
            Some(&self.storage[..])
        } else {
            None
        }
    }

    /// Return a view of the underlying storage. Should be used with care in
    /// sparse algorithms, as this won't check if the storage corresponds to a
    /// proper matrix
    pub fn raw_storage(&self) -> &[Iptr] {
        &self.storage[..]
    }

    /// Return a view of the underlying storage. Should only be used with
    /// subsequent structure checks.
    pub(crate) fn raw_storage_mut(&mut self) -> &mut [Iptr]
    where
        Storage: DerefMut<Target = [Iptr]>,
    {
        &mut self.storage[..]
    }

    /// Consume `self` and return the underlying storage
    pub fn into_raw_storage(self) -> Storage {
        self.storage
    }

    pub fn to_owned(&self) -> IndPtr<Iptr> {
        IndPtr {
            storage: self.storage.to_vec(),
        }
    }

    /// Returns a proper indptr representation, cloning if we do not have
    /// a proper indptr.
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
    ///     let indptr = mid.indptr(); // needed for lifetime
    ///     let indptr_proper = indptr.to_proper();
    ///     println!(
    ///         "ptr {:?} is valid as long as _indptr_proper_owned is in scope",
    ///         indptr_proper.as_ptr()
    ///     );
    ///     indptr_proper.as_ptr()
    /// };
    /// // This line is UB.
    /// // println!("ptr deref: {}", *ptr);
    /// ```
    ///
    /// It is much easier to directly use the `proper_indptr` method of
    /// `CsMatBase` directly:
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
    pub fn to_proper(&self) -> std::borrow::Cow<[Iptr]> {
        if self.is_proper() {
            std::borrow::Cow::Borrowed(&self.storage[..])
        } else {
            let offset = self.offset();
            let proper = self.storage.iter().map(|i| *i - offset).collect();
            std::borrow::Cow::Owned(proper)
        }
    }

    fn offset(&self) -> Iptr {
        let zero = Iptr::zero();
        self.storage.get(0).copied().unwrap_or(zero)
    }

    /// Iterate over the nonzeros represented by this indptr, yielding the
    /// outer dimension for each nonzero
    pub fn iter_outer_nnz_inds(
        &self,
    ) -> impl std::iter::DoubleEndedIterator<Item = usize>
           + std::iter::ExactSizeIterator<Item = usize>
           + '_ {
        let mut cur_outer = 0;
        (0..self.nnz()).map(move |i| {
            // loop to find the correct outer dimension. Looping
            // is necessary because there can be several adjacent
            // empty outer dimensions.
            loop {
                let nnz_end = self.outer_inds_sz(cur_outer).end;
                if i == nnz_end {
                    cur_outer += 1;
                } else {
                    break;
                }
            }
            cur_outer
        })
    }

    /// Iterate over outer dimensions, yielding start and end indices for each
    /// outer dimension.
    pub fn iter_outer(
        &self,
    ) -> impl std::iter::DoubleEndedIterator<Item = Range<Iptr>>
           + std::iter::ExactSizeIterator<Item = Range<Iptr>>
           + '_ {
        let offset = self.offset();
        self.storage.windows(2).map(move |x| {
            if offset == Iptr::zero() {
                x[0]..x[1]
            } else {
                (x[0] - offset)..(x[1] - offset)
            }
        })
    }

    /// Iterate over outer dimensions, yielding start and end indices for each
    /// outer dimension.
    ///
    /// Returns a range of usize to ensure iteration of indices and data is easy
    pub fn iter_outer_sz(
        &self,
    ) -> impl std::iter::DoubleEndedIterator<Item = Range<usize>>
           + std::iter::ExactSizeIterator<Item = Range<usize>>
           + '_ {
        self.iter_outer().map(|range| {
            range.start.index_unchecked()..range.end.index_unchecked()
        })
    }

    /// Return the value of the indptr at index i. This method is intended for
    /// low-level usage only, `outer_inds` should be preferred most of the time
    pub fn index(&self, i: usize) -> Iptr {
        let offset = self.offset();
        self.storage[i] - offset
    }

    /// Get the start and end indices for the requested outer dimension
    ///
    /// # Panics
    ///
    /// If `i >= self.outer_dims()`
    pub fn outer_inds(&self, i: usize) -> Range<Iptr> {
        assert!(i + 1 < self.storage.len());
        let offset = self.offset();
        (self.storage[i] - offset)..(self.storage[i + 1] - offset)
    }

    /// Get the start and end indices for the requested outer dimension
    ///
    /// Returns a range of usize to ensure iteration of indices and data is easy
    ///
    /// # Panics
    ///
    /// If `i >= self.outer_dims()`
    pub fn outer_inds_sz(&self, i: usize) -> Range<usize> {
        let range = self.outer_inds(i);
        range.start.index_unchecked()..range.end.index_unchecked()
    }

    /// Get the number of nonzeros in the requested outer dimension
    ///
    /// # Panics
    ///
    /// If `i >= self.outer_dims()`
    pub fn nnz_in_outer(&self, i: usize) -> Iptr {
        assert!(i + 1 < self.storage.len());
        self.storage[i + 1] - self.storage[i]
    }

    /// Get the number of nonzeros in the requested outer dimension
    ///
    /// Returns a usize
    ///
    /// # Panics
    ///
    /// If `i >= self.outer_dims()`
    pub fn nnz_in_outer_sz(&self, i: usize) -> usize {
        self.nnz_in_outer(i).index_unchecked()
    }

    /// Get the start and end indices for the requested outer dimension slice
    ///
    /// # Panics
    ///
    /// If `start >= self.outer_dims() || end > self.outer_dims()`
    pub fn outer_inds_slice(&self, start: usize, end: usize) -> Range<usize> {
        let off = self.offset();
        let range = (self.storage[start] - off)..(self.storage[end] - off);
        range.start.index_unchecked()..range.end.index_unchecked()
    }

    /// The number of nonzero elements described by this indptr
    pub fn nnz(&self) -> usize {
        let offset = self.offset();
        // index_unchecked validity: structure checks ensure that the last index
        // larger than the first, and that both can be represented as an usize
        self.storage
            .last()
            .map(|i| *i - offset)
            .map_or(0, Iptr::index_unchecked)
    }

    /// The number of nonzero elements described by this indptr, using the
    /// actual storage type
    pub fn nnz_i(&self) -> Iptr {
        let offset = self.offset();
        let zero = Iptr::zero();
        // index_unchecked validity: structure checks ensure that the last index
        // larger than the first, and that both can be represented as an usize
        self.storage.last().map_or(zero, |i| *i - offset)
    }

    /// Slice this indptr to include only the outer dimensions in the range
    /// `start..end`.
    pub(crate) fn middle_slice(
        &self,
        range: impl crate::range::Range,
    ) -> IndPtrView<Iptr> {
        self.view().middle_slice_rbr(range)
    }
}

impl<Iptr: SpIndex> IndPtr<Iptr> {
    /// Reserve storage in the underlying vector
    pub(crate) fn reserve(&mut self, cap: usize) {
        self.storage.reserve(cap);
    }

    /// Reserve storage in the underlying vector
    pub(crate) fn reserve_exact(&mut self, cap: usize) {
        self.storage.reserve_exact(cap);
    }

    /// Push to the underlying vector. Assumes the structure will be respected,
    /// no checks are performed (thus the crate-only visibility).
    pub(crate) fn push(&mut self, elem: Iptr) {
        self.storage.push(elem);
    }

    /// Resize the underlying vector. Assumes the structure will be respected,
    /// no checks are performed (thus the crate-only visibility). It's probable
    /// additional modifications need to be performed to guarantee integrity.
    pub(crate) fn resize(&mut self, new_len: usize, value: Iptr) {
        self.storage.resize(new_len, value);
    }

    /// Increment the indptr values to record that an element has been added
    /// to the indices and data, for the outer dimension `outer_dim`.
    pub(crate) fn record_new_element(&mut self, outer_ind: usize) {
        for val in self.storage[outer_ind + 1..].iter_mut() {
            *val += Iptr::one();
        }
    }
}

impl<'a, Iptr: SpIndex> IndPtrView<'a, Iptr> {
    /// Slice this indptr to include only the outer dimensions in the range
    /// `start..end`. Reborrows to get the actual lifetime of the data wrapped
    /// in this view
    pub(crate) fn middle_slice_rbr(
        &self,
        range: impl crate::range::Range,
    ) -> IndPtrView<'a, Iptr> {
        let start = range.start();
        let end = range.end().unwrap_or_else(|| self.outer_dims());
        IndPtrView {
            storage: &self.storage[start..=end],
        }
    }

    /// Reborrow this view to get the lifetime of the underlying slice
    pub(crate) fn reborrow(&self) -> IndPtrView<'a, Iptr> {
        IndPtrView {
            storage: &self.storage[..],
        }
    }
}

/// Allows comparison to vectors and slices
impl<Iptr: SpIndex, IptrStorage, IptrStorage2> std::cmp::PartialEq<IptrStorage2>
    for IndPtrBase<Iptr, IptrStorage>
where
    IptrStorage: Deref<Target = [Iptr]>,
    IptrStorage2: Deref<Target = [Iptr]>,
{
    fn eq(&self, other: &IptrStorage2) -> bool {
        self.raw_storage() == &**other
    }
}

#[cfg(test)]
mod tests {
    use super::{IndPtr, IndPtrView};

    #[test]
    fn constructors() {
        let raw_valid = vec![0, 1, 2, 3];
        assert!(IndPtr::new_checked(raw_valid).is_ok());
        let raw_valid = vec![0, 1, 2, 3];
        assert!(IndPtrView::new_checked(&raw_valid).is_ok());
        // Indptr for an empty matrix
        let raw_valid = vec![0];
        assert!(IndPtrView::new_checked(&raw_valid).is_ok());
        // Indptr for an empty matrix view
        let raw_valid = vec![1];
        assert!(IndPtrView::new_checked(&raw_valid).is_ok());

        let raw_invalid = &[0, 2, 1];
        assert_eq!(
            IndPtrView::new_checked(raw_invalid)
                .map_err(|(_, e)| e.kind())
                .unwrap_err(),
            crate::errors::StructureErrorKind::Unsorted
        );
        let raw_invalid: &[usize] = &[];
        assert!(IndPtrView::new_checked(raw_invalid).is_err());
    }

    #[test]
    fn empty() {
        assert!(IndPtrView::new_checked(&[0]).unwrap().is_empty());
        assert!(!IndPtrView::new_checked(&[0, 1]).unwrap().is_empty());
        #[cfg(debug_assertions)]
        {
            assert!(IndPtrView::new_trusted(&[0]).is_empty());
        }
        #[cfg(not(debug_assertions))]
        {
            assert!(IndPtrView::new_trusted(&[0]).is_empty());
        }
    }

    #[test]
    fn outer_dims() {
        assert_eq!(IndPtrView::new_checked(&[0]).unwrap().outer_dims(), 0);
        assert_eq!(IndPtrView::new_checked(&[0, 1]).unwrap().outer_dims(), 1);
        assert_eq!(
            IndPtrView::new_checked(&[2, 3, 5, 7]).unwrap().outer_dims(),
            3
        );
    }

    #[test]
    fn is_proper() {
        assert!(IndPtrView::new_checked(&[0, 1]).unwrap().is_proper());
        assert!(!IndPtrView::new_checked(&[1, 2]).unwrap().is_proper());
    }

    #[test]
    fn offset() {
        assert_eq!(IndPtrView::new_checked(&[0, 1]).unwrap().offset(), 0);
        assert_eq!(IndPtrView::new_checked(&[1, 2]).unwrap().offset(), 1);
    }

    #[test]
    fn nnz() {
        assert_eq!(IndPtrView::new_checked(&[0, 1]).unwrap().nnz(), 1);
        assert_eq!(IndPtrView::new_checked(&[1, 2]).unwrap().nnz(), 1);
    }

    #[test]
    fn outer_inds() {
        let iptr = IndPtrView::new_checked(&[0, 1, 3, 8]).unwrap();
        assert_eq!(iptr.outer_inds(0), 0..1);
        assert_eq!(iptr.outer_inds(1), 1..3);
        assert_eq!(iptr.outer_inds(2), 3..8);
        let res = std::panic::catch_unwind(|| iptr.outer_inds(3));
        assert!(res.is_err());
    }

    #[test]
    fn nnz_in_outer() {
        let iptr = IndPtrView::new_checked(&[0, 1, 3, 8]).unwrap();
        assert_eq!(iptr.nnz_in_outer(0), 1);
        assert_eq!(iptr.nnz_in_outer(1), 2);
        assert_eq!(iptr.nnz_in_outer(2), 5);
    }

    #[test]
    fn outer_inds_slice() {
        let iptr = IndPtrView::new_checked(&[0, 1, 3, 8]).unwrap();
        assert_eq!(iptr.outer_inds_slice(0, 1), 0..1);
        assert_eq!(iptr.outer_inds_slice(0, 2), 0..3);
        assert_eq!(iptr.outer_inds_slice(1, 3), 1..8);
        let res = std::panic::catch_unwind(|| iptr.outer_inds_slice(3, 4));
        assert!(res.is_err());
    }

    #[test]
    fn iter_outer() {
        let iptr = IndPtrView::new_checked(&[0, 1, 3, 8]).unwrap();
        let mut iter = iptr.iter_outer();
        assert_eq!(iter.next().unwrap(), 0..1);
        assert_eq!(iter.next().unwrap(), 1..3);
        assert_eq!(iter.next().unwrap(), 3..8);
        assert!(iter.next().is_none());
    }

    #[test]
    fn iter_outer_nnz_inds() {
        let iptr = IndPtrView::new_checked(&[0, 1, 3, 8]).unwrap();
        let mut iter = iptr.iter_outer_nnz_inds();
        assert_eq!(iter.next().unwrap(), 0);
        assert_eq!(iter.next().unwrap(), 1);
        assert_eq!(iter.next().unwrap(), 1);
        assert_eq!(iter.next().unwrap(), 2);
        assert_eq!(iter.next().unwrap(), 2);
        assert_eq!(iter.next().unwrap(), 2);
        assert_eq!(iter.next().unwrap(), 2);
        assert_eq!(iter.next().unwrap(), 2);
        assert!(iter.next().is_none());
    }

    #[test]
    fn compare_with_slices() {
        let iptr = IndPtrView::new_checked(&[0, 1, 3, 8]).unwrap();
        assert!(iptr == &[0, 1, 3, 8][..]);
        assert!(iptr == vec![0, 1, 3, 8]);
        let iptr = IndPtrView::new_checked(&[1, 1, 3, 8]).unwrap();
        assert!(iptr == &[1, 1, 3, 8][..]);
    }
}
