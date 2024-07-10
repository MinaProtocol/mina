#![allow(non_camel_case_types)]
#[allow(unused)]
use crate::{Char, Value};

#[repr(C)]
#[derive(Debug, Copy, Clone)]
#[cfg(caml_state)]
pub struct caml_ref_table {
    pub _address: u8,
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
#[cfg(caml_state)]
pub struct caml_ephe_ref_table {
    pub _address: u8,
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
#[cfg(caml_state)]
pub struct caml_custom_table {
    pub _address: u8,
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
#[cfg(caml_state)]
pub struct longjmp_buffer {
    pub _address: u8,
}

#[cfg(caml_state)]
pub type backtrace_slot = *mut ::core::ffi::c_void;

#[repr(C)]
#[derive(Debug, Copy, Clone)]
#[cfg(caml_state)]
pub struct caml_domain_state {
    pub _young_ptr: *mut Value,
    pub _young_limit: *mut Value,
    pub _exception_pointer: *mut Char,
    pub _young_base: *mut ::core::ffi::c_void,
    pub _young_start: *mut Value,
    pub _young_end: *mut Value,
    pub _young_alloc_start: *mut Value,
    pub _young_alloc_end: *mut Value,
    pub _young_alloc_mid: *mut Value,
    pub _young_trigger: *mut Value,
    pub _minor_heap_wsz: usize,
    pub _in_minor_collection: isize,
    pub _extra_heap_resources_minor: f64,
    pub _ref_table: *mut caml_ref_table,
    pub _ephe_ref_table: *mut caml_ephe_ref_table,
    pub _custom_table: *mut caml_custom_table,
    pub _stack_low: *mut Value,
    pub _stack_high: *mut Value,
    pub _stack_threshold: *mut Value,
    pub _extern_sp: *mut Value,
    pub _trapsp: *mut Value,
    pub _trap_barrier: *mut Value,
    pub _external_raise: *mut longjmp_buffer,
    pub _exn_bucket: Value,
    pub _top_of_stack: *mut Char,
    pub _bottom_of_stack: *mut Char,
    pub _last_return_address: usize,
    pub _gc_regs: *mut Value,
    pub _backtrace_active: isize,
    pub _backtrace_pos: isize,
    pub _backtrace_buffer: *mut backtrace_slot,
    pub _backtrace_last_exn: Value,
    pub _compare_unordered: isize,
    pub _requested_major_slice: isize,
    pub _requested_minor_gc: isize,
    pub _local_roots: *mut crate::memory::CamlRootsBlock,
    pub _stat_minor_words: f64,
    pub _stat_promoted_words: f64,
    pub _stat_major_words: f64,
    pub _stat_minor_collections: isize,
    pub _stat_major_collections: isize,
    pub _stat_heap_wsz: isize,
    pub _stat_top_heap_wsz: isize,
    pub _stat_compactions: isize,
    pub _stat_heap_chunks: isize,
}

#[cfg(caml_state)]
extern "C" {
    #[doc(hidden)]
    pub static mut Caml_state: *mut caml_domain_state;
}

#[cfg(not(caml_state))]
extern "C" {

    #[doc(hidden)]
    pub static mut caml_local_roots: *mut crate::memory::CamlRootsBlock;
}

#[cfg(caml_state)]
#[doc(hidden)]
pub unsafe fn local_roots() -> *mut crate::memory::CamlRootsBlock {
    (*Caml_state)._local_roots
}

#[cfg(caml_state)]
#[doc(hidden)]
pub unsafe fn set_local_roots(x: *mut crate::memory::CamlRootsBlock) {
    (*Caml_state)._local_roots = x
}

#[cfg(not(caml_state))]
#[doc(hidden)]
pub unsafe fn local_roots() -> *mut crate::memory::CamlRootsBlock {
    caml_local_roots
}

#[cfg(not(caml_state))]
#[doc(hidden)]
pub unsafe fn set_local_roots(x: *mut crate::memory::CamlRootsBlock) {
    caml_local_roots = x
}

#[test]
#[cfg(caml_state)]
fn bindgen_test_layout_caml_domain_state() {
    assert_eq!(
        ::core::mem::size_of::<caml_domain_state>(),
        360usize,
        concat!("Size of: ", stringify!(caml_domain_state))
    );
    assert_eq!(
        ::core::mem::align_of::<caml_domain_state>(),
        8usize,
        concat!("Alignment of ", stringify!(caml_domain_state))
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._young_ptr as *const _ as usize },
        0usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_ptr)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._young_limit as *const _ as usize },
        8usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_limit)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._exception_pointer as *const _ as usize
        },
        16usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_exception_pointer)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._young_base as *const _ as usize },
        24usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_base)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._young_start as *const _ as usize },
        32usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_start)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._young_end as *const _ as usize },
        40usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_end)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._young_alloc_start as *const _ as usize
        },
        48usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_alloc_start)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._young_alloc_end as *const _ as usize
        },
        56usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_alloc_end)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._young_alloc_mid as *const _ as usize
        },
        64usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_alloc_mid)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._young_trigger as *const _ as usize
        },
        72usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_young_trigger)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._minor_heap_wsz as *const _ as usize
        },
        80usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_minor_heap_wsz)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._in_minor_collection as *const _ as usize
        },
        88usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_in_minor_collection)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._extra_heap_resources_minor as *const _
                as usize
        },
        96usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_extra_heap_resources_minor)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._ref_table as *const _ as usize },
        104usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_ref_table)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._ephe_ref_table as *const _ as usize
        },
        112usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_ephe_ref_table)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._custom_table as *const _ as usize
        },
        120usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_custom_table)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._stack_low as *const _ as usize },
        128usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stack_low)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._stack_high as *const _ as usize },
        136usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stack_high)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stack_threshold as *const _ as usize
        },
        144usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stack_threshold)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._extern_sp as *const _ as usize },
        152usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_extern_sp)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._trapsp as *const _ as usize },
        160usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_trapsp)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._trap_barrier as *const _ as usize
        },
        168usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_trap_barrier)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._external_raise as *const _ as usize
        },
        176usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_external_raise)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._exn_bucket as *const _ as usize },
        184usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_exn_bucket)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._top_of_stack as *const _ as usize
        },
        192usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_top_of_stack)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._bottom_of_stack as *const _ as usize
        },
        200usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_bottom_of_stack)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._last_return_address as *const _ as usize
        },
        208usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_last_return_address)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._gc_regs as *const _ as usize },
        216usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_gc_regs)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._backtrace_active as *const _ as usize
        },
        224usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_backtrace_active)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._backtrace_pos as *const _ as usize
        },
        232usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_backtrace_pos)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._backtrace_buffer as *const _ as usize
        },
        240usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_backtrace_buffer)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._backtrace_last_exn as *const _ as usize
        },
        248usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_backtrace_last_exn)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._compare_unordered as *const _ as usize
        },
        256usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_compare_unordered)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._requested_major_slice as *const _
                as usize
        },
        264usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_requested_major_slice)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._requested_minor_gc as *const _ as usize
        },
        272usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_requested_minor_gc)
        )
    );
    assert_eq!(
        unsafe { &(*(::core::ptr::null::<caml_domain_state>()))._local_roots as *const _ as usize },
        280usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_local_roots)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_minor_words as *const _ as usize
        },
        288usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_minor_words)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_promoted_words as *const _ as usize
        },
        296usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_promoted_words)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_major_words as *const _ as usize
        },
        304usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_major_words)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_minor_collections as *const _
                as usize
        },
        312usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_minor_collections)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_major_collections as *const _
                as usize
        },
        320usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_major_collections)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_heap_wsz as *const _ as usize
        },
        328usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_heap_wsz)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_top_heap_wsz as *const _ as usize
        },
        336usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_top_heap_wsz)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_compactions as *const _ as usize
        },
        344usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_compactions)
        )
    );
    assert_eq!(
        unsafe {
            &(*(::core::ptr::null::<caml_domain_state>()))._stat_heap_chunks as *const _ as usize
        },
        352usize,
        concat!(
            "Offset of field: ",
            stringify!(caml_domain_state),
            "::",
            stringify!(_stat_heap_chunks)
        )
    );
}
