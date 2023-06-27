(* Endo coefficients *)

(** [Step_inner_curve] contains the endo coefficients used by the step proof system *)
module Step_inner_curve : sig
  val base : Backend.Tick.Field.t

  val scalar : Backend.Tock.Field.t

  val to_field :
       Import.Challenge.Constant.t Import.Scalar_challenge.t
    -> Backend.Tock.Field.t
end

(** [Wrap_inner_curve] contains the endo coefficients used by the wrap proof system *)
module Wrap_inner_curve : sig
  val base : Backend.Tock.Field.t

  val scalar : Backend.Tick.Field.t

  val to_field :
       Import.Challenge.Constant.t Import.Scalar_challenge.t
    -> Backend.Tick.Field.t
end
