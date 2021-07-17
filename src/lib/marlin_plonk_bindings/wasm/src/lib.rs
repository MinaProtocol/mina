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
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

#[wasm_bindgen]
pub fn console_log(s: &str) {
    log(s);
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
pub mod urs_utils;
