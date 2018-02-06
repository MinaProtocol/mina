open Core_kernel

module T = struct 
  type t = Host_and_port.Stable.V1.t [@@deriving bin_io, sexp, compare, hash]
end

include T 
include Hashable.Make(T)

module Event = struct
  type nonrec t =
    | Connect of t list
    | Disconnect of t list
end
