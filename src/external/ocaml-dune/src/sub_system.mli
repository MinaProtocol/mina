(** Dune sub-systems *)

(** This module allows to define sub-systems. The aim is to define
    everything related to the sub-system, such as the parser for jbuild
    files, the metadata attached to libraries and the specific rules in
    one place.

    A sub-system is generally split into two sub-systems:

    - a backend part, which will be used by libraries that provide an
      implementation of the sub-system
    - an end point, for users of the sub-system

    For instance, for inline tests, the backend is what defines the inline
    tests framework. "ppx_inline_test" and "qtest" are examples of backends.
    An end point is any library that contains inline tests.
*)

open! Import

include module type of struct include Sub_system_intf end

(** Register a sub-system backend:
    - connect the parser to the jbuild files parser
    - connect the metatada generator [M.to_sexp] so that metadata are
      included in installed [<lib>.dune] files
*)
module Register_backend(M : Backend) : Registered_backend with type t := M.t

(** Register a sub-system backend:
    - connect the parser to the jbuild files parser
    - connect the rule generator to the rule generator for libraries
*)
module Register_end_point(M : End_point) : sig end

(** Scan the sub-systems used by the library and generate rules for
    all of the ones that needs it. *)
val gen_rules : Library_compilation_context.t -> unit
