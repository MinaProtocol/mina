open! Stdune
(** Command line arguments specification *)

(** This module implements a small DSL to specify the command line
    argument of a program as well as the dependencies and targets of
    the program at the same time.

    For instance to represent the argument of [ocamlc -o src/foo.exe
    src/foo.ml], one might write:

    {[
      [ A "-o"
      ; Target (Path.relatie  dir "foo.exe")
      ; Dep    (Path.relative dir "foo.ml")
      ]
    ]}

    This DSL was inspired from the ocamlbuild API.  *)

open! Import

(** [A] stands for "atom", it is for command line arguments that are
    neither dependencies nor targets.

    [Path] is similar to [A] in the sense that it defines a command
    line argument that is neither a dependency or target. However, the
    difference between the two is that [A s] produces exactly the
    argument [s], while [Path p] produces a string that depends on
    where the command is executed. For instance [Path (Path.of_string
    "src/foo.ml")] will translate to "../src/foo.ml" if the command is
    started from the "test" directory.  *)
type 'a t =
  | A        of string
  | As       of string list
  | S        of 'a t list
  | Concat   of string * 'a t list (** Concatenation with a custom separator *)
  | Dep      of Path.t (** A path that is a dependency *)
  | Deps     of Path.t list
  | Target   of Path.t
  | Path     of Path.t
  | Paths    of Path.t list
  | Hidden_deps    of Path.t list
  | Hidden_targets of Path.t list
  (** Register dependencies but produce no argument *)
  | Dyn      of ('a -> Nothing.t t)

val add_deps    : _ t list -> Path.Set.t -> Path.Set.t
val add_targets : _ t list -> Path.t list -> Path.t list
val expand      : dir:Path.t -> 'a t list -> 'a -> string list * Path.Set.t

(** [quote_args quote args] is [As \[quote; arg1; quote; arg2; ...\]] *)
val quote_args : string -> string list -> _ t

val of_result : 'a t Or_exn.t -> 'a t
val of_result_map : 'a Or_exn.t -> f:('a -> 'b t) -> 'b t
