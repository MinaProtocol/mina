open Snark_params

type t = Tock.Proof.t [@@deriving equal, sexp, yojson]

val dummy : Tock.Proof.t

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving bin_io, equal, sexp, version, yojson]
  end
end
