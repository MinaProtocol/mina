open Async_kernel
open Core_kernel
include Key_cache_intf

module Sync : Sync = struct
  include T (Or_error)

  module Disk_storable = struct
    include Disk_storable (Or_error)

    let of_binable to_string _m =
      let read _ ~path:_ =
        Or_error.error_string "Key_cache: Trivial store cannot read"
      in
      let write _k _t _path = Ok () in
      { to_string; read; write }

    let simple to_string read write = { to_string; read; write }
  end

  let read _spec { Disk_storable.to_string = _; read = _; write = _ } _k =
    Or_error.error_string "Key_cache: Trivial store cannot read"

  let write _spec { Disk_storable.to_string = _; read = _; write = _ } _k _v =
    Ok ()
end

module Async : Async = struct
  include T (Deferred.Or_error)

  module Disk_storable = struct
    include Disk_storable (Deferred.Or_error)

    let of_binable to_string _m =
      let read _ ~path:_ =
        Deferred.Or_error.error_string "Key_cache: Trivial store cannot read"
      in
      let write _k _t _path = Deferred.Or_error.return () in
      { to_string; read; write }

    let simple to_string read write = { to_string; read; write }
  end

  let read _spec { Disk_storable.to_string = _; read = _; write = _ } _k =
    Deferred.Or_error.error_string "Key_cache: Trivial store cannot read"

  let write _spec { Disk_storable.to_string = _; read = _; write = _ } _k _v =
    Deferred.Or_error.return ()
end
