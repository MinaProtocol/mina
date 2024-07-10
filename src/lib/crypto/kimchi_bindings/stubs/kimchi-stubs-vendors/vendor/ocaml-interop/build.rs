// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

const OCAML_INTEROP_NO_CAML_STARTUP: &str = "OCAML_INTEROP_NO_CAML_STARTUP";

fn main() {
    println!(
        "cargo:rerun-if-env-changed={}",
        OCAML_INTEROP_NO_CAML_STARTUP
    );
    if std::env::var(OCAML_INTEROP_NO_CAML_STARTUP).is_ok() {
        println!("cargo:rustc-cfg=feature=\"no-caml-startup\"");
    }
}
