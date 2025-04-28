module Constant : sig
  type t = Impls.Step.unfinalized_proof

  (* val shift : Backend.Tock.Field.t Pickles_types.Shifted_value.Type2.Shift.t *)

  val dummy : t Lazy.t
end

type t = Impls.Step.unfinalized_proof_var

val typ : wrap_rounds:'a -> (t, Constant.t) Impls.Step.Typ.t

val dummy : unit -> t
