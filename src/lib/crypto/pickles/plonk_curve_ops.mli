module Make_add (Impl : Kimchi_pasta_snarky_backend.Snark_intf) : sig
  type pair := Impl.Field.t Tuple_lib.Double.t

  val seal : pair -> pair

  val add_fast : ?check_finite:bool -> pair -> pair -> pair
end

module Make
    (Impl : Kimchi_pasta_snarky_backend.Snark_intf)
    (G : Intf.Group(Impl).S with type t = Impl.Field.t * Impl.Field.t) : sig
  type pair := Impl.Field.t Tuple_lib.Double.t

  val seal : pair -> pair

  val add_fast : ?check_finite:bool -> pair -> pair -> pair

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

  (** Interface for the scalar field of the curve *)
  module type Scalar_field_intf = sig
    module Constant : sig
      (** Represents an element of the field *)
      type t

      (** The number of bits in the field's order, i.e.
          [1 + log2(field_order)] *)
      val size_in_bits : int

      (** The identity element for the addition *)
      val zero : t

      (** The identity element for the multiplication *)
      val one : t

      (** [of_int x] builds an element of type [t]. [x] is supposed to be the
          canonical representation of the field element.
      *)
      val of_int : int -> t

      (** [a * b] returns the unique value [c] such that [a * b = c mod p] where
          [p] is the order of the field *)
      val ( * ) : t -> t -> t

      (** [a / b] returns the unique value [c] such that [a * c = b mod p] where
          [p] is the order of the field
      *)
      val ( / ) : t -> t -> t

      (** [a + b] returns the unique value [c] such that [a + b = c mod p] where
          [p] is the order of the field *)
      val ( + ) : t -> t -> t

      (** [a - b] returns the unique value [c] such that [a + c = b mod p] where
          [p] is the order of the field *)
      val ( - ) : t -> t -> t

      (** [inv x] returns the unique value [y] such that [x * y = one mod p]
          where [p] is the order of the field.
      *)
      val inv : t -> t

      (** [negate x] returns the unique value [y] such that [x + y = zero mod p]
          where [p] is the order of the field *)
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
