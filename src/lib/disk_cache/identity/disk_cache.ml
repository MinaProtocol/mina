open Async_kernel
open Core_kernel

module Make (Data : Binable.S) = struct
  type t = unit

  type id = Data.t

  let initialize _path ~logger:_ = Deferred.Result.return ()

  let get () = ident

  let get_bin_prot () = Binable.to_bigstring (module Data)

  let put () = ident
end
