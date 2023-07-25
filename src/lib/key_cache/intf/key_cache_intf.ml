open Async_kernel
open Core_kernel

module Spec = struct
  type t =
    | On_disk of { directory : string; should_write : bool }
    | S3 of { bucket_prefix : string; install_path : string }
end

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
