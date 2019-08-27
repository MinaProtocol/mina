open Core_kernel

module Stable = struct
  module V1 = struct
    module T = struct
      type t = {trust: float; banned: Banned_status.Stable.V1.t}
      [@@deriving bin_io, yojson, version]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t = {trust: float; banned: Banned_status.Stable.V1.t}
[@@deriving yojson]
