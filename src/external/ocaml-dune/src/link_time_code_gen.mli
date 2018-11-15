(** {1 Handle link time code generation} *)

open Stdune

val libraries_link
  :  name:string
  -> loc:Loc.t
  -> mode:Mode.t
  -> Compilation_context.t
  -> Lib.L.t
  -> _ Arg_spec.t
(** Insert link time generated code for findlib_dynload in the list *)
