(* Domains *)

module Stable : sig
  module V2 : sig
    type t = { h : Domain.Stable.V1.t }
    [@@deriving fields, sexp, compare, yojson]
  end

  module Latest = V2
end

type t = Stable.Latest.t = { h : Domain.Stable.V1.t }
[@@deriving fields, sexp, compare, yojson]
