#![deny(missing_docs)]
#![cfg_attr(feature = "no-std", no_std)]
#![allow(clippy::missing_safety_doc)]

//! [ocaml-rs](https://github.com/zshipko/ocaml-rs/) is a library for directly interacting with the C OCaml runtime, in Rust.
//!
//! The OCaml manual chapter [Interfacing C with OCaml](https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html) does
//! a great job of explaining low-level details about how to safely interact with the OCaml runtime. This crate aims to
//! be a slightly higher-level of abstraction, with minimal added overhead.
//!
//! ## Getting started
//!
//! Take a look at the [ocaml-rust-starter](http://github.com/zshipko/ocaml-rust-starter) project for a basic example to help get started with `ocaml-rs`.
//!
//! ## Examples
//!
//! ```rust,no_run
//! // Automatically derive `IntoValue` and `FromValue`
//! #[cfg(feature = "derive")]
//! #[derive(ocaml::IntoValue, ocaml::FromValue)]
//! struct Example {
//!     name: String,
//!     i: ocaml::Int,
//! }
//!
//! #[cfg(feature = "derive")]
//! #[ocaml::func]
//! pub fn incr_example(mut e: Example) -> Example {
//!     e.i += 1;
//!     e
//! }
//!
//! #[cfg(feature = "derive")]
//! #[ocaml::func]
//! pub fn build_tuple(i: ocaml::Int) -> (ocaml::Int, ocaml::Int, ocaml::Int) {
//!     (i + 1, i + 2, i + 3)
//! }
//!
//! /// A name for the garbage collector handle can also be specified:
//! #[cfg(feature = "derive")]
//! #[ocaml::func(my_gc_handle)]
//! pub unsafe fn my_string() -> ocaml::Value {
//!     ocaml::Value::string("My string")
//! }
//!
//! #[cfg(feature = "derive")]
//! #[ocaml::func]
//! pub fn average(arr: ocaml::Array<f64>) -> Result<f64, ocaml::Error> {
//!     let mut sum = 0f64;
//!
//!     for i in 0..arr.len() {
//!         sum += arr.get_double(i)?;
//!     }
//!
//!     Ok(sum / arr.len() as f64)
//! }
//!
//! // A `native_func` must take `ocaml::Value` for every argument or `f64` for
//! // every unboxed argument and return an `ocaml::Value` (or `f64`).
//! // `native_func` has minimal overhead compared to wrapping with `func`
//! #[cfg(feature = "derive")]
//! #[ocaml::native_func]
//! pub unsafe fn incr(value: ocaml::Value) -> ocaml::Value {
//!     let i = value.int_val();
//!     ocaml::Value::int(i + 1)
//! }
//!
//! // This is equivalent to:
//! #[no_mangle]
//! pub unsafe extern "C" fn incr2(value: ocaml::Value) -> ocaml::Value {
//!     ocaml::body!(gc: {
//!         let i = value.int_val();
//!         ocaml::Value::int( i + 1)
//!     })
//! }
//!
//! // `ocaml::native_func` is responsible for:
//! // - Ensures that #[no_mangle] and extern "C" are added, in addition to wrapping
//! // - Wraps the function body using `ocaml::body!`
//!
//! // Finally, if your function is marked [@@unboxed] and [@@noalloc] in OCaml then you can avoid
//! // boxing altogether for f64 arguments using a plain C function and a bytecode function
//! // definition:
//! #[no_mangle]
//! pub extern "C" fn incrf(input: f64) -> f64 {
//!     input + 1.0
//! }
//!
//! #[cfg(feature = "derive")]
//! #[ocaml::bytecode_func]
//! pub fn incrf_bytecode(input: f64) -> f64 {
//!     incrf(input)
//! }
//! ```
//!
//! The OCaml stubs would look like this:
//!
//! ```ocaml
//! type example = {
//!     name: string;
//!     i: int;
//! }
//!
//! external incr_example: example -> example = "incr_example"
//! external build_tuple: int -> int * int * int = "build_tuple"
//! external average: float array -> float = "average"
//! external incr: int -> int = "incr"
//! external incr2: int -> int = "incr2"
//! external incrf: float -> float = "incrf_bytecode" "incrf" [@@unboxed] [@@noalloc]
//! ```

#[cfg(all(feature = "link", feature = "no-std"))]
std::compile_error!("Cannot use link and no-std features");

pub use ocaml_interop::{self as interop, OCaml, OCamlRef, OCamlRuntime as Runtime};

/// The `sys` module contains the low-level implementation of the OCaml runtime
pub use ocaml_sys as sys;

#[cfg(feature = "derive")]
pub use ocaml_derive::{
    ocaml_bytecode_func as bytecode_func, ocaml_func as func, ocaml_native_func as native_func,
    FromValue, IntoValue,
};

#[macro_use]
mod macros;

mod conv;
mod error;
mod tag;
mod types;
mod util;
mod value;

/// Rooted values
pub mod root;

/// Functions for interacting with the OCaml runtime
pub mod runtime;

/// Custom types, used for allocating Rust values owned by the OCaml garbage collector
pub mod custom;

pub use crate::custom::Custom;
pub use crate::error::{CamlError, Error};
pub use crate::runtime::*;
pub use crate::tag::Tag;
pub use crate::types::{bigarray, Array, List, Pointer};
pub use crate::value::{FromValue, IntoValue, Raw, Value};

#[cfg(not(feature = "no-std"))]
pub use crate::macros::inital_setup;

/// OCaml `float`
pub type Float = f64;

/// Integer type that converts to OCaml `int`
pub type Int = sys::Intnat;

/// Unsigned integer type that converts to OCaml `int`
pub type Uint = sys::Uintnat;

/// Wraps `sys::COMPILER` as `std::process::Command`
#[cfg(not(any(feature = "no-std", feature = "without-ocamlopt")))]
pub fn ocamlopt() -> std::process::Command {
    std::process::Command::new(sys::COMPILER)
}

#[cfg(feature = "link")]
#[cfg(test)]
mod tests;
