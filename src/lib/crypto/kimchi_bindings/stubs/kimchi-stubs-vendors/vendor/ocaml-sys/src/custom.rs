use crate::*;

use mlvalues::{Intnat, Size, Uintnat};

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct custom_fixed_length {
    pub bsize_32: Intnat,
    pub bsize_64: Intnat,
}
#[test]
fn bindgen_test_layout_custom_fixed_length() {
    assert_eq!(
        ::core::mem::size_of::<custom_fixed_length>(),
        16usize,
        concat!("Size of: ", stringify!(custom_fixed_length))
    );
    assert_eq!(
        ::core::mem::align_of::<custom_fixed_length>(),
        8usize,
        concat!("Alignment of ", stringify!(custom_fixed_length))
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_fixed_length>())).bsize_32 as *const _ as usize },
        0usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_fixed_length),
            "::",
            stringify!(bsize_32)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_fixed_length>())).bsize_64 as *const _ as usize },
        8usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_fixed_length),
            "::",
            stringify!(bsize_64)
        )
    );
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct custom_operations {
    pub identifier: *const Char,
    pub finalize: ::core::option::Option<unsafe extern "C" fn(v: Value)>,
    pub compare: ::core::option::Option<unsafe extern "C" fn(v1: Value, v2: Value) -> i32>,
    pub hash: ::core::option::Option<unsafe extern "C" fn(v: Value) -> Intnat>,
    pub serialize: ::core::option::Option<
        unsafe extern "C" fn(v: Value, bsize_32: *mut Uintnat, bsize_64: *mut Uintnat),
    >,
    pub deserialize:
        ::core::option::Option<unsafe extern "C" fn(dst: *mut ::core::ffi::c_void) -> Uintnat>,
    pub compare_ext: ::core::option::Option<unsafe extern "C" fn(v1: Value, v2: Value) -> i32>,
    pub fixed_length: *const custom_fixed_length,
}
#[test]
fn bindgen_test_layout_custom_operations() {
    assert_eq!(
        ::core::mem::size_of::<custom_operations>(),
        64usize,
        concat!("Size of: ", stringify!(custom_operations))
    );
    assert_eq!(
        ::core::mem::align_of::<custom_operations>(),
        8usize,
        concat!("Alignment of ", stringify!(custom_operations))
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).identifier as *const _ as usize },
        0usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(identifier)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).finalize as *const _ as usize },
        8usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(finalize)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).compare as *const _ as usize },
        16usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(compare)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).hash as *const _ as usize },
        24usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(hash)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).serialize as *const _ as usize },
        32usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(serialize)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).deserialize as *const _ as usize },
        40usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(deserialize)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).compare_ext as *const _ as usize },
        48usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(compare_ext)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<custom_operations>())).fixed_length as *const _ as usize },
        56usize,
        concat!(
            "Offset of field: ",
            stringify!(custom_operations),
            "::",
            stringify!(fixed_length)
        )
    );
}
extern "C" {
    pub fn caml_alloc_custom(
        ops: *const custom_operations,
        size: Uintnat,
        mem: Size,
        max: Size,
    ) -> Value;
}
extern "C" {
    pub fn caml_alloc_custom_mem(ops: *mut custom_operations, size: Uintnat, mem: Size) -> Value;
}
extern "C" {
    pub fn caml_register_custom_operations(ops: *mut custom_operations);
}
