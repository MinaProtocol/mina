use wasm_bindgen::convert::{OptionIntoWasmAbi, IntoWasmAbi, OptionFromWasmAbi, FromWasmAbi};

use std::ops::Deref;
use std::convert::From;

#[derive(Clone)]
pub struct WasmVector<T>(Vec<T>);

impl<T> Deref for WasmVector<T> {
    type Target = Vec<T>;

    fn deref(&self) -> &Self::Target { &self.0 }
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

impl<T> wasm_bindgen::describe::WasmDescribe for WasmVector<T> {
    fn describe() { <Vec<u32> as wasm_bindgen::describe::WasmDescribe>::describe() }
}

impl<T: FromWasmAbi<Abi=u32>> FromWasmAbi for WasmVector<T> {
    type Abi = <Vec<u32> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let pointers: Vec<u32> = FromWasmAbi::from_abi(js);
        WasmVector(pointers.into_iter().map(|x| FromWasmAbi::from_abi(x)).collect())
    }
}

impl<T: FromWasmAbi<Abi=u32>> OptionFromWasmAbi for WasmVector<T> {
    fn is_none(x: &Self::Abi) -> bool {
        <Vec<u32> as OptionFromWasmAbi>::is_none(x)
    }
}

impl<T: IntoWasmAbi<Abi=u32>> IntoWasmAbi for WasmVector<T> {
    type Abi = <Vec<u32> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let pointers: Vec<u32> =
            self.0.into_iter().map(|x| IntoWasmAbi::into_abi(x)).collect();
        IntoWasmAbi::into_abi(pointers)
    }
}

impl<T: IntoWasmAbi<Abi=u32>> OptionIntoWasmAbi for WasmVector<T> {
    fn none() -> Self::Abi {
        <Vec<u32> as OptionIntoWasmAbi>::none()
    }
}
