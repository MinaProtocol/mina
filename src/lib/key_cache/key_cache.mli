open Core_kernel
open Async_kernel

include module type of Key_cache_intf

module Trivial : Sync

module Trivial_async : Async

(** Exposes the current synchronous implementation, which may be overridden by
    [set_sync_implementation].
*)
module Sync : S with module M := Or_error

(** Exposes the current asynchronous implementation, which may be overridden by
    [set_async_implementation].
*)
module Async : S with module M := Deferred.Or_error
