open Core
open Tick_intf

module Make (Tick : TICK) : sig
  module Stable : sig
    module V1 : sig
      type t = Tick.Field.t * Tick.Inner_curve.Scalar.t
      [@@deriving sexp, eq, bin_io, compare, hash, version]

      include Codable.S with type t := t
    end

    module Latest = V1
  end

  type t = Tick.Field.t * Tick.Inner_curve.Scalar.t
  [@@deriving sexp, eq, compare, hash]

  include Codable.S with type t := t

  type var = Tick.Field.Var.t * Tick.Inner_curve.Scalar.var

  include Codable.Base58_check_base_intf with type t := t

  val dummy : t
end
