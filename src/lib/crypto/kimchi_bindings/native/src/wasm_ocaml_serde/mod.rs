//! This module constructs a serde serializer (and deserializer) to convert Rust structures to (and from) Js types expected by js-of-ocaml.
//! js-of-ocaml expects arrays of values instead of objects, so a Rust structure like:
//!
//! ```ignore
//! { a: F, b: Vec<F>, c: SomeType }
//! ```
//!
//! must be converted to an array that looks like this:
//!
//! ```ignore
//! // notice the leading 0, which is an artifact of OCaml's memory layout and how js-of-ocaml is implemented.
//! [0, a, b, c]
//! ```
//! See the following example on how to use it:
//!
//! ```
//! #[derive(serde::Serialize, serde::Deserialize)]
//! struct Thing { a: usize, b: u32 }
//!
//! let serializer = crate::wasm_ocaml_serde::ser::Serializer::new();
//! let thing = Thing { a: 5, b: 6 };
//! let js_value = serde::Serialize::serialize(thing, &mut serializer).unwrap();
//! assert_eq!(format!("{}", js_value), "[0, 5, 6]");
//! ```

use wasm_bindgen::prelude::*;

pub mod de;
pub mod ser;

pub use serde_wasm_bindgen::Error;

pub type Result<T = JsValue> = core::result::Result<T, Error>;
