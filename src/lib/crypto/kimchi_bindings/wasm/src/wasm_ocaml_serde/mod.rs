use wasm_bindgen::prelude::*;

pub mod de;
pub mod ser;

pub use serde_wasm_bindgen::Error;

pub type Result<T = JsValue> = core::result::Result<T, Error>;
