//! The Marlin_plonk_stubs crate exports some functionalities
//! and structures from the following the Rust crates to OCaml:
//!
//! * [Marlin](https://github.com/o1-labs/marlin),
//!   a PLONK implementation.
//! * [Arkworks](http://arkworks.rs/),
//!   a math library that Marlin builds on top of.
//!

use wasm_bindgen::prelude::*;

mod wasm_vector;

#[wasm_bindgen]
extern "C" {
    pub fn alert(s: &str);
}

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

// produces a warning, but can be useful
// macro_rules! console_log {
//     ($($t:tt)*) => (crate::log(&format_args!($($t)*).to_string()))
// }

#[wasm_bindgen]
pub fn console_log(s: &str) {
    log(s);
}

#[wasm_bindgen]
pub fn create_zero_u32_ptr() -> *mut u32 {
    Box::into_raw(std::boxed::Box::new(0))
}

/// Free a pointer. This method is exported in the WebAssembly module to be used
/// on the JavaScript side, see `web-backend.js`.
///
/// # Safety
///
/// See
/// `<https://rust-lang.github.io/rust-clippy/master/index.html#not_unsafe_ptr_arg_deref>`
#[wasm_bindgen]
pub unsafe fn free_u32_ptr(ptr: *mut u32) {
    let _drop_me = unsafe { std::boxed::Box::from_raw(ptr) };
}

/// Set the value of a pointer. This method is exported in the WebAssembly
/// module to be used on the JavaScript side, see `web-backend.js`.
///
/// # Safety
///
/// See
/// `<https://rust-lang.github.io/rust-clippy/master/index.html#not_unsafe_ptr_arg_deref>`
#[wasm_bindgen]
pub unsafe fn set_u32_ptr(ptr: *mut u32, arg: u32) {
    // The rust docs explicitly forbid using this for cross-thread syncronization. Oh well, we
    // don't have anything better. As long as it works in practice, we haven't upset the undefined
    // behavior dragons.
    unsafe {
        core::ptr::write_volatile(ptr, arg);
    }
}

/// This method is exported in the WebAssembly to be used on the JavaScript
/// side, see `web-backend.js`.
///
/// # Safety
///
/// See
/// `<https://rust-lang.github.io/rust-clippy/master/index.html#not_unsafe_ptr_arg_deref>`
#[allow(unreachable_code)]
#[wasm_bindgen]
pub unsafe fn wait_until_non_zero(ptr: *const u32) -> u32 {
    // The rust docs explicitly forbid using this for cross-thread syncronization. Oh well, we
    // don't have anything better. As long as it works in practice, we haven't upset the undefined
    // behavior dragons.
    loop {
        let contents = unsafe { core::ptr::read_volatile(ptr) };
        if contents != 0 {
            return contents;
        }
    }
    unreachable!();
}

/// This method is exported in the WebAssembly to check the memory used on the
/// JavaScript
#[wasm_bindgen]
pub fn get_memory() -> JsValue {
    wasm_bindgen::memory()
}

/// Returns the number of bytes used by the WebAssembly memory.
#[wasm_bindgen]
pub fn get_memory_byte_length() -> usize {
    let buffer = wasm_bindgen::memory()
        .dyn_into::<js_sys::WebAssembly::Memory>()
        .unwrap()
        .buffer();
    buffer.unchecked_into::<js_sys::ArrayBuffer>().byte_length() as usize
}

pub mod rayon;

/// Vectors
pub mod gate_vector;

pub mod poly_comm;
/// Curves
pub mod projective;

/// SRS
pub mod srs;

/// Indexes
pub mod pasta_fp_plonk_index;
pub mod pasta_fq_plonk_index;

/// Verifier indexes/keys
pub mod plonk_verifier_index;

/// Oracles
pub mod oracles;

/// Proofs
pub mod plonk_proof;

/// Poseidon
pub mod poseidon;

// exposes circuit for inspection
pub mod circuit;

pub mod wasm_ocaml_serde;
