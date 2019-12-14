module type Tick_S = sig
  module Field : sig
    type t [@@deriving sexp, eq, compare, hash]

    val one : t

    module Var : sig
      type t
    end
  end

  module Inner_curve : sig
    module Scalar : sig
      type t [@@deriving sexp, eq, compare, hash]

      val one : t

      type var
    end
  end
end
