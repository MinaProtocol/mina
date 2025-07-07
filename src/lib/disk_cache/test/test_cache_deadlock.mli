open Async

module type Cache_intf = sig
  module Make : Disk_cache_intf.F
end

val test_cache_deadlock : (module Cache_intf) -> unit Deferred.t
