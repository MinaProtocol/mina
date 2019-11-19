open Coda_base

module Stable : sig
  module V1 : sig
    type t = {state_hash: State_hash.t; frontier_hash: Frontier_hash.t}
    [@@deriving bin_io, yojson]
  end

  module Latest = V1
end

type t = Stable.Latest.t
