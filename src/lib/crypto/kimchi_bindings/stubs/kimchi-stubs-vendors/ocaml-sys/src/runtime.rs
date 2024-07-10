use crate::{Char, Value};

extern "C" {
    pub fn caml_main(argv: *const *const Char);
    pub fn caml_startup(argv: *const *const Char);
    pub fn caml_shutdown();
    pub fn caml_named_value(name: *const Char) -> *const Value;
}

// GC control
extern "C" {
    pub fn caml_gc_minor(v: Value);
    pub fn caml_gc_major(v: Value);
    pub fn caml_gc_full_major(v: Value);
    pub fn caml_gc_compaction(v: Value);
}
