(* manual_bin_io.ml -- deriver and transformer to complement syntax
   enforcement

   For some versioned types, we don't use `deriving bin_io`, instead
   we use one of the `Binable.Of...` functors to generate the `bin_io`
   function.

   The syntax enforcement mechanism looks for `version` and `bin_io`
   to appear together in a versioned type, so the use of those
   functors breaks this setup.

   Instead, we can write `deriving manual_bin_io`. The syntax enforce
   accepts that in place of `deriving bin_io`, and creates an
   obligation that there will be the code `include Binable.Of...` in
   the module containing that type.

   Because we have `deriving version`, we know the type is named `t`.
   The use of a `Binable.Of...` functor does not guarantee that the
   bin_io functions created are for `t`, though.

   But we can enforce that those functions exist by generating the
   definitions:

     let bin_reader_t = bin_reader_t let bin_writer_t = bin_writer_t

   and so on, for all the items in `Binable.t`.

   There are two pieces here, the deriver, which generates no
   new_code, and the transformer. We can't use the deriver to produce
   the new definitions, because they need to go at the end of the
   current structure, and not immediately past the `deriving`
   attribute.

*)

open Ppxlib

let name = "manual_bin_io"

let generate_bin_io_funs str = str

let ty_decls_to_empty_structure ~options:_ ~path:_ _ty_decls = []

let () =
  Ppx_deriving.(
    register (create name ~type_decl_str:ty_decls_to_empty_structure ()))

let () = Driver.register_transformation name ~impl:generate_bin_io_funs
