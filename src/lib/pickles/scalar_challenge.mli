(* Implementation of the algorithm described on page 29 of the Halo paper
   https://eprint.iacr.org/2019/1021.pdf
*)

val to_field_constant :
     endo:'f
  -> (module Plonk_checks.Field_intf with type t = 'f)
  -> Import.Challenge.Constant.t Import.Scalar_challenge.t
  -> 'f

val to_field_checked' :
     ?num_bits:int
  -> 'f Snarky_backendless.Snark.m
  -> 'f Snarky_backendless.Cvar.t Import.Scalar_challenge.t
  -> 'f Snarky_backendless.Cvar.t
     * 'f Snarky_backendless.Cvar.t
     * 'f Snarky_backendless.Cvar.t

val to_field_checked :
     ?num_bits:int
  -> 'f Snarky_backendless.Snark.m
  -> endo:'f
  -> 'f Snarky_backendless.Cvar.t Import.Scalar_challenge.t
  -> 'f Snarky_backendless.Cvar.t

val test : 'f Import.Spec.impl -> endo:'f -> unit

module Make : functor
  (Impl : Snarky_backendless.Snark_intf.Run_with_cvar)
  (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t)
  (Challenge : Import.Challenge.S with module Impl := Impl)
  (Endo : sig
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

  val seal :
    Impl.field Snarky_backendless.Cvar.t -> Impl.field Snarky_backendless.Cvar.t

  val endo :
       ?num_bits:int
    -> Impl.field Snarky_backendless.Cvar.t Tuple_lib.Double.t
    -> Impl.Field.t Import.Scalar_challenge.t
    -> G.t

  val endo_inv : Impl.Field.t * Impl.Field.t -> t -> G.t
end
