use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern {
    pub fn alert(s: &str);
}

#[wasm_bindgen]
pub fn greet(name: &str) {
    alert(&format!("Hello, {}!", name));
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (crate::log(&format_args!($($t)*).to_string()))
}

#[wasm_bindgen]
pub fn console_log(s: &str) {
    log(s);
}

#[wasm_bindgen]
pub fn create_zero_u32_ptr() -> *mut u32 {
    Box::into_raw(std::boxed::Box::new(0))
}

#[wasm_bindgen]
pub fn free_u32_ptr(ptr: *mut u32) {
    let _drop_me = unsafe { std::boxed::Box::from_raw(ptr) };
}

#[wasm_bindgen]
pub fn set_u32_ptr(ptr: *mut u32, arg: u32) {
    // The rust docs explicitly forbid using this for cross-thread syncronization. Oh well, we
    // don't have anything better. As long as it works in practice, we haven't upset the undefined
    // behavior dragons.
    unsafe { std::ptr::write_volatile(ptr, arg); }
}

#[wasm_bindgen]
pub fn wait_until_non_zero(ptr: *const u32) -> u32 {
    // The rust docs explicitly forbid using this for cross-thread syncronization. Oh well, we
    // don't have anything better. As long as it works in practice, we haven't upset the undefined
    // behavior dragons.
    while true {
        let contents = unsafe { std::ptr::read_volatile(ptr) };
        if contents != 0 { return contents; }
    }
    unreachable!();
}

pub use wasm_bindgen_rayon::init_thread_pool;

pub mod bigint_256;
pub mod index_serialization;
pub mod pasta_fp;
pub mod pasta_fq;
pub mod pasta_pallas;
pub mod pasta_vesta;
pub mod wasm_vector;
pub mod wasm_flat_vector;
pub mod pasta_vesta_poly_comm;
pub mod pasta_pallas_poly_comm;
pub mod pasta_fp_urs;
pub mod pasta_fq_urs;
pub mod plonk_gate;
pub mod pasta_fp_plonk_index;
pub mod pasta_fq_plonk_index;
pub mod pasta_fp_plonk_oracles;
pub mod pasta_fq_plonk_oracles;
pub mod pasta_fp_plonk_proof;
pub mod pasta_fq_plonk_proof;
pub mod pasta_fp_plonk_verifier_index;
pub mod pasta_fq_plonk_verifier_index;
pub mod urs_utils;
