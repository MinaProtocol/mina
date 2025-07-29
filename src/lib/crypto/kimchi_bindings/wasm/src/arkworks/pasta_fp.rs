extern crate alloc;

use alloc::vec::Vec;
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use mina_curves::pasta::Fp;
use wasm_bindgen::convert::{FromWasmAbi, IntoWasmAbi, OptionFromWasmAbi, OptionIntoWasmAbi};

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct WasmPastaFp(pub Fp);

impl wasm_types::FlatVectorElem for WasmPastaFp {
    const FLATTENED_SIZE: usize = core::mem::size_of::<Fp>();

    fn flatten(self) -> Vec<u8> {
        let mut bytes: Vec<u8> = Vec::with_capacity(Self::FLATTENED_SIZE);
        self.0.serialize_compressed(&mut bytes).unwrap();
        bytes
    }

    fn unflatten(flat: Vec<u8>) -> Self {
        WasmPastaFp(Fp::deserialize_compressed(flat.as_slice()).unwrap())
    }
}

impl From<Fp> for WasmPastaFp {
    fn from(x: Fp) -> Self {
        WasmPastaFp(x)
    }
}

impl From<WasmPastaFp> for Fp {
    fn from(x: WasmPastaFp) -> Self {
        x.0
    }
}

impl<'a> From<&'a WasmPastaFp> for &'a Fp {
    fn from(x: &'a WasmPastaFp) -> Self {
        &x.0
    }
}

impl wasm_bindgen::describe::WasmDescribe for WasmPastaFp {
    fn describe() {
        <Vec<u8> as wasm_bindgen::describe::WasmDescribe>::describe();
    }
}

impl FromWasmAbi for WasmPastaFp {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let bytes: Vec<u8> = FromWasmAbi::from_abi(js);
        WasmPastaFp(Fp::deserialize_compressed(bytes.as_slice()).unwrap())
    }
}

impl IntoWasmAbi for WasmPastaFp {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;

    fn into_abi(self) -> Self::Abi {
        let mut bytes: Vec<u8> = Vec::with_capacity(core::mem::size_of::<Self>());
        self.0.serialize_compressed(&mut bytes).unwrap();
        bytes.into_abi()
    }
}

impl OptionIntoWasmAbi for WasmPastaFp {
    fn none() -> Self::Abi {
        <Vec<u8> as OptionIntoWasmAbi>::none()
    }
}

impl OptionFromWasmAbi for WasmPastaFp {
    fn is_none(abi: &Self::Abi) -> bool {
        <Vec<u8> as OptionFromWasmAbi>::is_none(abi)
    }
}
