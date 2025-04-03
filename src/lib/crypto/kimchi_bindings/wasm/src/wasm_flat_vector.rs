//! The flat vector is a vector of fixed-size elements that we want to expose directly to js-of-ocaml
//! (so that we can access a `Vec<Field>` cheaply,
//! by just passing a pointer to a continuous memory region instead of copying.
//! The wasmvector is a normal heap-allocated vector,
//! where we leave it on the rust heap and just keep a pointer around.
//! We use flat for fields, normal for gates etc.
//!
//! Accessing Rust vector values is not the same as accessing an array.
//! Each indexing (e.g. `some_vec[3]`) is costly as it is implemented as a function call.
//! Knowing that, plus the fact that field elements are implemented as `[u32; 8]`, we know that we incur the cost of following several pointers.
//! To decrease that cost, we flatten such arrays, going from something like
//!
//! ```ignore
//! [[a0, a1, ..., a7], [b0, b1, ..., b7], ...]
//! ```
//!
//! to a flattened vector like:
//!
//! ```ignore
//! [a0, a1, ..., a7, b0, b1, ..., b7, ...]
//! ```

use wasm_bindgen::convert::{FromWasmAbi, IntoWasmAbi, OptionFromWasmAbi, OptionIntoWasmAbi};

use core::convert::From;
use core::ops::Deref;

#[derive(Clone, Debug)]
pub struct WasmFlatVector<T>(Vec<T>);

pub trait FlatVectorElem {
    const FLATTENED_SIZE: usize;

    fn flatten(self) -> Vec<u8>;

    fn unflatten(flat: &[u8]) -> Self;
}

impl<T> Deref for WasmFlatVector<T> {
    type Target = Vec<T>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<T> From<Vec<T>> for WasmFlatVector<T> {
    fn from(x: Vec<T>) -> Self {
        WasmFlatVector(x)
    }
}

impl<T> From<WasmFlatVector<T>> for Vec<T> {
    fn from(x: WasmFlatVector<T>) -> Self {
        x.0
    }
}

impl<'a, T> From<&'a WasmFlatVector<T>> for &'a Vec<T> {
    fn from(x: &'a WasmFlatVector<T>) -> Self {
        &x.0
    }
}

impl<T> core::iter::IntoIterator for WasmFlatVector<T> {
    type Item = <Vec<T> as core::iter::IntoIterator>::Item;
    type IntoIter = <Vec<T> as core::iter::IntoIterator>::IntoIter;
    fn into_iter(self) -> Self::IntoIter {
        self.0.into_iter()
    }
}

impl<'a, T> core::iter::IntoIterator for &'a WasmFlatVector<T> {
    type Item = <&'a Vec<T> as core::iter::IntoIterator>::Item;
    type IntoIter = <&'a Vec<T> as core::iter::IntoIterator>::IntoIter;
    fn into_iter(self) -> Self::IntoIter {
        self.0.iter()
    }
}

impl<T> core::iter::FromIterator<T> for WasmFlatVector<T> {
    fn from_iter<I>(iter: I) -> WasmFlatVector<T>
    where
        I: IntoIterator<Item = T>,
    {
        WasmFlatVector(core::iter::FromIterator::from_iter(iter))
    }
}

impl<T> core::default::Default for WasmFlatVector<T> {
    fn default() -> Self {
        WasmFlatVector(core::default::Default::default())
    }
}

impl<T> core::iter::Extend<T> for WasmFlatVector<T> {
    fn extend<I>(&mut self, iter: I)
    where
        I: IntoIterator<Item = T>,
    {
        self.0.extend(iter)
    }
}

impl<T> wasm_bindgen::describe::WasmDescribe for WasmFlatVector<T> {
    fn describe() {
        <Vec<u8> as wasm_bindgen::describe::WasmDescribe>::describe()
    }
}

impl<T: FlatVectorElem> FromWasmAbi for WasmFlatVector<T> {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;

    unsafe fn from_abi(js: Self::Abi) -> Self {
        let data: Vec<u8> = FromWasmAbi::from_abi(js);

        let res = data
            .chunks(T::FLATTENED_SIZE)
            .inspect(|chunk| assert_eq!(chunk.len(), T::FLATTENED_SIZE))
            .map(T::unflatten)
            .collect();

        WasmFlatVector(res)
    }
}

impl<T: FlatVectorElem> OptionFromWasmAbi for WasmFlatVector<T> {
    fn is_none(x: &Self::Abi) -> bool {
        <Vec<u8> as OptionFromWasmAbi>::is_none(x)
    }
}

impl<T: FlatVectorElem> IntoWasmAbi for WasmFlatVector<T> {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let data: Vec<_> = self.into_iter().flat_map(|x| x.flatten()).collect();
        IntoWasmAbi::into_abi(data)
    }
}

impl<T: FlatVectorElem> OptionIntoWasmAbi for WasmFlatVector<T> {
    fn none() -> Self::Abi {
        <Vec<u8> as OptionIntoWasmAbi>::none()
    }
}
