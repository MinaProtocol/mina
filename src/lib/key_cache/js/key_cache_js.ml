open Core_kernel
open Key_cache

module Trivial : S with module M := Or_error = struct
  include T (Or_error)

  module Disk_storable = struct
    include Disk_storable (Or_error)

    let of_binable to_string _m =
      let read _ ~path:_ =
        Or_error.error_string "Key_cache: Trivial store cannot read"
      in
      let write _k _t _path = Ok () in
      { to_string; read; write }

    let simple to_string read write =
      { to_string
      ; read = (fun k ~path -> read k ~path)
      ; write = (fun k v s -> write k v s)
      }
  end

  let read _spec { Disk_storable.to_string = _; read = _; write = _ } _k =
    Or_error.error_string "Key_cache: Trivial store cannot read"

  let write _spec { Disk_storable.to_string = _; read = _; write = _ } _k _v =
    Ok ()
end
