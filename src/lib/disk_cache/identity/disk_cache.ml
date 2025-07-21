open Async_kernel
open Core_kernel

module Make (Data : sig
  type t
end) =
struct
  type t = unit

  type persistence = unit [@@deriving bin_io_unversioned]

  type id = Data.t

  let initialize _path ~logger:_ ?persistence:_ () = Deferred.Result.return ()

  let get () = ident

  let put () = ident

  let freeze_eviction () = ()
end
