//! Bigarray bindings

use crate::mlvalues::{Intnat, Uintnat, Value};
use core::ffi::c_void;

pub type Data = *mut c_void;

#[repr(C)]
pub struct BigarrayProxy {
    refcount: Intnat,
    data: Data,
    size: Uintnat,
}

#[repr(C)]
pub struct Bigarray {
    pub data: Data,
    pub num_dims: Intnat,
    pub flags: Intnat,
    pub proxy: *const BigarrayProxy,
    pub dim: [Intnat; 0],
}

#[allow(non_camel_case_types)]
pub enum Managed {
    EXTERNAL = 0,         /* Data is not allocated by OCaml */
    MANAGED = 0x200,      /* Data is allocated by OCaml */
    MAPPED_FILE = 0x400,  /* Data is a memory mapped file */
    MANAGED_MASK = 0x600, /* Mask for "managed" bits in flags field */
}

#[allow(non_camel_case_types)]
pub enum Kind {
    FLOAT32 = 0x00,    /* Single-precision floats */
    FLOAT64 = 0x01,    /* Double-precision floats */
    SINT8 = 0x02,      /* Signed 8-bit integers */
    UINT8 = 0x03,      /* Unsigned 8-bit integers */
    SINT16 = 0x04,     /* Signed 16-bit integers */
    UINT16 = 0x05,     /* Unsigned 16-bit integers */
    INT32 = 0x06,      /* Signed 32-bit integers */
    INT64 = 0x07,      /* Signed 64-bit integers */
    CAML_INT = 0x08,   /* OCaml-style integers (signed 31 or 63 bits) */
    NATIVE_INT = 0x09, /* Platform-native long integers (32 or 64 bits) */
    COMPLEX32 = 0x0a,  /* Single-precision complex */
    COMPLEX64 = 0x0b,  /* Double-precision complex */
    CHAR = 0x0c,       /* Characters */
    KIND_MASK = 0xFF,  /* Mask for kind in flags field */
}

extern "C" {
    pub fn malloc(size: usize) -> Data;
    pub fn caml_ba_alloc(flags: i32, num_dims: i32, data: Data, dim: *const i32) -> Value;
    pub fn caml_ba_alloc_dims(flags: i32, num_dims: i32, data: Data, ...) -> Value;
    pub fn caml_ba_byte_size(b: *const Bigarray) -> u32;
}
