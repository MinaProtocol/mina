module Impl = Impls.Wrap

val sponge_params : Impl.Field.t Sponge.Params.t

module Other_field : sig
  include module type of Backend.Tick.Field

  val size : Snarky_backendless.Snark_intf.Bignum_bigint.t
end

module Sponge : sig
  module Permutation :
      module type of
        Sponge_inputs.Make
          (Impl)
          (struct
            include Tock_field_sponge.Inputs

            let params = Tock_field_sponge.params
          end)

  module S : module type of Sponge.Make_sponge (Permutation)

  include module type of S

  (** Alias for [S.squeeze] *)
  val squeeze_field : t -> Permutation.Field.t
end

module Inner_curve : sig
  module Inputs : sig
    module Impl = Impls.Wrap.Impl

    module Params : sig
      val a : Kimchi_pasta.Pasta.Fq.t

      val b : Kimchi_pasta.Pasta.Fq.t

      val one : Kimchi_pasta.Pasta.Fq.t * Kimchi_pasta.Pasta.Fq.t

      val group_size_in_bits : int
    end

    module F : sig
      type t = Impl.Field.t

      val ( * ) : t -> t -> t

      val ( + ) : t -> t -> t

      val ( - ) : t -> t -> t

      val inv_exn : t -> t

      val square : t -> t

      val negate : t -> t

      module Constant : sig
        type t = Impl.Field.Constant.t

        val ( * ) : t -> t -> t

        val ( + ) : t -> t -> t

        val ( - ) : t -> t -> t

        val inv_exn : t -> t

        val square : t -> t

        val negate : t -> t
      end

      val assert_square : t -> t -> unit

      val assert_r1cs : t -> t -> t -> unit
    end

    module Constant : sig
      include module type of Kimchi_pasta.Pasta.Vesta.Affine

      module Scalar = Impls.Step.Field.Constant

      val scale : t -> Scalar.t -> t

      val random : unit -> t

      val zero : Impl.Field.Constant.t * Impl.Field.Constant.t

      val ( + ) : t -> t -> t

      val negate : t -> t

      val to_affine_exn : 'a -> 'a

      val of_affine : 'a -> 'a
    end
  end

  module Params = Inputs.Params
  module Constant = Inputs.Constant

  type t = Inputs.F.t * Inputs.F.t

  val double : t -> t

  val add' : div:(Inputs.F.t -> Inputs.F.t -> Inputs.F.t) -> t -> t -> t

  val add_exn : t -> t -> t

  val to_affine_exn : 'a -> 'a

  val constant : Inputs.Constant.t -> t

  val negate : t -> t

  val one : t

  val assert_on_curve : t -> unit

  val typ_unchecked : (t, Inputs.Constant.t) Inputs.Impl.Typ.t

  val typ : (t, Inputs.Constant.t) Inputs.Impl.Typ.t

  val if_ : Inputs.Impl.Boolean.var -> then_:t -> else_:t -> t

  module Scalar : sig
    type t = Inputs.Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

    val of_field :
         Inputs.Impl.Field.t
      -> Inputs.Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

    val to_field :
         Inputs.Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
      -> Inputs.Impl.Field.t
  end

  module type Shifted_intf = sig
    type t

    val zero : t

    val unshift_nonzero : t -> Inputs.F.t * Inputs.F.t

    val add : t -> Inputs.F.t * Inputs.F.t -> t

    val if_ : Inputs.Impl.Boolean.var -> then_:t -> else_:t -> t
  end

  module Shifted : functor
    (M : sig
       val shift : t
     end)
    ()
    -> Shifted_intf

  val shifted : unit -> (module Shifted_intf)

  val scale :
       ?init:Inputs.F.t * Inputs.F.t
    -> t
    -> Inputs.Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
    -> Inputs.F.t * Inputs.F.t

  module Window_table : sig
    type t = Inputs.Constant.t Tuple_lib.Quadruple.t array

    val window_size : int

    val windows : int

    val shift_left_by_window_size : Inputs.Constant.t -> Inputs.Constant.t

    val create :
         shifts:Inputs.Constant.t Core_kernel.Array.t
      -> Inputs.Constant.t
      -> ( Inputs.Constant.t
         * Inputs.Constant.t
         * Inputs.Constant.t
         * Inputs.Constant.t )
         Core_kernel.Array.t
  end

  val pow2s : Inputs.Constant.t -> Inputs.Constant.t Core_kernel.Array.t

  module Scaling_precomputation : sig
    type t =
      { base : Inputs.Constant.t
      ; shifts : Inputs.Constant.t array
      ; table : Window_table.t
      }

    val group_map :
      (   Inputs.Impl.Field.Constant.t
       -> Inputs.Impl.Field.Constant.t * Inputs.Impl.Field.Constant.t )
      lazy_t

    val string_to_bits : string -> bool list

    val create : Inputs.Constant.t -> t
  end

  val add_unsafe : Inputs.F.t * Inputs.F.t -> Inputs.F.t * Inputs.F.t -> t

  val lookup_point :
       Inputs.Impl.Boolean.var * Inputs.Impl.Boolean.var
    -> Inputs.Constant.t
       * Inputs.Constant.t
       * Inputs.Constant.t
       * Inputs.Constant.t
    -> Inputs.Impl.Field.t * Inputs.Impl.Field.t

  val pairs :
       Inputs.Impl.Boolean.var list
    -> (Inputs.Impl.Boolean.var * Inputs.Impl.Boolean.var) list

  type shifted = { value : t; shift : Inputs.Constant.t }

  val unshift : shifted -> t

  val multiscale_known :
       (Inputs.Impl.Boolean.var list * Scaling_precomputation.t)
       Core_kernel.Array.t
    -> t

  val scale_known :
    Scaling_precomputation.t -> Inputs.Impl.Boolean.var list -> t

  val conditional_negation :
       Inputs.Impl.Boolean.var
    -> 'a * Inputs.Impl.Field.t
    -> 'a * Inputs.Impl.Field.t

  val p_plus_q_plus_p : t -> t -> Inputs.Impl.Field.t * Inputs.Impl.Field.t

  val scale_fast :
       Inputs.Impl.Field.t * Inputs.F.t
    -> [< `Plus_two_to_len_minus_1 of
          Inputs.Impl.Boolean.var Core_kernel.Array.t ]
    -> t

  val ( + ) :
       Impls.Wrap.field Snarky_backendless.Cvar.t
       * Impls.Wrap.field Snarky_backendless.Cvar.t
    -> Impls.Wrap.field Snarky_backendless.Cvar.t
       * Impls.Wrap.field Snarky_backendless.Cvar.t
    -> Impls.Wrap.field Snarky_backendless.Cvar.t
       * Impls.Wrap.field Snarky_backendless.Cvar.t

  val double :
       Impls.Wrap.field Snarky_backendless.Cvar.t
       * Impls.Wrap.field Snarky_backendless.Cvar.t
    -> Impls.Wrap.field Snarky_backendless.Cvar.t
       * Impls.Wrap.field Snarky_backendless.Cvar.t

  val scale : t -> Inputs.Impl.Boolean.var list -> Inputs.F.t * Inputs.F.t

  val to_field_elements : 'a * 'a -> 'a list

  val assert_equal :
       Impls.Wrap.Field.t * Impls.Wrap.Field.t
    -> Impls.Wrap.Field.t * Impls.Wrap.Field.t
    -> unit

  val scale_inv : t -> Inputs.Impl.Boolean.var list -> t
end

module Ops : module type of Plonk_curve_ops.Make (Impls.Wrap) (Inner_curve)

module Generators : sig
  val h : (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t) lazy_t
end

module Unsafe : sig
  val unpack_unboolean :
    ?length:int -> Impls.Wrap.Field.t -> Impl.Boolean.var list
end
