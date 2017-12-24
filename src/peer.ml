open Core_kernel

type t =
  { ip         : Host_and_port.t
  ; public_key : Public_key.t
  }
[@@deriving sexp, bin_io]

module Event = struct
  type t =
    | Connect of t list
    | Disconnect of t list
end
