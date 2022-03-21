[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t [@@deriving sexp]
  end
end]

type t = Stable.Latest.t [@@deriving compare, sexp, to_yojson]

val decompose : t -> Mina_block.t

val compose : Mina_block.t -> t

module Validated : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t [@@deriving sexp, to_yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  val lift : Mina_block.Validated.t -> t

  val lower : t -> Mina_block.Validated.t
end
