(** META file parsing/printing *)

open! Stdune
open! Import

type t =
  { name    : Lib_name.t option
  ; entries : entry list
  }

and entry =
  | Comment of string
  | Rule    of rule
  | Package of t

and rule =
  { var        : string
  ; predicates : predicate list
  ; action     : action
  ; value      : string
  }

and action = Set | Add

and predicate =
  | Pos of string
  | Neg of string

module Simplified : sig
  module Rules : sig
    type t =
      { set_rules : rule list
      ; add_rules : rule list
      }
  end

  type t =
    { name : Lib_name.t option
    ; vars : Rules.t String.Map.t
    ; subs : t list
    }

  val pp : Format.formatter -> t -> unit
end

val load : Path.t -> name:Lib_name.t option -> Simplified.t

(** Builtin META files for libraries distributed with the compiler. For when ocamlfind is
    not installed. *)
val builtins : stdlib_dir:Path.t -> version:Ocaml_version.t -> Simplified.t Lib_name.Map.t

val pp : Format.formatter -> entry list -> unit
