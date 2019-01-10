open Core
open Async

(** This module is used to transfer the currently running executable to a remote server *)
type 'a t

(** [existing_on_host ~executable_path ?strict_host_key_checking host] will create a [t]
    from the supplied host and path. The executable MUST be the exact same executable that
    will be run in the master process. There will be a check for this in [spawn_worker].
    Use [strict_host_key_checking] to change the StrictHostKeyChecking option used when
    sshing into this host *)
val existing_on_host
  :  executable_path:string
  -> ?strict_host_key_checking:[`No | `Ask | `Yes]
  -> string
  -> [`Undeletable] t

(** [copy_to_host ~executable_dir ?strict_host_key_checking host] will copy the currently
    running executable to the desired host and path. It will keep the same name but add a
    suffix .XXXXXXXX. Use [strict_host_key_checking] to change the StrictHostKeyChecking
    option used when sshing into this host *)
val copy_to_host
  :  executable_dir:string
  -> ?strict_host_key_checking:[`No | `Ask | `Yes]
  -> string
  -> [`Deletable] t Or_error.t Deferred.t

(** [delete t] will delete a remote executable that was copied over by a previous call to
    [copy_to_host] *)
val delete : [`Deletable] t -> unit Or_error.t Deferred.t

(** Get the underlying path, host, and host_key_checking *)
val path : _ t -> string
val host : _ t -> string
val host_key_checking : _ t -> string list

(** Run the executable remotely with the given environment and arguments. This checks to
    make sure [t] matches the currently running executable that [run] is called from. *)
val run
  :  _ t
  -> env:(string * string) list
  -> args:string list
  -> Process.t Or_error.t Deferred.t
