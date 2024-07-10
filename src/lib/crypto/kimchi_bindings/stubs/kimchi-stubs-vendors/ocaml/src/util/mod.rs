#[cfg(feature = "no-std")]
pub use cstr_core::CString;

#[cfg(not(feature = "no-std"))]
pub use std::ffi::CString;
