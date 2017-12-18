open Core_kernel

module Hash = String

module Header = struct
  type t =
    { previous_header_hash : Hash.t
    }
  [@@deriving bin_io]
end

module Body = struct
  type t = int
  [@@deriving bin_io]
end

type t =
  { header : Header.t
  ; body   : Body.t
  }
[@@deriving bin_io]
