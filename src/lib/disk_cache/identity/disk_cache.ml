open Async_kernel
open Core_kernel

module Make (Data : sig
  type t
end) =
struct
  type t = unit

  type id = Data.t

  let initialize _path ~logger:_ = Deferred.Result.return ()

  let get () = ident

  let put () = ident
end
