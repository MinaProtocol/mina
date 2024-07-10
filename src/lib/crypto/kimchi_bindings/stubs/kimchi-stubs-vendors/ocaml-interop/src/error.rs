// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

use crate::mlvalues::{is_block, string_val, tag_val, RawOCaml};
use crate::mlvalues::{tag, MAX_FIXNUM, MIN_FIXNUM};
use core::{fmt, slice};
use ocaml_sys::caml_string_length;

/// An OCaml exception value.
#[derive(Debug)]
pub struct OCamlException {
    raw: RawOCaml,
}

#[derive(Debug)]
pub enum OCamlFixnumConversionError {
    InputTooBig(i64),
    InputTooSmall(i64),
}

impl fmt::Display for OCamlFixnumConversionError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            OCamlFixnumConversionError::InputTooBig(n) => write!(
                f,
                "Input value doesn't fit in OCaml fixnum n={} > MAX_FIXNUM={}",
                n, MAX_FIXNUM
            ),
            OCamlFixnumConversionError::InputTooSmall(n) => write!(
                f,
                "Input value doesn't fit in OCaml fixnum n={} < MIN_FIXNUM={}",
                n, MIN_FIXNUM
            ),
        }
    }
}

impl OCamlException {
    #[doc(hidden)]
    pub unsafe fn of(raw: RawOCaml) -> Self {
        OCamlException { raw }
    }

    pub fn message(&self) -> Option<String> {
        if is_block(self.raw) {
            unsafe {
                let message = *(self.raw as *const RawOCaml).add(1);

                if is_block(message) && tag_val(message) == tag::STRING {
                    let error_message =
                        slice::from_raw_parts(string_val(message), caml_string_length(message))
                            .to_owned();
                    let error_message = String::from_utf8_unchecked(error_message);
                    Some(error_message)
                } else {
                    None
                }
            }
        } else {
            None
        }
    }
}
