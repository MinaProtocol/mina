open Core_kernel
open Async_kernel

include module type of Key_cache_intf

val may_download : unit -> bool

val set_downloads_enabled : bool -> unit

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
