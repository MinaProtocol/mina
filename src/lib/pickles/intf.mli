open Core_kernel
open Pickles_types
module Sponge_lib = Sponge

module Snarkable : sig
  module type S1 = sig
    type _ t

    val typ :
         ('var, 'value, 'f) Snarky_backendless.Typ.t
      -> ('var t, 'value t, 'f) Snarky_backendless.Typ.t
  end

  module type S2 = sig
    type (_, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky_backendless.Typ.t
      -> ('var2, 'value2, 'f) Snarky_backendless.Typ.t
      -> (('var1, 'var2) t, ('value1, 'value2) t, 'f) Snarky_backendless.Typ.t
  end

  module type S3 = sig
    type (_, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky_backendless.Typ.t
      -> ('var2, 'value2, 'f) Snarky_backendless.Typ.t
      -> ('var3, 'value3, 'f) Snarky_backendless.Typ.t
      -> ( ('var1, 'var2, 'var3) t
         , ('value1, 'value2, 'value3) t
         , 'f )
         Snarky_backendless.Typ.t
  end

  module type S4 = sig
    type (_, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky_backendless.Typ.t
      -> ('var2, 'value2, 'f) Snarky_backendless.Typ.t
      -> ('var3, 'value3, 'f) Snarky_backendless.Typ.t
      -> ('var4, 'value4, 'f) Snarky_backendless.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4) t
         , ('value1, 'value2, 'value3, 'value4) t
         , 'f )
         Snarky_backendless.Typ.t
  end

  module type S5 = sig
    type (_, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky_backendless.Typ.t
      -> ('var2, 'value2, 'f) Snarky_backendless.Typ.t
      -> ('var3, 'value3, 'f) Snarky_backendless.Typ.t
      -> ('var4, 'value4, 'f) Snarky_backendless.Typ.t
      -> ('var5, 'value5, 'f) Snarky_backendless.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5) t
         , ('value1, 'value2, 'value3, 'value4, 'value5) t
         , 'f )
         Snarky_backendless.Typ.t
  end

  module type S6 = sig
    type (_, _, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky_backendless.Typ.t
      -> ('var2, 'value2, 'f) Snarky_backendless.Typ.t
      -> ('var3, 'value3, 'f) Snarky_backendless.Typ.t
      -> ('var4, 'value4, 'f) Snarky_backendless.Typ.t
      -> ('var5, 'value5, 'f) Snarky_backendless.Typ.t
      -> ('var6, 'value6, 'f) Snarky_backendless.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5, 'var6) t
         , ('value1, 'value2, 'value3, 'value4, 'value5, 'value6) t
         , 'f )
         Snarky_backendless.Typ.t
  end

  module type S7 = sig
    type (_, _, _, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky_backendless.Typ.t
      -> ('var2, 'value2, 'f) Snarky_backendless.Typ.t
      -> ('var3, 'value3, 'f) Snarky_backendless.Typ.t
      -> ('var4, 'value4, 'f) Snarky_backendless.Typ.t
      -> ('var5, 'value5, 'f) Snarky_backendless.Typ.t
      -> ('var6, 'value6, 'f) Snarky_backendless.Typ.t
      -> ('var7, 'value7, 'f) Snarky_backendless.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5, 'var6, 'var7) t
         , ('value1, 'value2, 'value3, 'value4, 'value5, 'value6, 'value7) t
         , 'f )
         Snarky_backendless.Typ.t
  end

  module type S8 = sig
    type (_, _, _, _, _, _, _, _) t

    val typ :
         ('var1, 'value1, 'f) Snarky_backendless.Typ.t
      -> ('var2, 'value2, 'f) Snarky_backendless.Typ.t
      -> ('var3, 'value3, 'f) Snarky_backendless.Typ.t
      -> ('var4, 'value4, 'f) Snarky_backendless.Typ.t
      -> ('var5, 'value5, 'f) Snarky_backendless.Typ.t
      -> ('var6, 'value6, 'f) Snarky_backendless.Typ.t
      -> ('var7, 'value7, 'f) Snarky_backendless.Typ.t
      -> ('var8, 'value8, 'f) Snarky_backendless.Typ.t
      -> ( ('var1, 'var2, 'var3, 'var4, 'var5, 'var6, 'var7, 'var8) t
         , ( 'value1
           , 'value2
           , 'value3
           , 'value4
           , 'value5
           , 'value6
           , 'value7
           , 'value8 )
           t
         , 'f )
         Snarky_backendless.Typ.t
  end
end

module Evals : sig
  module type S = sig
    type n

    val n : n Nat.t

    include Binable.S1 with type 'a t = ('a, n) Vector.t

    include Snarkable.S1 with type 'a t := 'a t
  end
end

module Group (Impl : Snarky_backendless.Snark_intf.Run) : sig
  module type S = sig
    type t

    (** Parameters for the elliptic curve given in Weierstrass form in affine coordinates (i.e.
        [y^2 = x^3 + a x + b]) *)
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

      val to_affine_exn : t -> Impl.field * Impl.field

      val of_affine : Impl.field * Impl.field -> t
    end

    val typ_unchecked : (t, Constant.t, Impl.field) Snarky_backendless.Typ.t

    val typ : (t, Constant.t, Impl.field) Snarky_backendless.Typ.t

    val ( + ) : t -> t -> t

    val double : t -> t

    val scale : t -> Impl.Boolean.var list -> t

    val if_ : Impl.Boolean.var -> then_:t -> else_:t -> t

    val negate : t -> t

    val to_field_elements : t -> Impl.Field.t list

    module Scaling_precomputation : sig
      type t

      val create : Constant.t -> t
    end

    val constant : Constant.t -> t

    val multiscale_known :
      (Impl.Boolean.var list * Scaling_precomputation.t) array -> t
  end
end

module Sponge (Impl : Snarky_backendless.Snark_intf.Run) : sig
  module type S =
    Sponge.Intf.Sponge
      with module Field := Impl.Field
       and module State := Sponge.State
       and type input := Impl.Field.t
       and type digest := Impl.Field.t
       and type t = Impl.Field.t Sponge.t
end

module type Inputs_base = sig
  module Impl : Snarky_backendless.Snark_intf.Run

  module Inner_curve : sig
    open Impl

    include Group(Impl).S with type t = Field.t * Field.t

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

    val size_in_bits : int

    val to_bits : t -> bool list

    val of_bits : bool list -> t

    val is_square : t -> bool

    val print : t -> unit
  end

  module Generators : sig
    val h : Inner_curve.Constant.t Lazy.t
  end

  val sponge_params : Impl.Field.t Sponge_lib.Params.t
end

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

module type Statement = sig
  type field

  type t

  val to_field_elements : t -> field array
end

module type Statement_var =
  Statement with type field := Backend.Tick.Field.t Snarky_backendless.Cvar.t

module type Statement_value = Statement with type field := Backend.Tick.Field.t
