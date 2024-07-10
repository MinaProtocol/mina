use crate::indexing::SpIndex;
///! Traits to generalize over compressed sparse matrices storages
use crate::sparse::prelude::*;
use std::ops::Deref;

/// The `SpMatView` trait describes data that can be seen as a view
/// into a `CsMat`
pub trait SpMatView<N, I: SpIndex, Iptr: SpIndex = I> {
    /// Return a view into the current matrix
    fn view(&self) -> CsMatViewI<N, I, Iptr>;

    /// Return a view into the current matrix
    fn transpose_view(&self) -> CsMatViewI<N, I, Iptr>;
}

impl<N, I, Iptr, IpStorage, IndStorage, DataStorage> SpMatView<N, I, Iptr>
    for CsMatBase<N, I, IpStorage, IndStorage, DataStorage, Iptr>
where
    I: SpIndex,
    Iptr: SpIndex,
    IpStorage: Deref<Target = [Iptr]>,
    IndStorage: Deref<Target = [I]>,
    DataStorage: Deref<Target = [N]>,
{
    fn view(&self) -> CsMatViewI<N, I, Iptr> {
        self.view()
    }

    fn transpose_view(&self) -> CsMatViewI<N, I, Iptr> {
        self.transpose_view()
    }
}

/// The `SpVecView` trait describes types that can be seen as a view into
/// a `CsVec`
pub trait SpVecView<N, I: SpIndex> {
    /// Return a view into the current vector
    fn view(&self) -> CsVecViewI<N, I>;
}

impl<N, I, IndStorage, DataStorage> SpVecView<N, I>
    for CsVecBase<IndStorage, DataStorage, N, I>
where
    IndStorage: Deref<Target = [I]>,
    DataStorage: Deref<Target = [N]>,
    I: SpIndex,
{
    fn view(&self) -> CsVecViewI<N, I> {
        self.view()
    }
}
