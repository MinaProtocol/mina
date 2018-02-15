open Snark_params

type t = Tick.Proof.t

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io]
  end
end
