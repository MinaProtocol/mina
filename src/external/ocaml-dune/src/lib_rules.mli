open! Stdune
open Dune_file

module Gen (S : sig val sctx : Super_context.t end) : sig

  module Odoc : sig
    val init : unit -> unit
    val gen_rules : dir:Path.t -> string list -> unit
  end

  val rules
    : Library.t
    -> dir_contents:Dir_contents.t
    -> dir:Path.t
    -> scope:Scope.t
    -> dir_kind:Dune_lang.syntax
    -> Compilation_context.t * Merlin.t
end
