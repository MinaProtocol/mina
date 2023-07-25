open Core_kernel
open Async_kernel

include module type of Key_cache_intf

(** The synchronous implementation. *)
module Sync : S with module M := Or_error

(** The asynchronous implementation. *)
module Async : S with module M := Deferred.Or_error
