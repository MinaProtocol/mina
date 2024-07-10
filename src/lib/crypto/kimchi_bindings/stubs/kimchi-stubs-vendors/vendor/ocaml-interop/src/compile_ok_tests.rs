// Copyright (c) Viable Systems and TezEdge Contributors
// SPDX-License-Identifier: MIT

mod test_immediate_ocamlrefs {
    // Test tests are just to confirm that AsRef for immediate OCaml values
    // (ints, bools, etc) compiles correctly without the need for rooting those
    // values.

    use crate::*;

    fn ocaml_fixnum_input(_cr: &mut OCamlRuntime, _: OCamlRef<OCamlInt>) {}
    fn ocaml_bool_input(_cr: &mut OCamlRuntime, _: OCamlRef<bool>) {}
    fn ocaml_option_input(_cr: &mut OCamlRuntime, _: OCamlRef<Option<String>>) {}
    fn ocaml_unit_input(_cr: &mut OCamlRuntime, _: OCamlRef<()>) {}

    fn test_immediate_ocamlref(cr: &mut OCamlRuntime) -> bool {
        let i: OCaml<OCamlInt> = OCaml::of_i32(10);
        let b: OCaml<bool> = OCaml::of_bool(true);
        let n: OCaml<Option<String>> = OCaml::none();
        let u: OCaml<()> = OCaml::unit();

        ocaml_fixnum_input(cr, &i);
        ocaml_bool_input(cr, &b);
        ocaml_option_input(cr, &n);
        ocaml_unit_input(cr, &u);

        true
    }

    #[test]
    fn test_immediate_ocamlrefs() {
        let mut cr = unsafe { OCamlRuntime::recover_handle() };
        assert!(test_immediate_ocamlref(&mut cr));
    }
}
