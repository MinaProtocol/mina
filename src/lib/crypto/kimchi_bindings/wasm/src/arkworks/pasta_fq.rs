extern crate alloc;

use alloc::vec::Vec;
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use mina_curves::pasta::Fq;
use wasm_bindgen::convert::{FromWasmAbi, IntoWasmAbi, OptionFromWasmAbi, OptionIntoWasmAbi};

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct WasmPastaFq(pub Fq);

impl wasm_types::FlatVectorElem for WasmPastaFq {
    const FLATTENED_SIZE: usize = core::mem::size_of::<Fq>();
    fn flatten(self) -> Vec<u8> {
        let mut bytes: Vec<u8> = Vec::with_capacity(Self::FLATTENED_SIZE);
        self.0.serialize_compressed(&mut bytes).unwrap();
        bytes
    }
    fn unflatten(flat: Vec<u8>) -> Self {
        WasmPastaFq(Fq::deserialize_compressed(flat.as_slice()).unwrap())
    }
}

impl From<Fq> for WasmPastaFq {
    fn from(x: Fq) -> Self {
        WasmPastaFq(x)
    }
}

impl From<WasmPastaFq> for Fq {
    fn from(x: WasmPastaFq) -> Self {
        x.0
    }
}

impl<'a> From<&'a WasmPastaFq> for &'a Fq {
    fn from(x: &'a WasmPastaFq) -> Self {
        &x.0
    }
}

impl wasm_bindgen::describe::WasmDescribe for WasmPastaFq {
    fn describe() {
        <Vec<u8> as wasm_bindgen::describe::WasmDescribe>::describe();
    }
}

impl FromWasmAbi for WasmPastaFq {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let bytes: Vec<u8> = FromWasmAbi::from_abi(js);
        WasmPastaFq(Fq::deserialize_compressed(bytes.as_slice()).unwrap())
    }
}

impl IntoWasmAbi for WasmPastaFq {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let mut bytes: Vec<u8> = Vec::with_capacity(core::mem::size_of::<Self>());
        self.0.serialize_compressed(&mut bytes).unwrap();
        bytes.into_abi()
    }
}

impl OptionIntoWasmAbi for WasmPastaFq {
    fn none() -> Self::Abi {
        <Vec<u8> as OptionIntoWasmAbi>::none()
    }
}

impl OptionFromWasmAbi for WasmPastaFq {
    fn is_none(abi: &Self::Abi) -> bool {
        <Vec<u8> as OptionFromWasmAbi>::is_none(abi)
    }
}
