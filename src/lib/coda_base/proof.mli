open Snark_params

type t = Tock.Proof.t [@@deriving sexp, yojson]

val dummy : Tock.Proof.t

[%%versioned:
module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving compare, sexp, yojson]
  end
end]
