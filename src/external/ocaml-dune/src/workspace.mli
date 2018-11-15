(** Workspaces definitions *)

open! Stdune
open! Import

module Context : sig
  module Target : sig
    type t =
      | Native
      | Named of string
  end
  module Common : sig
    type t =
      { loc       : Loc.t
      ; profile   : string
      ; targets   : Target.t list
      ; env       : Dune_env.Stanza.t option
      ; toolchain : string option
      }
  end
  module Opam : sig
    type t =
      { base    : Common.t
      ; name    : string
      ; switch  : string
      ; root    : string option
      ; merlin  : bool
      }
  end

  module Default : sig
    type t = Common.t
  end

  type t = Default of Default.t | Opam of Opam.t

  val name : t -> string
end

type t =
  { merlin_context : string option
  ; contexts       : Context.t list
  ; env            : Dune_env.Stanza.t option
  }

val load : ?x:string -> ?profile:string -> Path.t -> t

(** Default name of workspace files *)
val filename : string

(** Default configuration *)
val default : ?x:string -> ?profile:string -> unit -> t
