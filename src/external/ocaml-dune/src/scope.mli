(** Scopes *)

(** A scope is a project + a library database  *)

open! Stdune

type t

val root : t -> Path.t
val name : t -> Dune_project.Name.t
val project : t -> Dune_project.t

(** Return the library database associated to this scope *)
val libs : t -> Lib.DB.t

(** Scope databases *)
module DB : sig
  type scope = t

  type t

  (** Return the new scope database as well as the public libraries
      database *)
  val create
    :  projects:Dune_project.t list
    -> context:string
    -> installed_libs:Lib.DB.t
    -> ext_lib:string
    -> ext_obj:string
    -> (Path.t * Dune_file.Library.t) list
    -> t * Lib.DB.t

  val find_by_dir  : t -> Path.t              -> scope
  val find_by_name : t -> Dune_project.Name.t -> scope
end with type scope := t
