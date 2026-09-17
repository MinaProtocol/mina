//! MiniMina library surface.
//!
//! Exposes the pure, reusable pieces of minimina as a library target (in
//! addition to the `minimina` binary defined in `main.rs`). Keeping these in a
//! library lets their doc examples run as doctests under `cargo test`.

pub mod amounts;
