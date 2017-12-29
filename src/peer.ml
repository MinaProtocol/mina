open Core

type t =
  { ip         : Host_and_port.t
  ; public_key : Public_key.t
  }
[@@deriving sexp]

module Event = struct
  type t =
    | Connect of t list
    | Disconnect of t list
end
