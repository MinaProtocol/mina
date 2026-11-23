(** Work that is running, so that whoever stops it can wait for it to
    finish. *)

open Async_kernel

type t

val create : unit -> t

(** Run [f], counting it as in flight until its result is determined or it
    raises. *)
val run : t -> (unit -> 'a Deferred.t) -> 'a Deferred.t

(** Determined once no work is in flight. Work started before then is waited
    for too. *)
val idle : t -> unit Deferred.t
