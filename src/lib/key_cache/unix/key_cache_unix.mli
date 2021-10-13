open Core_kernel
open Key_cache

val set_downloads_enabled : bool -> unit

module Sync : S with module M := Or_error

module Async : S with module M := Async_kernel.Deferred.Or_error
