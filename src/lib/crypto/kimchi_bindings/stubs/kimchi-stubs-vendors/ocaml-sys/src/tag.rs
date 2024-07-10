//! Contains defintions for OCaml tags

/// Used to store OCaml value tags, which are used to determine the underlying type of values
pub type Tag = u8;

pub const FORWARD: Tag = 250;
pub const INFIX: Tag = 249;
pub const OBJECT: Tag = 248;
pub const CLOSURE: Tag = 247;
pub const LAZY: Tag = 246;
pub const ABSTRACT: Tag = 251;
pub const NO_SCAN: Tag = 251;
pub const STRING: Tag = 252;
pub const DOUBLE: Tag = 253;
pub const DOUBLE_ARRAY: Tag = 254;
pub const CUSTOM: Tag = 255;
