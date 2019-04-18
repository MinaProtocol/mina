let to_string = function
  | `Offline -> "Offline"
  | `Bootstrap -> "Bootstrap"
  | `Synced -> "Synced"

let to_yojson status = `String (to_string status)

module Stable = struct
  module V1 = struct
    module T = struct
      type t = [`Offline | `Bootstrap | `Synced]
      [@@deriving bin_io, version, sexp]

      let to_yojson = to_yojson
    end

    include T
  end

  module Latest = V1
end

type t = [`Offline | `Bootstrap | `Synced] [@@deriving sexp]
