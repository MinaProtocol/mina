[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t [@@deriving compare, sexp, yojson]
  end
end]

type t = Stable.Latest.t [@@deriving compare, sexp, yojson]

val of_body : Body.t -> t
