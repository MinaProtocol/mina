/// Regression tests.
///
/// To run, execute `wasm-pack test --release --firefox --headless`
use ark_ff::biginteger::BigInteger256;
use plonk_wasm::arkworks::bigint_256::*;

use wasm_bindgen::convert::{FromWasmAbi, IntoWasmAbi};
use wasm_bindgen_test::wasm_bindgen_test;

wasm_bindgen_test::wasm_bindgen_test_configure!(run_in_browser);

#[wasm_bindgen_test]
pub fn bigint_abi_regression() {
    let bigint: BigInteger256 = BigInteger256::from((1u64 << 60) + 5u64);
    let integer = WasmBigInteger256(bigint.clone());
    let abi = integer.into_abi();
    let integer2 = unsafe { WasmBigInteger256::from_abi(abi) };
    //println!("{abi}");
    assert!(bigint == integer2.0);
}
