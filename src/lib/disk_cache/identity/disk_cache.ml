open Async_kernel
open Core_kernel

module Make (Data : sig
  type t [@@deriving bin_io]
end) =
struct
  type t = unit

  type id = Data.t [@@deriving bin_io_unversioned]

  let initialize _path ~logger:_ ?disk_meta_location:_ () =
    Deferred.Result.return ()

  let get () = ident

  let put () = ident
end
