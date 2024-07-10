// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

use crate::{
    boxroot::BoxRoot,
    error::OCamlFixnumConversionError,
    memory::{alloc_box, OCamlCell},
    mlvalues::*,
    FromOCaml, OCamlRef, OCamlRuntime,
};
use core::any::Any;
use core::borrow::Borrow;
use core::{marker::PhantomData, ops::Deref, slice, str};
use ocaml_sys::{caml_string_length, int_val, val_int};
use std::pin::Pin;

/// Representation of OCaml values.
pub struct OCaml<'a, T: 'a> {
    pub(crate) _marker: PhantomData<&'a T>,
    pub(crate) raw: RawOCaml,
}

impl<'a, T> Clone for OCaml<'a, T> {
    fn clone(&self) -> Self {
        OCaml {
            _marker: PhantomData,
            raw: self.raw,
        }
    }
}

impl<'a, T> Copy for OCaml<'a, T> {}

impl<'a, T> Deref for OCaml<'a, T> {
    type Target = OCamlCell<T>;

    fn deref(&self) -> OCamlRef<T> {
        self.as_ref()
    }
}

impl<'a, T> OCaml<'a, T> {
    #[doc(hidden)]
    pub unsafe fn new(_cr: &'a OCamlRuntime, x: RawOCaml) -> OCaml<'a, T> {
        OCaml {
            _marker: PhantomData,
            raw: x,
        }
    }

    #[doc(hidden)]
    pub unsafe fn field<F>(&self, i: UIntnat) -> OCaml<'a, F> {
        assert!(
            tag_val(self.raw) < tag::NO_SCAN,
            "unexpected OCaml value tag >= NO_SCAN"
        );
        assert!(
            i < wosize_val(self.raw),
            "trying to access a field bigger than the OCaml block value"
        );
        OCaml {
            _marker: PhantomData,
            raw: *(self.raw as *const RawOCaml).add(i),
        }
    }

    #[doc(hidden)]
    pub fn is_block(&self) -> bool {
        is_block(self.raw)
    }

    #[doc(hidden)]
    pub fn is_block_sized(&self, size: usize) -> bool {
        self.is_block() && unsafe { wosize_val(self.raw) == size }
    }

    #[doc(hidden)]
    pub fn is_long(&self) -> bool {
        is_long(self.raw)
    }

    #[doc(hidden)]
    pub fn tag_value(&self) -> u8 {
        assert!(
            self.is_block(),
            "attempted to access the tag on an OCaml value that isn't a block"
        );
        unsafe { tag_val(self.raw) }
    }

    /// Obtains an [`OCamlRef`]`<T>` for this value.
    pub fn as_ref<'b>(&'b self) -> OCamlRef<'b, T>
    where
        'a: 'b,
    {
        let ptr = &self.raw as *const RawOCaml;
        unsafe { OCamlCell::create_ref(ptr) }
    }

    pub fn root(self) -> BoxRoot<T> {
        BoxRoot::new(self)
    }

    /// Gets the raw representation for this value reference (pointer or int).
    ///
    /// # Safety
    ///
    /// The resulting raw pointer will not be tracked, and may become invalid
    /// after any call into the OCaml runtime. Great care must be taken when
    /// working with these values.
    pub unsafe fn raw(&self) -> RawOCaml {
        self.raw
    }

    /// Converts this OCaml value into a Rust value.
    pub fn to_rust<RustT>(&self) -> RustT
    where
        RustT: FromOCaml<T>,
    {
        RustT::from_ocaml(*self)
    }

    /// Meant to match Data_custom_val from mlvalues.h
    ///
    /// **Experimental**
    ///
    /// # Safety
    ///
    /// Casts to an arbitrary pointer type, take care before
    /// dereferencing
    ///
    /// Similar to raw(), the resulting pointer can become invalid
    /// after any call into the OCaml runtime, for example allocating
    /// OCaml values or calling OCaml functions
    pub unsafe fn custom_ptr_val<U>(&self) -> *const U {
        ocaml_sys::field(self.raw, 1) as *const U
    }
}

impl<'a, T: 'static> OCaml<'a, DynBox<T>> {
    /// Build an OCaml value wrapping a Rust value
    ///
    /// The returned value will be opaque to the OCaml side, though you
    /// can provide functions using it and expose them to OCaml.
    ///
    /// It will be dropped if it stops being referenced by the GC.
    ///
    /// **Experimental**
    pub fn box_value(cr: &'a mut OCamlRuntime, v: T) -> Self {
        alloc_box(cr, v)
    }
}

impl OCaml<'static, ()> {
    /// Returns a value that represent OCaml's unit value.
    pub fn unit() -> Self {
        OCaml {
            _marker: PhantomData,
            raw: UNIT,
        }
    }
}

// Be careful about not deriving anything on OCaml to
// uphold the Borrow contract on Eq/Ord/Hash
impl<'a, A: 'static> Borrow<A> for OCaml<'a, DynBox<A>> {
    fn borrow(&self) -> &A {
        Pin::get_ref(Pin::as_ref(
            unsafe { self.custom_ptr_val::<Pin<Box<dyn Any>>>().as_ref() }
                .expect("Custom block contains null pointer"),
        ))
        .downcast_ref::<A>()
        .expect("DynBox of wrong type, cannot downcast")
    }
}

impl<T> OCaml<'static, Option<T>> {
    /// Returns a value that represent OCaml's None value.
    pub fn none() -> Self {
        OCaml {
            _marker: PhantomData,
            raw: NONE,
        }
    }
}

impl<'a> OCaml<'a, String> {
    /// Returns an `[u8]` reference to the internal bytes of this value.
    pub fn as_bytes(&self) -> &'a [u8] {
        let s = self.raw;
        unsafe {
            assert!(
                tag_val(s) == tag::STRING,
                "attempt to perform a string operation on an OCaml value that is not a string"
            );
            slice::from_raw_parts(string_val(s), caml_string_length(s))
        }
    }

    /// Returns a `str` reference to the internal bytes of this value.
    ///
    /// # Panics
    ///
    /// Panics if the bytes do not form a valid utf8 string.
    pub fn as_str(&self) -> &'a str {
        str::from_utf8(self.as_bytes()).unwrap()
    }

    /// Returns a `str` reference to the internal bytes of this value.
    ///
    /// # Safety
    ///
    /// No checks are performed to ensure that the returned value is a valid utf8 string.
    pub unsafe fn as_str_unchecked(&self) -> &'a str {
        str::from_utf8_unchecked(self.as_bytes())
    }
}

impl<'a> OCaml<'a, OCamlBytes> {
    /// Returns an `[u8]` reference to the internal bytes of this value.
    pub fn as_bytes(&self) -> &'a [u8] {
        let s = self.raw;
        unsafe {
            assert!(
                tag_val(s) == tag::STRING,
                "attempt to perform a string operation on an OCaml value that is not a string"
            );
            slice::from_raw_parts(string_val(s), caml_string_length(s))
        }
    }

    /// Returns a `str` reference to the internal bytes of this value.
    ///
    /// # Panics
    ///
    /// Panics if the bytes do not form a valid utf8 string.
    pub fn as_str(&self) -> &'a str {
        str::from_utf8(self.as_bytes()).unwrap()
    }

    /// Returns a `str` reference to the internal bytes of this value.
    ///
    /// # Safety
    ///
    /// No checks are performed to ensure that the returned value is a valid utf8 string.
    pub unsafe fn as_str_unchecked(&self) -> &'a str {
        str::from_utf8_unchecked(self.as_bytes())
    }
}

impl<'a> OCaml<'a, OCamlInt> {
    /// Converts an OCaml int to an `i64`.
    pub fn to_i64(&self) -> i64 {
        unsafe { int_val(self.raw) as i64 }
    }

    /// Creates an OCaml int from an `i64` without checking that it fits in an OCaml fixnum.
    ///
    /// # Safety
    ///
    /// OCaml ints are represented as 63bits + 1bit tag, so when converting
    /// from an i64, a bit of precision is lost.
    pub unsafe fn of_i64_unchecked(n: i64) -> OCaml<'static, OCamlInt> {
        OCaml {
            _marker: PhantomData,
            raw: val_int(n as isize),
        }
    }

    // Creates an OCaml int from an `i64`.
    //
    // The conversion fails if the `i64` value doesn't fit in an OCaml fixnum and
    // an error is returned instead.
    pub fn of_i64(n: i64) -> Result<OCaml<'static, OCamlInt>, OCamlFixnumConversionError> {
        if n > MAX_FIXNUM as i64 {
            Err(OCamlFixnumConversionError::InputTooBig(n))
        } else if n < MIN_FIXNUM as i64 {
            Err(OCamlFixnumConversionError::InputTooSmall(n))
        } else {
            Ok(OCaml {
                _marker: PhantomData,
                raw: unsafe { val_int(n as isize) },
            })
        }
    }

    /// Creates an OCaml int from an i32.
    pub fn of_i32(n: i32) -> OCaml<'static, OCamlInt> {
        OCaml {
            _marker: PhantomData,
            raw: unsafe { val_int(n as isize) },
        }
    }
}

impl<'a> OCaml<'a, bool> {
    /// Converts an OCaml boolean into a Rust boolean.
    pub fn to_bool(&self) -> bool {
        unsafe { int_val(self.raw) != 0 }
    }

    /// Creates an OCaml boolean from a Rust boolean.
    pub fn of_bool(b: bool) -> OCaml<'static, bool> {
        OCaml {
            _marker: PhantomData,
            raw: if b { TRUE } else { FALSE },
        }
    }
}

impl<'a, A> OCaml<'a, Option<A>> {
    /// Returns true if this OCaml option value is an OCaml `None`.
    pub fn is_none(&self) -> bool {
        self.raw == NONE
    }

    /// Returns true if this OCaml option value is an OCaml `Some`.
    pub fn is_some(&self) -> bool {
        self.is_block()
    }

    /// Converts an OCaml `Option<T>` value into a Rust `Option<OCaml<T>>`.
    pub fn to_option(&self) -> Option<OCaml<'a, A>> {
        if self.is_none() {
            None
        } else {
            let value: OCaml<A> = unsafe { self.field(0) };
            Some(OCaml {
                _marker: PhantomData,
                raw: value.raw,
            })
        }
    }
}

impl<'a, A, Err> OCaml<'a, Result<A, Err>> {
    /// Returns true if this OCaml result value is an OCaml `Ok`.
    pub fn is_ok(&self) -> bool {
        self.tag_value() == tag::TAG_OK
    }

    /// Returns true if this OCaml result value is an OCaml `Error`.
    pub fn is_error(&self) -> bool {
        self.tag_value() == tag::TAG_ERROR
    }

    /// Converts an OCaml `Result<T, E>` value into a Rust `Result<OCaml<T>, OCaml<E>>`.
    pub fn to_result(&self) -> Result<OCaml<'a, A>, OCaml<'a, Err>> {
        if self.is_ok() {
            let value: OCaml<A> = unsafe { self.field(0) };
            Ok(OCaml {
                _marker: PhantomData,
                raw: value.raw,
            })
        } else if self.is_error() {
            let value: OCaml<Err> = unsafe { self.field(0) };
            Err(OCaml {
                _marker: PhantomData,
                raw: value.raw,
            })
        } else {
            panic!(
                "Unexpected tag value for OCaml<Result<...>>: {}",
                self.tag_value()
            )
        }
    }
}

impl<'a, A> OCaml<'a, OCamlList<A>> {
    /// Returns an OCaml nil (empty list) value.
    pub fn nil() -> Self {
        OCaml {
            _marker: PhantomData,
            raw: EMPTY_LIST,
        }
    }

    /// Returns true if the value is OCaml's nil (empty list).
    pub fn is_empty(&self) -> bool {
        self.raw == EMPTY_LIST
    }

    /// Returns the head of an OCaml list.
    pub fn hd(&self) -> Option<OCaml<'a, A>> {
        if self.is_empty() {
            None
        } else {
            Some(unsafe { self.field(0) })
        }
    }

    /// Returns the tail of an OCaml list.
    pub fn tl(&self) -> Option<OCaml<'a, OCamlList<A>>> {
        if self.is_empty() {
            None
        } else {
            Some(unsafe { self.field(1) })
        }
    }

    /// Returns a tuple of the head and tail of an OCaml list.
    pub fn uncons(&self) -> Option<(OCaml<'a, A>, Self)> {
        if self.is_empty() {
            None
        } else {
            Some(unsafe { (self.field(0), self.field(1)) })
        }
    }
}

// Tuples

macro_rules! impl_tuple {
    ($($n:tt: $accessor:ident -> $t:ident),+) => {
        impl<'a, $($t),+> OCaml<'a, ($($t),+)>
        {
            pub fn to_tuple(&self) -> ($(OCaml<'a, $t>),+) {
                ($(self.$accessor()),+)
            }

            $(
                pub fn $accessor(&self) -> OCaml<'a, $t> {
                    unsafe { self.field($n) }
                }
            )+
        }
    };
}

impl_tuple!(
    0: fst -> A,
    1: snd -> B);
impl_tuple!(
    0: fst -> A,
    1: snd -> B,
    2: tuple_3 -> C);
impl_tuple!(
    0: fst -> A,
    1: snd -> B,
    2: tuple_3 -> C,
    3: tuple_4 -> D);
impl_tuple!(
    0: fst -> A,
    1: snd -> B,
    2: tuple_3 -> C,
    3: tuple_4 -> D,
    4: tuple_5 -> E);
impl_tuple!(
    0: fst -> A,
    1: snd -> B,
    2: tuple_3 -> C,
    3: tuple_4 -> D,
    4: tuple_5 -> E,
    5: tuple_6 -> F);
impl_tuple!(
    0: fst -> A,
    1: snd -> B,
    2: tuple_3 -> C,
    3: tuple_4 -> D,
    4: tuple_5 -> E,
    5: tuple_6 -> F,
    6: tuple_7 -> G);
impl_tuple!(
    0: fst -> A,
    1: snd -> B,
    2: tuple_3 -> C,
    3: tuple_4 -> D,
    4: tuple_5 -> E,
    5: tuple_6 -> F,
    6: tuple_7 -> G,
    7: tuple_8 -> H);
impl_tuple!(
    0: fst -> A,
    1: snd -> B,
    2: tuple_3 -> C,
    3: tuple_4 -> D,
    4: tuple_5 -> E,
    5: tuple_6 -> F,
    6: tuple_7 -> G,
    7: tuple_8 -> H,
    8: tuple_9 -> I);
