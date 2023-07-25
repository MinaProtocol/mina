open Core_kernel
open Async_kernel

[%%import "/src/config.mlh"]

include Key_cache_intf
module Trivial = Key_cache_dummy.Key_cache.Trivial
module Trivial_async = Key_cache_dummy.Key_cache.Trivial_async

let sync = ref (module Trivial : Sync)

let async = ref (module Trivial_async : Async)

module Sync : Sync = struct
  include T (Or_error)

  module Disk_storable = struct
    include Disk_storable (Or_error)

    let of_binable to_string binable =
      let (module M) = !sync in
      M.Disk_storable.of_binable to_string binable

    let simple to_string read write =
      let (module M) = !sync in
      M.Disk_storable.simple to_string read write
  end

  let read spec ds k =
    let (module M) = !sync in
    M.read spec ds k

  let write spec ds k v =
    let (module M) = !sync in
    M.write spec ds k v
end

module Async : Async = struct
  include T (Deferred.Or_error)

  module Disk_storable = struct
    include Disk_storable (Deferred.Or_error)

    let of_binable to_string binable =
      let (module M) = !async in
      M.Disk_storable.of_binable to_string binable

    let simple to_string read write =
      let (module M) = !async in
      M.Disk_storable.simple to_string read write
  end

  let read spec ds k =
    let (module M) = !async in
    M.read spec ds k

  let write spec ds k v =
    let (module M) = !async in
    M.write spec ds k v
end
