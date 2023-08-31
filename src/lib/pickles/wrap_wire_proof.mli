(** Restricted version of the wrap proof, to ensure that disabled features
    aren't used.
*)

open Core_kernel
open Pickles_types
module Columns = Nat.N15
module Columns_vec = Vector.Vector_15
module Coefficients = Nat.N15
module Coefficients_vec = Vector.Vector_15
module Quotient_polynomial = Nat.N7
module Quotient_polynomial_vec = Vector.Vector_7
module Permuts_minus_1 = Nat.N6
module Permuts_minus_1_vec = Vector.Vector_6

module Commitments : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
            Mina_wire_types.Pickles.Concrete_.Wrap_wire_proof.Commitments.V1.t =
        { w_comm :
            (Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t)
            Columns_vec.Stable.V1.t
        ; z_comm :
            Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t
        ; t_comm :
            (Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t)
            Quotient_polynomial_vec.Stable.V1.t
        }
      [@@deriving compare, sexp, yojson, hash, equal]
    end
  end]

  val to_kimchi : t -> Backend.Tock.Curve.Affine.t Plonk_types.Messages.t

  val of_kimchi : Backend.Tock.Curve.Affine.t Plonk_types.Messages.t -> t
end

module Evaluations : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
            Mina_wire_types.Pickles.Concrete_.Wrap_wire_proof.Evaluations.V1.t =
        { w :
            (Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t)
            Columns_vec.Stable.V1.t
        ; coefficients :
            (Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t)
            Columns_vec.Stable.V1.t
        ; z : Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; s :
            (Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t)
            Permuts_minus_1_vec.Stable.V1.t
        ; generic_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; poseidon_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; complete_add_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; mul_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; emul_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; endomul_scalar_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        }
      [@@deriving compare, sexp, yojson, hash, equal]
    end
  end]

  val to_kimchi :
       t
    -> (Backend.Tock.Field.t array * Backend.Tock.Field.t array)
       Plonk_types.Evals.t

  val of_kimchi :
       (Backend.Tock.Field.t array * Backend.Tock.Field.t array)
       Plonk_types.Evals.t
    -> t
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Mina_wire_types.Pickles.Concrete_.Wrap_wire_proof.V1.t =
      { commitments : Commitments.Stable.V1.t
      ; evaluations : Evaluations.Stable.V1.t
      ; ft_eval1 : Backend.Tock.Field.Stable.V1.t
      ; bulletproof :
          ( Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t
          , Backend.Tock.Field.Stable.V1.t )
          Plonk_types.Openings.Bulletproof.Stable.V1.t
      }
    [@@deriving compare, sexp, yojson, hash, equal]
  end
end]

val to_kimchi_proof : t -> Backend.Tock.Proof.t

val of_kimchi_proof : Backend.Tock.Proof.t -> t
