open Core_kernel
open Async_kernel

module Spec : sig
  type t =
    | On_disk of { directory : string; should_write : bool }
    | S3 of { bucket_prefix : string; install_path : string }
end

val may_download : unit -> bool

val set_downloads_enabled : bool -> unit

module T (M : sig
  type _ t
end) : sig
  type ('a, 'b) t = { write : 'a -> 'b -> unit M.t; read : 'a -> 'b M.t }
end

(** Represents a type that can be cached, and serialized/deserialized from disk. *)
module Disk_storable (M : sig
  type _ t
end) : sig
  type ('k, 'v) t =
    { to_string : 'k -> string
    ; read : 'k -> path:string -> 'v M.t
    ; write : 'k -> 'v -> string -> unit M.t
    }
end

module type S = sig
  module M : sig
    type _ t
  end

  type ('a, 'b) t = ('a, 'b) T(M).t =
    { write : 'a -> 'b -> unit M.t; read : 'a -> 'b M.t }

  module Disk_storable : sig
    type ('k, 'v) t = ('k, 'v) Disk_storable(M).t =
      { to_string : 'k -> string
      ; read : 'k -> path:string -> 'v M.t
      ; write : 'k -> 'v -> string -> unit M.t
      }

    val of_binable :
      ('k -> string) -> (module Binable.S with type t = 'v) -> ('k, 'v) t

    val simple :
         ('k -> string)
      -> ('k -> path:string -> 'v M.t)
      -> ('k -> 'v -> string -> unit M.t)
      -> ('k, 'v) t
  end

  val read :
       Spec.t list
    -> ('k, 'v) Disk_storable.t
    -> 'k
    -> ('v * [> `Cache_hit | `Locally_generated ]) M.t

  val write : Spec.t list -> ('k, 'v) Disk_storable.t -> 'k -> 'v -> unit M.t
end

module type Sync = S with module M := Or_error

module type Async = S with module M := Deferred.Or_error

module Trivial : Sync

module Trivial_async : Async

(** Update the implementation used for [Sync]. Defaults to [Trivial]. *)
val set_sync_implementation : (module Sync) -> unit

(** Update the implementation used for [Async]. Defaults to [Trivial_async]. *)
val set_async_implementation : (module Async) -> unit

(** Exposes the current synchronous implementation, which may be overridden by
    [set_sync_implementation].
*)
module Sync : S with module M := Or_error

(** Exposes the current asynchronous implementation, which may be overridden by
    [set_async_implementation].
*)
module Async : S with module M := Deferred.Or_error
