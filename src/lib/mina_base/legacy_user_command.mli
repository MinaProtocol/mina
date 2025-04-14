type t = User_command.t [@@deriving yojson]

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t = User_command.Stable.V2.t [@@deriving sexp, yojson]

    val to_latest : t -> t
  end
end]
