use crate::arkworks::bigint_256::{self, WasmBigInteger256};
use ark_ff::{
    fields::{Field, FpParameters, PrimeField, SquareRootField},
    FftField, One, UniformRand, Zero,
};
use ark_ff::{FromBytes, ToBytes};
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain as Domain};
use mina_curves::pasta::{fields::fp::FpParameters as Fp_params, Fp};
use num_bigint::BigUint;
use rand::rngs::StdRng;
use std::cmp::Ordering::{Equal, Greater, Less};
use wasm_bindgen::convert::{FromWasmAbi, IntoWasmAbi, OptionFromWasmAbi, OptionIntoWasmAbi};
use wasm_bindgen::prelude::*;

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct WasmPastaFp(pub Fp);

impl crate::wasm_flat_vector::FlatVectorElem for WasmPastaFp {
    const FLATTENED_SIZE: usize = std::mem::size_of::<Fp>();
    fn flatten(self) -> Vec<u8> {
        let mut bytes: Vec<u8> = Vec::with_capacity(Self::FLATTENED_SIZE);
        self.0.write(&mut bytes).unwrap();
        bytes
    }
    fn unflatten(flat: Vec<u8>) -> Self {
        WasmPastaFp(FromBytes::read(flat.as_slice()).unwrap())
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
        <Vec<u8> as wasm_bindgen::describe::WasmDescribe>::describe()
    }
}

impl FromWasmAbi for WasmPastaFp {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    unsafe fn from_abi(js: Self::Abi) -> Self {
        let bytes: Vec<u8> = FromWasmAbi::from_abi(js);
        WasmPastaFp(FromBytes::read(bytes.as_slice()).unwrap())
    }
}

impl IntoWasmAbi for WasmPastaFp {
    type Abi = <Vec<u8> as FromWasmAbi>::Abi;
    fn into_abi(self) -> Self::Abi {
        let mut bytes: Vec<u8> = vec![];
        self.0.write(&mut bytes).unwrap();
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

#[wasm_bindgen]
pub fn caml_pasta_fp_size_in_bits() -> isize {
    Fp_params::MODULUS_BITS as isize
}

#[wasm_bindgen]
pub fn caml_pasta_fp_size() -> WasmBigInteger256 {
    WasmBigInteger256(Fp_params::MODULUS)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_add(x: WasmPastaFp, y: WasmPastaFp) -> WasmPastaFp {
    WasmPastaFp(x.0 + y.0)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_sub(x: WasmPastaFp, y: WasmPastaFp) -> WasmPastaFp {
    WasmPastaFp(x.0 - y.0)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_negate(x: WasmPastaFp) -> WasmPastaFp {
    WasmPastaFp(-x.0)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_mul(x: WasmPastaFp, y: WasmPastaFp) -> WasmPastaFp {
    WasmPastaFp(x.0 * y.0)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_div(x: WasmPastaFp, y: WasmPastaFp) -> WasmPastaFp {
    WasmPastaFp(x.0 / y.0)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_inv(x: WasmPastaFp) -> Option<WasmPastaFp> {
    x.0.inverse().map(WasmPastaFp)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_square(x: WasmPastaFp) -> WasmPastaFp {
    WasmPastaFp(x.0.square())
}

#[wasm_bindgen]
pub fn caml_pasta_fp_is_square(x: WasmPastaFp) -> bool {
    let s = x.0.pow(Fp_params::MODULUS_MINUS_ONE_DIV_TWO);
    s.is_zero() || s.is_one()
}

#[wasm_bindgen]
pub fn caml_pasta_fp_sqrt(x: WasmPastaFp) -> Option<WasmPastaFp> {
    x.0.sqrt().map(WasmPastaFp)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_of_int(i: i32) -> WasmPastaFp {
    WasmPastaFp(Fp::from(i as u64))
}

#[wasm_bindgen]
pub fn caml_pasta_fp_to_string(x: WasmPastaFp) -> String {
    bigint_256::to_biguint(&x.0.into_repr()).to_string()
}

#[wasm_bindgen]
pub fn caml_pasta_fp_of_string(s: String) -> Result<WasmPastaFp, JsValue> {
    let biguint = BigUint::parse_bytes(s.as_bytes(), 10)
        .ok_or(JsValue::from_str("caml_pasta_fp_of_string"))?;

    match Fp::from_repr(bigint_256::of_biguint(&biguint)) {
        Some(x) => Ok(x.into()),
        None => Err(JsValue::from_str("caml_pasta_fp_of_string")),
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_print(x: WasmPastaFp) {
    println!("{}", bigint_256::to_biguint(&(x.0.into_repr())));
}

#[wasm_bindgen]
pub fn caml_pasta_fp_compare(x: WasmPastaFp, y: WasmPastaFp) -> i32 {
    match x.0.cmp(&y.0) {
        Less => -1,
        Equal => 0,
        Greater => 1,
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_equal(x: WasmPastaFp, y: WasmPastaFp) -> bool {
    x.0 == y.0
}

#[wasm_bindgen]
pub fn caml_pasta_fp_random() -> WasmPastaFp {
    WasmPastaFp(UniformRand::rand(&mut rand::thread_rng()))
}

#[wasm_bindgen]
pub fn caml_pasta_fp_rng(i: i32) -> WasmPastaFp {
    // We only care about entropy here, so we force a conversion i32 -> u32.
    let i: u64 = (i as u32).into();
    let mut rng: StdRng = rand::SeedableRng::seed_from_u64(i);
    WasmPastaFp(UniformRand::rand(&mut rng))
}

#[wasm_bindgen]
pub fn caml_pasta_fp_to_bigint(x: WasmPastaFp) -> WasmBigInteger256 {
    WasmBigInteger256(x.0.into_repr())
}

#[wasm_bindgen]
pub fn caml_pasta_fp_of_bigint(x: WasmBigInteger256) -> Result<WasmPastaFp, JsValue> {
    match Fp::from_repr(x.0) {
        Some(x) => Ok(x.into()),
        None => Err(JsValue::from_str("caml_pasta_fp_of_bigint")),
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_two_adic_root_of_unity() -> WasmPastaFp {
    WasmPastaFp(FftField::two_adic_root_of_unity())
}

#[wasm_bindgen]
pub fn caml_pasta_fp_domain_generator(log2_size: i32) -> WasmPastaFp {
    match Domain::new(1 << log2_size) {
        Some(x) => WasmPastaFp(x.group_gen),
        None => panic!("caml_pasta_fp_domain_generator"),
    }
}

#[wasm_bindgen]
pub fn caml_pasta_fp_to_bytes(x: WasmPastaFp) -> Vec<u8> {
    let len = std::mem::size_of::<Fp>();
    let mut str: Vec<u8> = Vec::with_capacity(len);
    str.resize(len, 0);
    let str_as_fp: *mut Fp = str.as_mut_ptr().cast::<Fp>();
    unsafe {
        *str_as_fp = x.0;
    }
    str
}

#[wasm_bindgen]
pub fn caml_pasta_fp_of_bytes(x: &[u8]) -> WasmPastaFp {
    let len = std::mem::size_of::<Fp>();
    if x.len() != len {
        panic!("caml_pasta_fp_of_bytes");
    };
    let x = unsafe { *(x.as_ptr() as *const Fp) };
    WasmPastaFp(x)
}

#[wasm_bindgen]
pub fn caml_pasta_fp_deep_copy(x: WasmPastaFp) -> WasmPastaFp {
    x
}
