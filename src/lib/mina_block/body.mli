[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t [@@deriving compare, sexp, to_yojson]
  end
end]

type t = Stable.Latest.t [@@deriving compare, sexp, to_yojson]

val create : Staged_ledger_diff.t -> t

val staged_ledger_diff : t -> Staged_ledger_diff.t
