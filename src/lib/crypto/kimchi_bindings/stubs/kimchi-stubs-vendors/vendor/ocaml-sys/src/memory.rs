//! Defines types and macros primarily for interacting with the OCaml GC.
//!
//! # `CAMLParam` Macros
//! The following macros are used to declare C local variables and
//! function parameters of type `value`.
//!
//! The function body must start with one of the `CAMLparam` macros.
//! If the function has no parameter of type `value], use [CAMLparam0`.
//! If the function has 1 to 5 `value` parameters, use the corresponding
//!
//! `CAMLparam` with the parameters as arguments.
//! If the function has more than 5 `value] parameters, use [CAMLparam5`
//! for the first 5 parameters, and one or more calls to the `CAMLxparam`
//! macros for the others.
//!
//! If the function takes an array of `value`s as argument, use
//! `CAMLparamN] to declare it (or [CAMLxparamN` if you already have a
//! call to `CAMLparam` for some other arguments).
//!
//! If you need local variables of type `value`, declare them with one
//! or more calls to the `CAMLlocal` macros at the beginning of the
//! function, after the call to CAMLparam.  Use `CAMLlocalN` (at the
//! beginning of the function) to declare an array of `value`s.
//!
//! Your function may raise an exception or return a `value` with the
//! `CAMLreturn] macro.  Its argument is simply the [value` returned by
//! your function.  Do NOT directly return a `value] with the [return`
//! keyword.  If your function returns void, use `CAMLreturn0`.
//!
//! All the identifiers beginning with "caml__" are reserved by OCaml.
//! Do not use them for anything (local or global variables, struct or
//! union tags, macros, etc.)
//!

use core::default::Default;
use core::ptr;

use crate::mlvalues::{field, Size, Value};

#[repr(C)]
#[derive(Debug, Clone)]
pub struct CamlRootsBlock {
    pub next: *mut CamlRootsBlock,
    pub ntables: isize,
    pub nitems: isize,
    pub tables: [*mut Value; 5],
}

impl Default for CamlRootsBlock {
    fn default() -> CamlRootsBlock {
        CamlRootsBlock {
            next: ptr::null_mut(),
            ntables: 0,
            nitems: 0,
            tables: [ptr::null_mut(); 5],
        }
    }
}

extern "C" {
    pub fn caml_modify(addr: *mut Value, value: Value);
    pub fn caml_initialize(addr: *mut Value, value: Value);
}

/// Stores the `$val` at `$offset` in the `$block`.
///
/// # Original C code
///
/// ```c
/// Store_field(block, offset, val) do{ \
///   mlsize_t caml__temp_offset = (offset); \
///   value caml__temp_val = (val); \
///   caml_modify (&Field ((block), caml__temp_offset), caml__temp_val); \
/// }while(0)
/// ```
///
/// # Example
/// ```norun
/// // stores some_value in the first field in the given block
/// store_field!(some_block, 1, some_value)
/// ```
macro_rules! store_field {
    ($block:expr, $offset:expr, $val:expr) => {
        let offset = $offset;
        let val = $val;
        let block = $block;
        $crate::memory::caml_modify(field(block, offset), val);
    };
}

/// Stores the `value` in the `block` at `offset`.
///
/// # Safety
///
/// No bounds checking or validation of the OCaml values is done in this function
pub unsafe fn store_field(block: Value, offset: Size, value: Value) {
    store_field!(block, offset, value);
}

extern "C" {
    pub fn caml_enter_blocking_section();
    pub fn caml_leave_blocking_section();
    pub fn caml_register_global_root(value: *mut Value);
    pub fn caml_remove_global_root(value: *mut Value);
    pub fn caml_register_generational_global_root(value: *mut Value);
    pub fn caml_remove_generational_global_root(value: *mut Value);
    pub fn caml_modify_generational_global_root(value: *mut Value, newval: Value);
}
