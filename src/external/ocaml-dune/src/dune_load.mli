open! Stdune

module Dune_file : sig
  type t =
    { dir     : Path.t
    ; project : Dune_project.t
    ; stanzas : Dune_file.Stanzas.t
    ; kind    : Dune_lang.Syntax.t
    }
end

module Dune_files : sig
  type t

  val eval
    :  t
    -> context:Context.t
    -> Dune_file.t list Fiber.t
end

type conf = private
  { file_tree  : File_tree.t
  ; dune_files : Dune_files.t
  ; packages   : Package.t Package.Name.Map.t
  ; projects   : Dune_project.t list
  }

val load
  :  ?extra_ignored_subtrees:Path.Set.t
  -> ?ignore_promoted_rules:bool
  -> unit
  -> conf
