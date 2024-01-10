open Core_kernel
open Async_kernel

[%%import "/src/config.mlh"]

module Spec = struct
  type t =
    | On_disk of { directory : string; should_write : bool }
    | S3 of { bucket_prefix : string; install_path : string }
end

[%%inject "may_download", download_snark_keys]

let may_download = ref may_download

let set_downloads_enabled b = may_download := b

let may_download () = !may_download

module T (M : sig
  type _ t
end) =
struct
  type ('a, 'b) t = { write : 'a -> 'b -> unit M.t; read : 'a -> 'b M.t }
end

module Disk_storable (M : sig
  type _ t
end) =
struct
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

module Trivial : Sync = struct
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

module Trivial_async : Async = struct
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

let sync = ref (module Trivial : Sync)

let async = ref (module Trivial_async : Async)

let set_sync_implementation x = sync := x

let set_async_implementation x = async := x

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
