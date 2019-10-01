module Stable : sig
  module V1 : sig
    type t [@@deriving bin_io, yojson, version]
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving eq, yojson]

type transition = {source: t; target: t}

val empty : t

val to_string : t -> string

val merge_diff : t -> 'mutant Diff.Lite.t -> 'mutant -> t
