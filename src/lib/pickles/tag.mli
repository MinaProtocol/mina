(** A globally-unique identifier tag to look up the data for a collection of
    inductive rules. Used to declare dependencies between families of rules.
*)

open Core_kernel

(* NOTE: For Type_equal.Id, see:
   https://ocaml.janestreet.com/ocaml-core/v0.13/doc/base/Base__Type_equal/Id/index.html
   Most notably, 2 calls to Id.create will create 2 different identifiers, even
   if the type associated are the same.
*)

type ('var, 'value, 'n1, 'n2) id = ('var * 'value * 'n1 * 'n2) Type_equal.Id.t

type kind = Side_loaded | Compiled

(** Base type *)
type ('var, 'value, 'n1, 'n2) t = private
  { kind : kind; id : ('var, 'value, 'n1, 'n2) id }
[@@deriving fields]

(** [create ?kind name] creates a tag with kind [kind] and id derived from
    [name].

    @param kind defaults to {!Compiled}
 *)
val create : ?kind:kind -> string -> ('var, 'value, 'n1, 'n2) t
