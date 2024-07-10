use crate::{Char, Value};

extern "C" {
    pub fn caml_format_exception(v: Value) -> *const Char;
}
