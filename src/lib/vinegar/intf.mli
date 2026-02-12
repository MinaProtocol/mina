open Core_kernel
open Vinegar_types
module Sponge_lib = Sponge

(** Generic interface over a concrete implementation [Impl] of an elliptic
    curve in Weierstrass form with [a] and [b]. In affine, the curve has the
    equation form [y² = x³ + ax + b]. *)
module Group (Impl : Snarky_backendless.Snark_intf.Run) : sig
  module type S = sig
    type t

    (** Parameters of the elliptic curve *)
    module Params : sig
      val a : Impl.Field.Constant.t

      val b : Impl.Field.Constant.t
    end

    module Constant : sig
      type t [@@deriving sexp, equal]

      val ( + ) : t -> t -> t

      val negate : t -> t

      (** The scalar field of the elliptic curve *)
      module Scalar : sig
        include Plonk_checks.Field_intf

        include Sexpable.S with type t := t

        val project : bool list -> t
      end

      val scale : t -> Scalar.t -> t

      (** [to_affine_exn p] returns the affine coordinates [(x, y)] of the point
          [p] *)
      val to_affine_exn : t -> Impl.field * Impl.field

      (** [of_affine (x, y)] builds a point on the curve
          TODO: check it is on the curve? Check it is in the prime subgroup?
      *)
      val of_affine : Impl.field * Impl.field -> t
    end

    (** Represent a point, but not necessarily on the curve and in the prime
        subgroup *)
    val typ_unchecked : (t, Constant.t) Impl.Typ.t

    (** Represent a point on the curve and in the prime subgroup *)
    val typ : (t, Constant.t) Impl.Typ.t

    (** Add two points on the curve.
        TODO: is the addition complete?
    *)
    val ( + ) : t -> t -> t

    (** Double the point *)
    val double : t -> t

    (** [scalar g xs] computes the scalar multiplication of [g] with [xs], where
        the scalar [xs] is given as a list of bits *)
    val scale : t -> Impl.Boolean.var list -> t

    val if_ : Impl.Boolean.var -> then_:t -> else_:t -> t

    (** [negate x] computes the opposite of [x] *)
    val negate : t -> t

    (** Return the affine coordinates of the point [t] *)
    val to_field_elements : t -> Impl.Field.t list

    (** MSM with precomputed scaled values *)
    module Scaling_precomputation : sig
      (** Precomputed table *)
      type t

      (** [create p] builds a table of scaled values of [p] which can be used to
          compute MSM *)
      val create : Constant.t -> t
    end

    val constant : Constant.t -> t

    (** MSM using a precomputed table *)
    val multiscale_known :
      (Impl.Boolean.var list * Scaling_precomputation.t) array -> t
  end
end

(** Hash functions that will be used for the Fiat Shamir transformation *)
module Sponge (Impl : Snarky_backendless.Snark_intf.Run) : sig
  module type S =
    Sponge.Intf.Sponge
      with module Field := Impl.Field
       and module State := Sponge.State
       and type input := Impl.Field.t
       and type digest := Impl.Field.t
       and type t = Impl.Field.t Sponge.t
end

(** Basic interface representing inputs of a computation *)
module type Inputs_base = sig
  module Impl : Snarky_backendless.Snark_intf.Run

  module Inner_curve : sig
    open Impl

    include Group(Impl).S with type t = Field.t * Field.t

    (** A generator on the curve and in the prime subgroup *)
    val one : t

    val if_ : Boolean.var -> then_:t -> else_:t -> t

    val scale_inv : t -> Boolean.var list -> t
  end

  module Other_field : sig
    type t = Inner_curve.Constant.Scalar.t [@@deriving sexp]

    include Shifted_value.Field_intf with type t := t

    val to_bigint : t -> Impl.Bigint.t

    val of_bigint : Impl.Bigint.t -> t

    val size : Import.B.t

    (** The size in bits for the canonical representation of a field
        element *)
    val size_in_bits : int

    (** [to_bits x] returns the little endian representation of the canonical
        representation of the field element [x] *)
    val to_bits : t -> bool list

    (** [of_bits bs] builds an element of the field using the little endian
        representation given by [bs] *)
    val of_bits : bool list -> t

    (** [is_square y] returns [true] if there exists an element [x] in the same
        field such that [x^2 = y], i.e [y] is a quadratic residue modulo [p] *)
    val is_square : t -> bool

    val print : t -> unit
  end

  module Generators : sig
    (** Fixed generator of the group. It must be a point on the curve and in the
        prime subgroup *)
    val h : Inner_curve.Constant.t Lazy.t
  end

  (** Parameters for the sponge that will be used as a random oracle for the
      Fiat Shamir transformation *)
  val sponge_params : Impl.Field.t Sponge_lib.Params.t
end

(** Interface for inputs for the outer computations *)
module Wrap_main_inputs : sig
  module type S = sig
    include Inputs_base

    module Sponge : sig
      open Impl

      include Sponge(Impl).S

      val squeeze_field : t -> Field.t
    end
  end
end

(** Interface for inputs for the inner computations *)
module Step_main_inputs : sig
  module type S = sig
    include Inputs_base

    module Sponge : sig
      include
        Sponge_lib.Intf.Sponge
          with module Field := Impl.Field
           and module State := Sponge_lib.State
           and type input :=
            [ `Field of Impl.Field.t | `Bits of Impl.Boolean.var list ]
           and type digest := Impl.Field.t
           and type t = Impl.Field.t Sponge_lib.t

      val squeeze_field : t -> Impl.Field.t
    end
  end
end

(** Represent a statement to be proven *)
module type Statement = sig
  type field

  type t

  val to_field_elements : t -> field array
end

module type Statement_var =
  Statement with type field := Backend.Tick.Field.t Snarky_backendless.Cvar.t

module type Statement_value = Statement with type field := Backend.Tick.Field.t
