use wasm_bindgen::convert::{FromWasmAbi, IntoWasmAbi, OptionFromWasmAbi, OptionIntoWasmAbi};

use std::convert::From;
use std::ops::Deref;

#[derive(Clone, Debug)]
pub struct WasmVector<T>(Vec<T>);

impl<T> Deref for WasmVector<T> {
    type Target = Vec<T>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<T> From<Vec<T>> for WasmVector<T> {
    fn from(x: Vec<T>) -> Self {
        WasmVector(x)
    }
}

impl<T> From<WasmVector<T>> for Vec<T> {
    fn from(x: WasmVector<T>) -> Self {
        x.0
    }
}

impl<'a, T> From<&'a WasmVector<T>> for &'a Vec<T> {
    fn from(x: &'a WasmVector<T>) -> Self {
        &x.0
    }
}

impl<T> std::iter::IntoIterator for WasmVector<T> {
    type Item = <Vec<T> as std::iter::IntoIterator>::Item;
    type IntoIter = <Vec<T> as std::iter::IntoIterator>::IntoIter;
    fn into_iter(self) -> Self::IntoIter {
        self.0.into_iter()
    }
}

impl<'a, T> std::iter::IntoIterator for &'a WasmVector<T> {
    type Item = <&'a Vec<T> as std::iter::IntoIterator>::Item;
    type IntoIter = <&'a Vec<T> as std::iter::IntoIterator>::IntoIter;
    fn into_iter(self) -> Self::IntoIter {
        (&self.0).into_iter()
    }
}

impl<T> std::iter::FromIterator<T> for WasmVector<T> {
    fn from_iter<I>(iter: I) -> WasmVector<T>
    where
        I: IntoIterator<Item = T>,
    {
        WasmVector(std::iter::FromIterator::from_iter(iter))
    }
}

impl<T> std::default::Default for WasmVector<T> {
    fn default() -> Self {
        WasmVector(std::default::Default::default())
    }
}

impl<T> std::iter::Extend<T> for WasmVector<T> {
    fn extend<I>(&mut self, iter: I)
    where
        I: IntoIterator<Item = T>,
    {
        self.0.extend(iter)
    }
}

impl<T> wasm_bindgen::describe::WasmDescribe for WasmVector<T> {
    fn describe() {
        <Vec<u32> as wasm_bindgen::describe::WasmDescribe>::describe()
    }
}

impl<T: FromWasmAbi<Abi = u32>> FromWasmAbi for WasmVector<T> {
    type Abi = <Vec<u32> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let pointers: Vec<u32> = FromWasmAbi::from_abi(js);
        WasmVector(
            pointers
                .into_iter()
                .map(|x| FromWasmAbi::from_abi(x))
                .collect(),
        )
    }
}

impl<T: FromWasmAbi<Abi = u32>> OptionFromWasmAbi for WasmVector<T> {
    fn is_none(x: &Self::Abi) -> bool {
        <Vec<u32> as OptionFromWasmAbi>::is_none(x)
    }
}

impl<T: IntoWasmAbi<Abi = u32>> IntoWasmAbi for WasmVector<T> {
    type Abi = <Vec<u32> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let pointers: Vec<u32> = self
            .0
            .into_iter()
            .map(|x| IntoWasmAbi::into_abi(x))
            .collect();
        IntoWasmAbi::into_abi(pointers)
    }
}

impl<T: IntoWasmAbi<Abi = u32>> OptionIntoWasmAbi for WasmVector<T> {
    fn none() -> Self::Abi {
        <Vec<u32> as OptionIntoWasmAbi>::none()
    }
}
