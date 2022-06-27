(* TODO Consider moving to a different location. as in future this won't be only about block body *)
module Tag : sig
  type t = Body [@@deriving enum]
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t [@@deriving compare, sexp, to_yojson, bin_io]
  end
end]

type t = Stable.Latest.t [@@deriving compare, sexp, to_yojson]

val create : Diff.t -> t

val staged_ledger_diff : t -> Diff.t

val compute_reference : t -> Consensus.Body_reference.t
