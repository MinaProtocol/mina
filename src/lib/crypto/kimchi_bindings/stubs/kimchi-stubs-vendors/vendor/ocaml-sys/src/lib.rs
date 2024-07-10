#![allow(clippy::missing_safety_doc)]
#![allow(clippy::upper_case_acronyms)]
#![no_std]

pub type Char = cty::c_char;

#[cfg(not(feature = "without-ocamlopt"))]
pub const VERSION: &str = include_str!(concat!(env!("OUT_DIR"), "/ocaml_version"));

#[cfg(feature = "without-ocamlopt")]
pub const VERSION: &str = "";

#[cfg(not(feature = "without-ocamlopt"))]
pub const PATH: &str = include_str!(concat!(env!("OUT_DIR"), "/ocaml_path"));

#[cfg(feature = "without-ocamlopt")]
pub const PATH: &str = "";

#[cfg(not(feature = "without-ocamlopt"))]
pub const COMPILER: &str = include_str!(concat!(env!("OUT_DIR"), "/ocaml_compiler"));

#[cfg(feature = "without-ocamlopt")]
pub const COMPILER: &str = "";

mod mlvalues;
#[macro_use]
mod memory;
mod alloc;
pub mod bigarray;
mod callback;
mod custom;
mod fail;
mod printexc;
mod runtime;
mod state;
mod tag;

pub use self::mlvalues::Value;
pub use self::tag::Tag;
pub use alloc::*;
pub use callback::*;
pub use custom::*;
pub use fail::*;
pub use memory::*;
pub use mlvalues::*;
pub use printexc::*;
pub use runtime::*;
pub use state::*;
pub use tag::*;
