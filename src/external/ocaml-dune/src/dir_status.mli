open Stdune

type t =
  | Standalone of
      (File_tree.Dir.t * Super_context.Dir_with_dune.t option) option
  (* Directory not part of a multi-directory group. The argument is
     [None] for directory that are not from the source tree, such as
     generated ones. *)

  | Group_root of File_tree.Dir.t
                  * Super_context.Dir_with_dune.t
  (* Directory with [(include_subdirs x)] where [x] is not [no] *)

  | Is_component_of_a_group_but_not_the_root of
      Super_context.Dir_with_dune.t option
  (* Sub-directory of a [Group_root _] *)

val get : Super_context.t -> dir:Path.t -> t

val get_assuming_parent_is_part_of_group
  :  Super_context.t
  -> dir:Path.t
  -> File_tree.Dir.t
  -> t

val clear_cache : unit -> unit
