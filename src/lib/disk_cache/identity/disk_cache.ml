open Async_kernel
open Core

module Make (Data : sig
  type t
end) =
struct
  type t = unit

  type id = Data.t

  let initialize _path ~logger:_ = Deferred.Result.return ()

  let get () = Fn.id

  let put () = Fn.id
end
