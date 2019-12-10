open Core

module type TICK = sig
  module Field : sig
    type t [@@deriving sexp, eq, compare, hash, bin_io]

    val one : t

    module Var : sig
      type t
    end

    val gen : t Quickcheck.Generator.t
  end

  module Inner_curve : sig
    module Scalar : sig
      type t [@@deriving sexp, eq, compare, hash, bin_io]

      val one : t

      type var

      val gen : t Quickcheck.Generator.t
    end
  end
end
