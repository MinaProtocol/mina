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
  module Params : sig
    val a : Impl.Field.Constant.t

    val b : Impl.Field.Constant.t

    val one : Impl.Field.Constant.t * Impl.Field.Constant.t

    val group_size_in_bits : int
  end

  module Constant : sig
    include module type of Kimchi_pasta.Pasta.Vesta.Affine

    module Scalar = Impls.Step.Field.Constant

    val scale : t -> Scalar.t -> t

    val random : unit -> t

    val zero : t

    val ( + ) : t -> t -> t

    val negate : t -> t

    val to_affine_exn : 'a -> 'a

    val of_affine : 'a -> 'a
  end

  type t = Impl.Field.t * Impl.Field.t

  val add' : div:(Impl.Field.t -> Impl.Field.t -> Impl.Field.t) -> t -> t -> t

  val add_exn : t -> t -> t

  val to_affine_exn : 'a -> 'a

  val constant : Constant.t -> t

  val negate : t -> t

  val one : t

  val assert_on_curve : t -> unit

  val typ_unchecked : (t, Constant.t) Impl.Typ.t

  val typ : (t, Constant.t) Impl.Typ.t

  val if_ : Impl.Boolean.var -> then_:t -> else_:t -> t

  module Scalar : sig
    type t = Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

    val of_field :
      Impl.Field.t -> Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

    val to_field :
      Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t -> Impl.Field.t
  end

  module type Shifted_intf = sig
    type t

    val zero : t

    val unshift_nonzero : t -> Impl.Field.t * Impl.Field.t

    val add : t -> Impl.Field.t * Impl.Field.t -> t

    val if_ : Impl.Boolean.var -> then_:t -> else_:t -> t
  end

  module Shifted : functor
    (_ : sig
       val shift : t
     end)
    ()
    -> Shifted_intf

  val shifted : unit -> (module Shifted_intf)

  module Window_table : sig
    type t = Constant.t Tuple_lib.Quadruple.t array

    val window_size : int

    val windows : int

    val shift_left_by_window_size : Constant.t -> Constant.t

    val create :
         shifts:Constant.t Core_kernel.Array.t
      -> Constant.t
      -> (Constant.t * Constant.t * Constant.t * Constant.t) Core_kernel.Array.t
  end

  val pow2s : Constant.t -> Constant.t Core_kernel.Array.t

  module Scaling_precomputation : sig
    type t =
      { base : Constant.t; shifts : Constant.t array; table : Window_table.t }

    val group_map :
      (Impl.Field.Constant.t -> Impl.Field.Constant.t * Impl.Field.Constant.t)
      lazy_t

    val string_to_bits : string -> bool list

    val create : Constant.t -> t
  end

  val add_unsafe : t -> t -> t

  val lookup_point :
       Impl.Boolean.var * Impl.Boolean.var
    -> Constant.t * Constant.t * Constant.t * Constant.t
    -> t

  val pairs :
    Impl.Boolean.var list -> (Impl.Boolean.var * Impl.Boolean.var) list

  type shifted = { value : t; shift : Constant.t }

  val unshift : shifted -> t

  val multiscale_known :
    (Impl.Boolean.var list * Scaling_precomputation.t) Core_kernel.Array.t -> t

  val scale_known : Scaling_precomputation.t -> Impl.Boolean.var list -> t

  val conditional_negation : Impl.Boolean.var -> t -> t

  val p_plus_q_plus_p : t -> t -> t

  val scale_fast :
       t
    -> [< `Plus_two_to_len_minus_1 of Impl.Boolean.var Core_kernel.Array.t ]
    -> t

  val ( + ) : t -> t -> t

  val double : t -> t

  val scale : t -> Impl.Boolean.var list -> t

  val to_field_elements : t -> Impl.Field.t list

  val assert_equal : t -> t -> unit

  val scale_inv : t -> Impl.Boolean.var list -> t
end

module Ops : module type of Plonk_curve_ops.Make (Impl) (Inner_curve)

module Generators : sig
  val h : (Impl.Field.Constant.t * Impl.Field.Constant.t) lazy_t
end

module Unsafe : sig
  val unpack_unboolean : ?length:int -> Impl.Field.t -> Impl.Boolean.var list
end
