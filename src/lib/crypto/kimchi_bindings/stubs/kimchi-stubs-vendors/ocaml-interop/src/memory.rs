// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

use crate::{
    conv::FromOCaml,
    mlvalues::{tag, DynBox, OCamlBytes, OCamlFloat, OCamlInt32, OCamlInt64, OCamlList, RawOCaml},
    runtime::OCamlRuntime,
    value::OCaml,
};
use core::{any::Any, cell::UnsafeCell, marker::PhantomData, mem, pin::Pin, ptr};
pub use ocaml_sys::{
    caml_alloc, local_roots as ocaml_sys_local_roots, set_local_roots as ocaml_sys_set_local_roots,
    store_field,
};
use ocaml_sys::{
    caml_alloc_string, caml_alloc_tuple, caml_copy_double, caml_copy_int32, caml_copy_int64,
    custom_operations, string_val, Size,
};

pub struct OCamlCell<T> {
    cell: UnsafeCell<RawOCaml>,
    _marker: PhantomData<T>,
}

static_assertions::assert_eq_size!(OCamlCell<bool>, OCaml<'static, bool>, RawOCaml);

/// An `OCamlRef<T>` is a reference to a location containing a [`OCaml`]`<T>` value.
///
/// Usually obtained as the result of rooting an OCaml value.
pub type OCamlRef<'a, T> = &'a OCamlCell<T>;

impl<T> OCamlCell<T> {
    #[doc(hidden)]
    pub unsafe fn create_ref<'a>(val: *const RawOCaml) -> OCamlRef<'a, T> {
        &*(val as *const OCamlCell<T>)
    }

    /// Converts this value into a Rust value.
    pub fn to_rust<RustT>(&self, cr: &OCamlRuntime) -> RustT
    where
        RustT: FromOCaml<T>,
    {
        RustT::from_ocaml(cr.get(self))
    }

    /// Borrows the raw value contained in this root.
    ///
    /// # Safety
    ///
    /// The [`RawOCaml`] value obtained may become invalid after the OCaml GC runs.
    pub unsafe fn get_raw(&self) -> RawOCaml {
        *self.cell.get()
    }
}

pub fn alloc_bytes<'a>(cr: &'a mut OCamlRuntime, s: &[u8]) -> OCaml<'a, OCamlBytes> {
    unsafe {
        let len = s.len();
        let value = caml_alloc_string(len);
        let ptr = string_val(value);
        core::ptr::copy_nonoverlapping(s.as_ptr(), ptr, len);
        OCaml::new(cr, value)
    }
}

pub fn alloc_string<'a>(cr: &'a mut OCamlRuntime, s: &str) -> OCaml<'a, String> {
    unsafe {
        let len = s.len();
        let value = caml_alloc_string(len);
        let ptr = string_val(value);
        core::ptr::copy_nonoverlapping(s.as_ptr(), ptr, len);
        OCaml::new(cr, value)
    }
}

pub fn alloc_int32(cr: &mut OCamlRuntime, i: i32) -> OCaml<OCamlInt32> {
    unsafe { OCaml::new(cr, caml_copy_int32(i)) }
}

pub fn alloc_int64(cr: &mut OCamlRuntime, i: i64) -> OCaml<OCamlInt64> {
    unsafe { OCaml::new(cr, caml_copy_int64(i)) }
}

pub fn alloc_double(cr: &mut OCamlRuntime, d: f64) -> OCaml<OCamlFloat> {
    unsafe { OCaml::new(cr, caml_copy_double(d)) }
}

// TODO: it is possible to directly alter the fields memory upon first allocation of
// small values (like tuples and conses are) without going through `caml_modify` to get
// a little bit of extra performance.

pub fn alloc_some<'a, 'b, A>(
    cr: &'a mut OCamlRuntime,
    value: OCamlRef<'b, A>,
) -> OCaml<'a, Option<A>> {
    unsafe {
        let ocaml_some = caml_alloc(1, tag::SOME);
        store_field(ocaml_some, 0, value.get_raw());
        OCaml::new(cr, ocaml_some)
    }
}

pub fn alloc_ok<'a, 'b, A, Err>(
    cr: &'a mut OCamlRuntime,
    value: OCamlRef<'b, A>,
) -> OCaml<'a, Result<A, Err>> {
    unsafe {
        let ocaml_ok = caml_alloc(1, tag::TAG_OK);
        store_field(ocaml_ok, 0, value.get_raw());
        OCaml::new(cr, ocaml_ok)
    }
}

pub fn alloc_error<'a, 'b, A, Err>(
    cr: &'a mut OCamlRuntime,
    err: OCamlRef<'b, Err>,
) -> OCaml<'a, Result<A, Err>> {
    unsafe {
        let ocaml_err = caml_alloc(1, tag::TAG_ERROR);
        store_field(ocaml_err, 0, err.get_raw());
        OCaml::new(cr, ocaml_err)
    }
}

#[doc(hidden)]
pub unsafe fn alloc_tuple<T>(cr: &mut OCamlRuntime, size: usize) -> OCaml<T> {
    let ocaml_tuple = caml_alloc_tuple(size);
    OCaml::new(cr, ocaml_tuple)
}

/// List constructor
///
/// Build a new list from a head and a tail list.
pub fn alloc_cons<'a, 'b, A>(
    cr: &'a mut OCamlRuntime,
    head: OCamlRef<'b, A>,
    tail: OCamlRef<'b, OCamlList<A>>,
) -> OCaml<'a, OCamlList<A>> {
    unsafe {
        let ocaml_cons = caml_alloc(2, tag::CONS);
        store_field(ocaml_cons, 0, head.get_raw());
        store_field(ocaml_cons, 1, tail.get_raw());
        OCaml::new(cr, ocaml_cons)
    }
}

#[inline]
pub unsafe fn store_raw_field_at<A>(
    cr: &mut OCamlRuntime,
    block: OCamlRef<A>,
    offset: Size,
    raw_value: RawOCaml,
) {
    store_field(cr.get(block).get_raw(), offset, raw_value);
}

const BOX_OPS_DYN_DROP: custom_operations = custom_operations {
    identifier: "_rust_box_dyn_drop\0".as_ptr() as *const ocaml_sys::Char,
    finalize: Some(drop_box_dyn),
    compare: None,
    hash: None,
    serialize: None,
    deserialize: None,
    compare_ext: None,
    fixed_length: ptr::null(),
};

extern "C" fn drop_box_dyn(oval: RawOCaml) {
    unsafe {
        let box_ptr = ocaml_sys::field(oval, 1) as *mut Pin<Box<dyn Any>>;
        ptr::drop_in_place(box_ptr);
    }
}

// Notes by @g2p:
//
// Implementation notes: is it possible to reduce indirection?
// Could we also skip the finalizer?
//
// While putting T immediately inside the custom block as field(1)
// is tempting, GC would misalign it (UB) when moving.  Put a pointer to T instead.
// That optimisation would only work when alignment is the same as OCaml,
// meaning size_of<uintnat>.  It would also need to use different types.
//
// Use Any for now.  This allows safe downcasting when converting back to Rust.
//
// mem::needs_drop can be used to detect drop glue.
// This could be used to skip the finalizer, but only when there's no box.
// Using a lighter finalizer won't work either, the GlobalAllocator trait needs
// to know the layout before freeing the referenced block.
// malloc won't use that info, but other allocators would.
//
// Also: caml_register_custom_operations is only useful for Marshall serialization,
// skip it

/// Allocate a `DynBox` for a value of type `A`.
pub fn alloc_box<A: 'static>(cr: &mut OCamlRuntime, data: A) -> OCaml<DynBox<A>> {
    let oval;
    // A fatter Box, points to data then to vtable
    type B = Pin<Box<dyn Any>>;
    unsafe {
        oval = ocaml_sys::caml_alloc_custom(&BOX_OPS_DYN_DROP, mem::size_of::<B>(), 0, 1);
        let box_ptr = ocaml_sys::field(oval, 1) as *mut B;
        std::ptr::write(box_ptr, Box::pin(data));
    }
    unsafe { OCaml::new(cr, oval) }
}
