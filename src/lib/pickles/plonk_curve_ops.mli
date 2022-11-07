(* Undocumented *)

val add_fast :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> ?check_finite:bool
  -> 'f Snarky_backendless.Cvar.t * 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t * 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t * 'f Snarky_backendless.Cvar.t

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t) : sig
  type var := Impl.field Snarky_backendless.Cvar.t

  type pair := var Tuple_lib.Double.t

  val seal : pair -> pair

  val add_fast : ?check_finite:bool -> var * var -> var * var -> var * var

  val bits_per_chunk : int

  val chunks_needed : num_bits:int -> int

  val scale_fast_msb_bits :
    pair -> Impl.Boolean.var array Pickles_types.Shifted_value.Type1.t -> G.t

  val scale_fast_unpack :
       pair
    -> Impl.Field.t Pickles_types.Shifted_value.Type1.t
    -> num_bits:int
    -> G.t * Impl.Boolean.var array

  val scale_fast2 :
       G.t
    -> (Impl.Field.t * Impl.Boolean.var) Pickles_types.Shifted_value.Type2.t
    -> num_bits:int
    -> G.t

  val scale_fast :
       pair
    -> Impl.Field.t Pickles_types.Shifted_value.Type1.t
    -> num_bits:int
    -> G.t

  module type Scalar_field_intf = sig
    module Constant : sig
      type t

      val size_in_bits : int

      val one : t

      val of_int : int -> t

      val ( * ) : t -> t -> t

      val ( / ) : t -> t -> t

      val ( + ) : t -> t -> t

      val ( - ) : t -> t -> t

      val inv : t -> t

      val negate : t -> t

      val to_bigint : t -> Impl.Bigint.t
    end

    type t = Impl.Field.t

    val typ : (t, Constant.t) Impl.Typ.t
  end

  val scale_fast2' :
       (module Scalar_field_intf with type Constant.t = 'scalar_field)
    -> G.t
    -> Impl.Field.t
    -> num_bits:int
    -> G.t
end
