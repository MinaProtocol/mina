// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

// Check that OCaml<T> values are not accessible after an allocation.
// Must fail with:
// error[E0499]: cannot borrow `*cr` as mutable more than once at a time
/// ```compile_fail
/// # use ocaml_interop::*;
/// # let cr = &mut OCamlRuntime::init();
/// let arg1: OCaml<String> = "test".to_owned().to_ocaml(cr);
/// let arg2: OCaml<String> = "test".to_owned().to_ocaml(cr);
/// let arg1_rust: String = arg1.to_rust();
/// # ()
/// ```
pub struct LivenessFailureCheck;

// Checks that OCamlRef values made from non-immediate OCaml values cannot be used
// as if they were references to rooted values.
// Must fail with:
// error[E0499]: cannot borrow `*cr` as mutable more than once at a time
/// ```compile_fail
/// # use ocaml_interop::*;
/// # ocaml! { fn ocaml_function(arg1: String) -> String; }
/// # fn test(cr: &'static mut OCamlRuntime) {
/// let arg1: OCaml<String> = "test".to_ocaml(cr);
/// let _ = ocaml_function(cr, &arg1);
/// }
/// ```
pub struct NoStaticDerefsForNonImmediates;
