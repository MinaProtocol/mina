use crate::{Char, Value};

extern "C" {
    pub fn caml_raise(bucket: Value);
    pub fn caml_raise_constant(tag: Value);
    pub fn caml_raise_with_arg(tag: Value, arg: Value);
    pub fn caml_raise_with_args(tag: Value, nargs: i32, arg: *mut Value);
    pub fn caml_raise_with_string(tag: Value, msg: *const Char);
    pub fn caml_failwith(msg: *const Char);
    pub fn caml_failwith_value(msg: Value);
    pub fn caml_invalid_argument(msg: *const Char);
    pub fn caml_invalid_argument_value(msg: Value);
    pub fn caml_raise_out_of_memory();
    pub fn caml_raise_stack_overflow();
    pub fn caml_raise_sys_error(arg1: Value);
    pub fn caml_raise_end_of_file();
    pub fn caml_raise_zero_divide();
    pub fn caml_raise_not_found();
    pub fn caml_array_bound_error();
    pub fn caml_raise_sys_blocked_io();
}
