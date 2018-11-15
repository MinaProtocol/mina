open! Stdune

module File : sig
  type t =
    { src : Path.t
    ; dst : Path.t
    }

  (** Register a file to promote *)
  val register : t -> unit
end

(** Promote all registered files if [!Clflags.auto_promote]. Otherwise
    dump the list of registered files to [_build/.to-promote]. *)
val finalize : unit -> unit

(** Describe what files should be promoted. The second argument of
    [These] is a function that is called on files that cannot be
    promoted. *)
type files_to_promote =
  | All
  | These of Path.t list * (Path.t -> unit)

val promote_files_registered_in_last_run : files_to_promote -> unit
