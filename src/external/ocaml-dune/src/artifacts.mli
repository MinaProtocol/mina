open! Stdune
open! Import

type t

val create
  :  Context.t
  -> public_libs:Lib.DB.t
  -> build_system:Build_system.t
  -> t

(** A named artifact that is looked up in the PATH if not found in the tree
    If the name is an absolute path, it is used as it.
*)
val binary
  :  t
  -> ?hint:string
  -> loc:Loc.t option
  -> string
  -> Action.Prog.t

val add_binaries : t -> dir:Path.t -> string File_bindings.t -> t

(** [file_of_lib t ~from ~lib ~file] returns the path to a file in the
    directory of the given library. *)
val file_of_lib
  :  t
  -> loc:Loc.t
  -> lib:Lib_name.t
  -> file:string
  -> (Path.t, fail) result
