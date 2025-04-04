(* Implementation of the algorithm described on page 29 of the Halo paper
   https://eprint.iacr.org/2019/1021.pdf
*)

val to_field_constant :
     endo:'f
  -> (module Plonk_checks.Field_intf with type t = 'f)
  -> Import.Challenge.Constant.t Import.Scalar_challenge.t
  -> 'f

(** [to_field_checked' ?num_bits backend chal] builds a circuit using the gate
    [Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.(T
    EC_endoscalar)] to decompose into [num_bits] bits a scalar challenge [chal].

    The default value of [num_bits] is 128, and the gadget requires 8 rows.
*)
val to_field_checked' :
     ?num_bits:int
  -> (module Kimchi_pasta_snarky_backend.Snark_intf with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t Import.Scalar_challenge.t
  -> 'f Snarky_backendless.Cvar.t
     * 'f Snarky_backendless.Cvar.t
     * 'f Snarky_backendless.Cvar.t

val to_field_checked :
     ?num_bits:int
  -> (module Kimchi_pasta_snarky_backend.Snark_intf with type field = 'f)
  -> endo:'f
  -> 'f Snarky_backendless.Cvar.t Import.Scalar_challenge.t
  -> 'f Snarky_backendless.Cvar.t

module Make : functor
  (Impl : Kimchi_pasta_snarky_backend.Snark_intf)
  (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t)
  (Challenge : Import.Challenge.S with module Impl := Impl)
  (_ : sig
     val base : Impl.Field.Constant.t

     val scalar : G.Constant.Scalar.t
   end)
  -> sig
  type t = Challenge.t Import.Scalar_challenge.t

  module Constant : sig
    type t = Challenge.Constant.t Import.Scalar_challenge.t

    val to_field :
         (Core_kernel.Int64.t, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
         Import.Scalar_challenge.t
      -> G.Constant.Scalar.t
  end

  val typ : (t, Constant.t) Impl.Typ.t

  val num_bits : int

  val seal : Impl.Field.t -> Impl.Field.t

  val endo :
       ?num_bits:int
    -> Impl.Field.t Tuple_lib.Double.t
    -> Impl.Field.t Import.Scalar_challenge.t
    -> G.t

  val endo_inv : Impl.Field.t * Impl.Field.t -> t -> G.t
end
