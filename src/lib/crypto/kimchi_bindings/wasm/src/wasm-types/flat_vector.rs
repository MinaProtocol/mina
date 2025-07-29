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

extern crate alloc;

use wasm_bindgen::convert::{FromWasmAbi, IntoWasmAbi, OptionFromWasmAbi, OptionIntoWasmAbi};

use alloc::vec::Vec;
use core::{convert::From, ops::Deref};

#[derive(Clone, Debug)]
pub struct FlatVector<T>(Vec<T>);

impl<T: FlatVectorElem> FlatVector<T> {
    #[must_use]
    pub fn from_bytes(data: Vec<u8>) -> Self {
        let mut res: Vec<T> = Vec::with_capacity(data.len() / T::FLATTENED_SIZE);

        let mut buf = Vec::with_capacity(T::FLATTENED_SIZE);

        for x in data {
            assert!(buf.len() < T::FLATTENED_SIZE);

            buf.push(x);

            if buf.len() >= T::FLATTENED_SIZE {
                res.push(T::unflatten(buf));
                buf = Vec::with_capacity(T::FLATTENED_SIZE);
            }
        }

        assert_eq!(buf.len(), 0);

        FlatVector(res)
    }
}

pub trait FlatVectorElem {
    const FLATTENED_SIZE: usize;
    fn flatten(self) -> Vec<u8>;
    fn unflatten(flat: Vec<u8>) -> Self;
}

impl<T> Deref for FlatVector<T> {
    type Target = Vec<T>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<T> From<Vec<T>> for FlatVector<T> {
    fn from(x: Vec<T>) -> Self {
        FlatVector(x)
    }
}

impl<T> From<FlatVector<T>> for Vec<T> {
    fn from(x: FlatVector<T>) -> Self {
        x.0
    }
}

impl<'a, T> From<&'a FlatVector<T>> for &'a Vec<T> {
    fn from(x: &'a FlatVector<T>) -> Self {
        &x.0
    }
}

impl<T> core::iter::IntoIterator for FlatVector<T> {
    type Item = <Vec<T> as core::iter::IntoIterator>::Item;
    type IntoIter = <Vec<T> as core::iter::IntoIterator>::IntoIter;
    fn into_iter(self) -> Self::IntoIter {
        self.0.into_iter()
    }
}

impl<'a, T> core::iter::IntoIterator for &'a FlatVector<T> {
    type Item = <&'a Vec<T> as core::iter::IntoIterator>::Item;
    type IntoIter = <&'a Vec<T> as core::iter::IntoIterator>::IntoIter;
    fn into_iter(self) -> Self::IntoIter {
        self.0.iter()
    }
}

impl<T> core::iter::FromIterator<T> for FlatVector<T> {
    fn from_iter<I>(iter: I) -> FlatVector<T>
    where
        I: IntoIterator<Item = T>,
    {
        FlatVector(core::iter::FromIterator::from_iter(iter))
    }
}

impl<T> core::default::Default for FlatVector<T> {
    fn default() -> Self {
        FlatVector(core::default::Default::default())
    }
}

impl<T> core::iter::Extend<T> for FlatVector<T> {
    fn extend<I>(&mut self, iter: I)
    where
        I: IntoIterator<Item = T>,
    {
        self.0.extend(iter);
    }
}

impl<T> wasm_bindgen::describe::WasmDescribe for FlatVector<T> {
    fn describe() {
        <Vec<u8> as wasm_bindgen::describe::WasmDescribe>::describe();
    }
}

impl<T: FlatVectorElem> FromWasmAbi for FlatVector<T> {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let data: Vec<u8> = FromWasmAbi::from_abi(js);
        let mut res: Vec<T> = Vec::with_capacity(data.len() / T::FLATTENED_SIZE);

        let mut buf = Vec::with_capacity(T::FLATTENED_SIZE);
        for x in data {
            assert!(buf.len() < T::FLATTENED_SIZE);
            buf.push(x);
            if buf.len() >= T::FLATTENED_SIZE {
                res.push(T::unflatten(buf));
                buf = Vec::with_capacity(T::FLATTENED_SIZE);
            }
        }
        assert_eq!(buf.len(), 0);
        FlatVector(res)
    }
}

impl<T: FlatVectorElem> OptionFromWasmAbi for FlatVector<T> {
    fn is_none(x: &Self::Abi) -> bool {
        <Vec<u8> as OptionFromWasmAbi>::is_none(x)
    }
}

impl<T: FlatVectorElem> IntoWasmAbi for FlatVector<T> {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let mut data: Vec<u8> = Vec::with_capacity(self.0.len() * T::FLATTENED_SIZE);
        for x in self.0 {
            data.extend(x.flatten().into_iter());
        }
        IntoWasmAbi::into_abi(data)
    }
}

impl<T: FlatVectorElem> OptionIntoWasmAbi for FlatVector<T> {
    fn none() -> Self::Abi {
        <Vec<u8> as OptionIntoWasmAbi>::none()
    }
}
