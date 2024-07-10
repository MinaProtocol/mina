// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

#![doc(html_root_url = "https://docs.rs/ocaml-interop/0.8.8")]

//! _Zinc-iron alloy coating is used in parts that need very good corrosion protection._
//!
//! **API IS CONSIDERED UNSTABLE AT THE MOMENT AND IS LIKELY TO CHANGE IN THE FUTURE**
//!
//! [ocaml-interop](https://github.com/tezedge/ocaml-interop) is an OCaml<->Rust FFI with an emphasis
//! on safety inspired by [caml-oxide](https://github.com/stedolan/caml-oxide),
//! [ocaml-rs](https://github.com/zshipko/ocaml-rs) and [CAMLroot](https://arxiv.org/abs/1812.04905).
//!
//! ## Table of Contents
//!
//! - [Usage](#usage)
//!   * [The OCaml runtime handle](#the-ocaml-runtime-handle)
//!   * [OCaml value representation](#ocaml-value-representation)
//!   * [Converting between OCaml and Rust data](#converting-between-ocaml-and-rust-data)
//!     + [`FromOCaml` trait](#fromocaml-trait)
//!     + [`ToOCaml` trait](#toocaml-trait)
//!   * [Calling convention](#calling-convention)
//!   * [OCaml exceptions](#ocaml-exceptions)
//!   * [Calling into OCaml from Rust](#calling-into-ocaml-from-rust)
//!   * [Calling into Rust from OCaml](#calling-into-rust-from-ocaml)
//! - [References and links](#references-and-links)
//!
//! ## Usage
//!
//! ### The OCaml runtime handle
//!
//! The OCaml runtime handle is represented by a [`OCamlRuntime`] value. To be able to use of the capabilities
//! offered by the OCaml runtime, access to this handle is required. The handle is first obtained when calling
//! [`OCamlRuntime::init`] to initialize the OCaml runtime. Rust functions called form OCaml will also receive
//! a `&mut OCamlRuntime` as their first argument.
//!
//! This OCaml runtime handle must belong to a single thread, and passed around (moved or as a `&mut` reference)
//! to any code that needs access to the OCaml runtime.
//!
//! Un-rooted non-immediate OCaml values have a lifetime associated to the OCaml runtime handle, and will become
//! stale once the OCaml runtime is mutably borrowed.
//!
//! ### OCaml value representation
//!
//! OCaml values are exposed to Rust using three types:
//!
//! - [`OCaml`]`<'gc, T>` is the representation of OCaml values in Rust. These values become stale
//!   after calls into the OCaml runtime and must be re-referenced.
//! - [`BoxRoot`]`<T>` is a container for an [`OCaml`]`<T>` value that is rooted and tracked by
//!   OCaml's Garbage Collector.
//! - [`OCamlRef`]`<'a, T>` is a reference to an [`OCaml`]`<T>` value that may or may not be rooted.
//!
//! ### Converting between OCaml and Rust data
//!
//! #### [`FromOCaml`] trait
//!
//! The [`FromOCaml`] trait implements conversion from OCaml values into Rust values, using the `from_ocaml` function.
//!
//! [`OCaml`]`<T>` values have a `to_rust()` method that is usually more convenient than `Type::from_ocaml(ocaml_value)`,
//! and works for any combination that implements the `FromOCaml` trait.
//!
//! [`OCamlRef`]`<T>` values have a `to_rust(cr)` that needs an [`OCamlRuntime`] reference to be passed to it.
//!
//! #### [`ToOCaml`] trait
//!
//! The [`ToOCaml`] trait implements conversion from Rust values into OCaml values, using the `to_ocaml` method.
//! It takes a single parameter that must be a `&mut OCamlRuntime`.
//!
//! ### Calling convention
//!
//! There are two possible calling conventions in regards to rooting, one with *callee rooted arguments*,
//! and another with *caller rooted arguments*.
//!
//! #### Callee rooted arguments calling convention
//!
//! With this calling convention, values that are arguments to a function call are passed directly.
//! Functions that receive arguments are responsible for rooting them. This is how OCaml's C API and
//! `ocaml-interop` versions before `0.5.0` work.
//!
//! #### Caller rooted arguments calling convention
//!
//! With this calling convention, values that are arguments to a function call must be rooted by the caller.
//! Then instead of the value, it is the root pointing to the value that is passed as an argument.
//! This is how `ocaml-interop` works starting with version `0.5.0`.
//!
//! When a Rust function is called from OCaml, it will receive arguments as [`OCamlRef`]`<T>` values,
//! and when a OCaml function is called from Rust, arguments will be passed as [`OCamlRef`]`<T>` values.
//!
//! #### Return values
//!
//! When an OCaml function is called from Rust, the return value is a [`BoxRoot`]`<T>`.
//!
//! Rust functions that are meant to be called from OCaml must return [`OCaml`]`<T>` values.
//!
//! ### OCaml exceptions
//!
//! If an OCaml function called from Rust raises an exception, this will result in a panic.
//!
//! OCaml functions meant to be called from Rust should not raise exceptions to signal errors,
//! but instead return `result` or `option` values, which can then be mapped into `Result` and
//! `Option` values in Rust.
//!
//! ### Calling into OCaml from Rust
//!
//! The following code defines two OCaml functions and registers them using the `Callback.register` mechanism:
//!
//! ```ocaml
//! let increment_bytes bytes first_n =
//!   let limit = (min (Bytes.length bytes) first_n) - 1 in
//!   for i = 0 to limit do
//!     let value = (Bytes.get_uint8 bytes i) + 1 in
//!     Bytes.set_uint8 bytes i value
//!   done;
//!   bytes
//!
//! let twice x = 2 * x
//!
//! let () =
//!   Callback.register "increment_bytes" increment_bytes;
//!   Callback.register "twice" twice
//! ```
//!
//! To be able to call these from Rust, there are a few things that need to be done:
//!
//! - Rust-driven programs must initialize the OCaml runtime.
//! - Functions that were exported from the OCaml side with `Callback.register` have to be declared using the [`ocaml!`] macro.
//!
//! ### Example
//!
//! ```rust,no_run
//! use ocaml_interop::{
//!     BoxRoot, FromOCaml, OCaml, OCamlInt, OCamlRef, ToOCaml, OCamlRuntime
//! };
//!
//! // To call an OCaml function, it first has to be declared inside an `ocaml!` macro block:
//! mod ocaml_funcs {
//!     use ocaml_interop::{ocaml, OCamlInt};
//!
//!     ocaml! {
//!         // OCaml: `val increment_bytes: bytes -> int -> bytes`
//!         // registered with `Callback.register "increment_bytes" increment_bytes`.
//!         // In Rust, this will be exposed as:
//!         //     pub fn increment_bytes(
//!         //         _: &mut OCamlRuntime,
//!         //         bytes: OCamlRef<String>,
//!         //         first_n: OCamlRef<OCamlInt>,
//!         //     ) -> BoxRoot<String>;
//!         pub fn increment_bytes(bytes: String, first_n: OCamlInt) -> String;
//!         // OCaml: `val twice: int -> int`
//!         // registered with `Callback.register "twice" twice`.
//!         // In Rust this will be exposed as:
//!         //     pub fn twice(
//!         //         _: &mut OCamlRuntime,
//!         //         num: OCamlRef<OCamlInt>,
//!         //     ) -> BoxRoot<OCamlInt>;
//!         pub fn twice(num: OCamlInt) -> OCamlInt;
//!     }
//! }
//!
//! fn increment_bytes(
//!     cr: &mut OCamlRuntime,
//!     bytes1: String,
//!     bytes2: String,
//!     first_n: usize,
//! ) -> (String, String) {
//!     // Any calls into the OCaml runtime takes as input a `&mut` reference to an `OCamlRuntime`
//!     // value that is obtained as the result of initializing the OCaml runtime with the
//!     // `OCamlRuntime::init()` call.
//!     // The `ToOCaml` trait provides the `to_ocaml` and `to_boxroot` methods to convert Rust
//!     // values into OCaml values.
//!     // Here `to_boxroot` is used to produce OCaml values that are already rooted.
//!     let ocaml_bytes1_rooted: BoxRoot<String> = bytes1.to_boxroot(cr);
//!     let ocaml_bytes2_rooted = bytes2.to_boxroot(cr);
//!
//!     // Rust `i64` integers can be converted into OCaml fixnums with `OCaml::of_i64`
//!     // and `OCaml::of_i64_unchecked`.
//!     // Such conversion doesn't require any allocation on the OCaml side, and doesn't
//!     // invalidate other `OCaml<T>` values. In addition, these immediate values require rooting.
//!     let ocaml_first_n: OCaml<'static, OCamlInt> =
//!         unsafe { OCaml::of_i64_unchecked(first_n as i64) };
//!
//!     // Any OCaml function (declared above in a `ocaml!` block) can be called as a regular
//!     // Rust function, by passing a `&mut OCamlRuntime` as the first argument, followed by
//!     // the rest of the arguments declared for that function.
//!     // Arguments to these functions must be `OCamlRef<T>` values. These are the result of
//!     // dereferencing `OCaml<T>` and `BoxRoot<T>` values.
//!     let result1 = ocaml_funcs::increment_bytes(
//!         cr,                   // &mut OCamlRuntime
//!         &ocaml_bytes1_rooted, // OCamlRef<String>
//!         &ocaml_first_n,       // OCamlRef<OCamlInt>
//!     );
//!
//!     let result2 = ocaml_funcs::increment_bytes(
//!         cr,
//!         &ocaml_bytes2_rooted,
//!         &ocaml_first_n,
//!     );
//!
//!     (result1.to_rust(cr), result2.to_rust(cr))
//! }
//!
//! fn twice(cr: &mut OCamlRuntime, num: usize) -> usize {
//!     let ocaml_num = unsafe { OCaml::of_i64_unchecked(num as i64) };
//!     let result = ocaml_funcs::twice(cr, &ocaml_num);
//!     result.to_rust::<i64>(cr) as usize
//! }
//!
//! fn entry_point() {
//!     // IMPORTANT: the OCaml runtime has to be initialized first.
//!     let mut cr = OCamlRuntime::init();
//!     // `cr` is the OCaml runtime handle, must be passed to any function
//!     // that interacts with the OCaml runtime.
//!     let first_n = twice(&mut cr, 5);
//!     let bytes1 = "000000000000000".to_owned();
//!     let bytes2 = "aaaaaaaaaaaaaaa".to_owned();
//!     println!("Bytes1 before: {}", bytes1);
//!     println!("Bytes2 before: {}", bytes2);
//!     let (result1, result2) = increment_bytes(&mut cr, bytes1, bytes2, first_n);
//!     println!("Bytes1 after: {}", result1);
//!     println!("Bytes2 after: {}", result2);
//!     // `OCamlRuntime`'s `Drop` implementation will pefrorm the necessary cleanup
//!     // to shutdown the OCaml runtime.
//! }
//! ```
//!
//! ### Calling into Rust from OCaml
//!
//! To be able to call a Rust function from OCaml, it has to be defined in a way that exposes it to OCaml. This can be done with the [`ocaml_export!`] macro.
//!
//! #### Example
//!
//! ```rust,no_run
//! use ocaml_interop::{
//!     ocaml_export, FromOCaml, OCamlInt, OCaml, OCamlBytes,
//!     OCamlRef, ToOCaml,
//! };
//!
//! // `ocaml_export` expands the function definitions by adding `pub` visibility and
//! // the required `#[no_mangle]` and `extern` declarations. It also takes care of
//! // acquiring the OCaml runtime handle and binding it to the name provided as
//! // the first parameter of the function.
//! ocaml_export! {
//!     // The first parameter is a name to which the GC frame handle will be bound to.
//!     // The remaining parameters must have type `OCamlRef<T>`, and the return
//!     // value `OCaml<T>`.
//!     fn rust_twice(cr, num: OCamlRef<OCamlInt>) -> OCaml<OCamlInt> {
//!         let num: i64 = num.to_rust(cr);
//!         unsafe { OCaml::of_i64_unchecked(num * 2) }
//!     }
//!
//!     fn rust_increment_bytes(
//!         cr,
//!         bytes: OCamlRef<OCamlBytes>,
//!         first_n: OCamlRef<OCamlInt>,
//!     ) -> OCaml<OCamlBytes> {
//!         let first_n: i64 = first_n.to_rust(cr);
//!         let first_n = first_n as usize;
//!         let mut vec: Vec<u8> = bytes.to_rust(cr);
//!
//!         for i in 0..first_n {
//!             vec[i] += 1;
//!         }
//!
//!         vec.to_ocaml(cr)
//!     }
//! }
//! ```
//!
//! Then in OCaml, these functions can be referred to in the same way as C functions:
//!
//! ```ocaml
//! external rust_twice: int -> int = "rust_twice"
//! external rust_increment_bytes: bytes -> int -> bytes = "rust_increment_bytes"
//! ```
//!
//! ## References and links
//!
//! - OCaml Manual: [Chapter 20  Interfacing C with OCaml](https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html).
//! - [Safely Mixing OCaml and Rust](https://docs.google.com/viewer?a=v&pid=sites&srcid=ZGVmYXVsdGRvbWFpbnxtbHdvcmtzaG9wcGV8Z3g6NDNmNDlmNTcxMDk1YTRmNg) paper by Stephen Dolan.
//! - [Safely Mixing OCaml and Rust](https://www.youtube.com/watch?v=UXfcENNM_ts) talk by Stephen Dolan.
//! - [CAMLroot: revisiting the OCaml FFI](https://arxiv.org/abs/1812.04905).
//! - [caml-oxide](https://github.com/stedolan/caml-oxide), the code from that paper.
//! - [ocaml-rs](https://github.com/zshipko/ocaml-rs), another OCaml<->Rust FFI library.

mod boxroot;
mod closure;
mod conv;
mod error;
mod macros;
mod memory;
mod mlvalues;
mod runtime;
mod value;

pub use crate::boxroot::BoxRoot;

pub use crate::closure::{OCamlFn1, OCamlFn2, OCamlFn3, OCamlFn4, OCamlFn5};
pub use crate::conv::{FromOCaml, ToOCaml};
pub use crate::error::OCamlException;
pub use crate::memory::alloc_cons as cons;
pub use crate::memory::OCamlRef;
pub use crate::mlvalues::{
    DynBox, OCamlBytes, OCamlFloat, OCamlInt, OCamlInt32, OCamlInt64, OCamlList, RawOCaml,
};
pub use crate::runtime::OCamlRuntime;
pub use crate::value::OCaml;

#[doc(hidden)]
pub mod internal {
    pub use crate::closure::OCamlClosure;
    pub use crate::memory::{alloc_tuple, caml_alloc, store_field};
    pub use crate::mlvalues::tag;
    pub use crate::mlvalues::UNIT;
    pub use ocaml_boxroot_sys::{boxroot_setup, boxroot_teardown};
    pub use ocaml_sys::caml_hash_variant;

    // To bypass ocaml_sys::int_val unsafe declaration
    pub fn int_val(val: super::RawOCaml) -> isize {
        unsafe { ocaml_sys::int_val(val) }
    }
}

#[doc(hidden)]
#[cfg(doctest)]
pub mod compile_fail_tests;

#[doc(hidden)]
#[cfg(test)]
mod compile_ok_tests;
