let to_string = function
  | `Offline -> "Offline"
  | `Bootstrap -> "Bootstrap"
  | `Synced -> "Synced"

module Stable = struct
  module V1 = struct
    module T = struct
      type t = [`Offline | `Bootstrap | `Synced]
      [@@deriving bin_io, version, sexp, to_yojson]
    end

    include T
  end

  module Latest = V1
end

type t = [`Offline | `Bootstrap | `Synced] [@@deriving sexp, to_yojson]
