// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

use ocaml_boxroot_sys::{boxroot_setup, boxroot_teardown};
use std::marker::PhantomData;

use crate::{memory::OCamlRef, value::OCaml};

/// OCaml runtime handle.
///
/// Should be initialized once at the beginning of the program
/// and the obtained handle passed around.
///
/// Once the handle is dropped, the OCaml runtime will be shutdown.
pub struct OCamlRuntime {
    _private: (),
}

impl OCamlRuntime {
    /// Initializes the OCaml runtime and returns an OCaml runtime handle.
    ///
    /// Once the handle is dropped, the OCaml runtime will be shutdown.
    pub fn init() -> Self {
        Self::init_persistent();
        Self { _private: () }
    }

    /// Initializes the OCaml runtime.
    ///
    /// After the first invocation, this method does nothing.
    pub fn init_persistent() {
        #[cfg(not(feature = "no-caml-startup"))]
        {
            static INIT: std::sync::Once = std::sync::Once::new();

            INIT.call_once(|| {
                let arg0 = "ocaml\0".as_ptr() as *const ocaml_sys::Char;
                let c_args = vec![arg0, core::ptr::null()];
                unsafe {
                    ocaml_sys::caml_startup(c_args.as_ptr());
                }
            })
        }
        #[cfg(feature = "no-caml-startup")]
        panic!("Rust code that is called from an OCaml program should not try to initialize the runtime.");
    }

    /// Recover the runtime handle.
    ///
    /// This method is used internally, do not use directly in code, only when writing tests.
    ///
    /// # Safety
    ///
    /// This function is unsafe because the OCaml runtime handle should be obtained once
    /// upon initialization of the OCaml runtime and then passed around. This method exists
    /// only to ease the authoring of tests.
    #[inline(always)]
    pub unsafe fn recover_handle() -> &'static mut Self {
        static mut RUNTIME: OCamlRuntime = OCamlRuntime { _private: () };
        &mut RUNTIME
    }

    /// Release the OCaml runtime lock, call `f`, and re-acquire the OCaml runtime lock.
    pub fn releasing_runtime<T, F>(&mut self, f: F) -> T
    where
        F: FnOnce() -> T,
    {
        OCamlBlockingSection::new().perform(f)
    }

    /// Returns the OCaml valued to which this GC tracked reference points to.
    pub fn get<'tmp, T>(&'tmp self, reference: OCamlRef<T>) -> OCaml<'tmp, T> {
        OCaml {
            _marker: PhantomData,
            raw: unsafe { reference.get_raw() },
        }
    }
}

impl Drop for OCamlRuntime {
    fn drop(&mut self) {
        unsafe {
            boxroot_teardown();
            ocaml_sys::caml_shutdown();
        }
    }
}

struct OCamlBlockingSection {}

impl OCamlBlockingSection {
    fn new() -> Self {
        Self {}
    }

    fn perform<T, F>(self, f: F) -> T
    where
        F: FnOnce() -> T,
    {
        unsafe { ocaml_sys::caml_enter_blocking_section() };
        f()
    }
}

impl Drop for OCamlBlockingSection {
    fn drop(&mut self) {
        unsafe { ocaml_sys::caml_leave_blocking_section() };
    }
}

// For initializing from an OCaml-driven program

#[no_mangle]
extern "C" fn ocaml_interop_setup(_unit: crate::RawOCaml) -> crate::RawOCaml {
    unsafe { boxroot_setup() };
    ocaml_sys::UNIT
}

#[no_mangle]
extern "C" fn ocaml_interop_teardown(_unit: crate::RawOCaml) -> crate::RawOCaml {
    unsafe { boxroot_teardown() };
    ocaml_sys::UNIT
}
