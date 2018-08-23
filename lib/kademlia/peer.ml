open Core_kernel

module T = struct
  type t = Host_and_port.Stable.V1.t * int
  [@@deriving bin_io, sexp, compare, hash]

  let external_rpc t =
    Host_and_port.create ~host:(Host_and_port.host (fst t)) ~port:(snd t)
end

include T
include Hashable.Make (T)

module Event = struct
  type nonrec t = Connect of t list | Disconnect of t list [@@deriving sexp]
end
