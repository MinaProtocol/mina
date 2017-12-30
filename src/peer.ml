open Core_kernel

type t = Host_and_port.t [@@deriving bin_io, sexp, compare]

module Event = struct
  type nonrec t =
    | Connect of t list
    | Disconnect of t list
end
