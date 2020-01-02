open Core_kernel

module type Full_S = sig end

module type Tick_or_tock_S = sig end

module type S = sig
  module Full : Full_S

  module Tick_or_tock : Tick_or_tock_S

  module Coefficients = Full.G1.Coefficients
  module T = Full.G1.T
  module T' = T.T'

  type t = T.t [@@deriving bin_io]

  val add : t -> t -> t

  val ( + ) : t -> t -> t

  val negate : t -> t

  val double : t -> t

  val scale_field : t -> Full.Field.t -> t

  val zero : t

  val one : t

  module Affine = T.Affine

  val to_affine_exn : t -> Affine.t

  val to_affine : t -> Affine.t sexp_option

  val of_affine : Affine.t -> t

  val equal : t -> t -> bool

  val random : unit -> t

  val delete : t -> unit

  val print : t -> unit

  val subgroup_check : t -> unit

  module Vector = T.Vector
  module Window_table = Full.G1.Window_table

  val find_y : field -> field sexp_option

  val point_near_x : field -> t

  val t_of_sexp : Base__Sexp.t -> t

  val sexp_of_t : t -> Base__Sexp.t

  type var = Field.Var.t * Field.Var.t

  module Scalar : sig
    module T : sig
      type t = Tick_or_tock.field [@@deriving bin_io, sexp]

      val hash_fold_t : Hash.state -> t -> Hash.state

      val hash : t -> int

      val compare : t -> t -> int

      val gen : t Base_quickcheck.Generator.t

      val gen_uniform : t Base_quickcheck.Generator.t

      val of_int : int -> t

      val one : t

      val zero : t

      val add : t -> t -> t

      val sub : t -> t -> t

      val mul : t -> t -> t

      val inv : t -> t

      val square : t -> t

      val sqrt : t -> t

      val is_square : t -> bool

      val equal : t -> t -> bool

      val size_in_bits : int

      val print : t -> unit

      val random : unit -> t

      module Mutable : sig
        val add : t -> other:t -> unit

        val mul : t -> other:t -> unit

        val sub : t -> other:t -> unit

        val copy : over:t -> t -> unit
      end

      val ( += ) : t -> t -> unit

      val ( -= ) : t -> t -> unit

      val ( *= ) : t -> t -> unit

      module Vector : sig
        type elt = t

        type nonrec t = elt Snarky.Vector.t

        val typ : t Ctypes.typ

        val delete : t -> unit

        val create : unit -> t

        val get : t -> int -> elt

        val emplace_back : t -> elt -> unit

        val length : t -> int
      end

      val negate : t -> t

      val ( + ) : t -> t -> t

      val ( * ) : t -> t -> t

      val ( - ) : t -> t -> t

      val ( / ) : t -> t -> t

      val of_string : string -> t

      val to_string : t -> string

      val size : Snarky.Libsnark.Bignum_bigint.t

      val unpack : t -> bool sexp_list

      val project : bool sexp_list -> t

      val project_reference : bool sexp_list -> t

      val parity : t -> bool

      type var' = Tick_or_tock.Var.t

      module Var : sig
        type t = Vector.elt Snarky.Cvar.t

        val length : t -> int

        val var_indices : t -> int sexp_list

        val to_constant_and_terms :
          t -> Vector.elt sexp_option * (Vector.elt * var') sexp_list

        val constant : Vector.elt -> t

        val to_constant : t -> Vector.elt sexp_option

        val linear_combination : (Vector.elt * t) sexp_list -> t

        val sum : t sexp_list -> t

        val add : t -> t -> t

        val sub : t -> t -> t

        val scale : t -> Vector.elt -> t

        val project : Tick_or_tock.Boolean.var sexp_list -> t

        val pack : Tick_or_tock.Boolean.var sexp_list -> t
      end

      module Checked : sig
        val mul : Var.t -> Var.t -> (Var.t, 'a) Tick_or_tock.Checked.t

        val square : Var.t -> (Var.t, 'a) Tick_or_tock.Checked.t

        val div : Var.t -> Var.t -> (Var.t, 'a) Tick_or_tock.Checked.t

        val inv : Var.t -> (Var.t, 'a) Tick_or_tock.Checked.t

        val is_square :
          Var.t -> (Tick_or_tock.Boolean.var, 'a) Tick_or_tock.Checked.t

        val sqrt : Var.t -> (Var.t, 'a) Tick_or_tock.Checked.t

        val sqrt_check :
             Var.t
          -> (Var.t * Tick_or_tock.Boolean.var, 'a) Tick_or_tock.Checked.t

        val equal :
             Var.t
          -> Var.t
          -> (Tick_or_tock.Boolean.var, 's) Tick_or_tock.Checked.t

        val unpack :
             Var.t
          -> length:int
          -> (Tick_or_tock.Boolean.var sexp_list, 'a) Tick_or_tock.Checked.t

        val unpack_flagged :
             Var.t
          -> length:int
          -> ( Tick_or_tock.Boolean.var sexp_list
               * [`Success of Tick_or_tock.Boolean.var]
             , 'a )
             Tick_or_tock.Checked.t

        val unpack_full :
             Var.t
          -> ( Tick_or_tock.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
             , 'a )
             Tick_or_tock.Checked.t

        val parity :
             ?length:int
          -> Var.t
          -> (Tick_or_tock.Boolean.var, 'a) Tick_or_tock.Checked.t

        val choose_preimage_var :
             Var.t
          -> length:int
          -> (Tick_or_tock.Boolean.var sexp_list, 'a) Tick_or_tock.Checked.t

        type comparison_result = Tick_or_tock.Field.Checked.comparison_result =
          { less: Tick_or_tock.Boolean.var
          ; less_or_equal: Tick_or_tock.Boolean.var }

        val compare :
             bit_length:int
          -> Var.t
          -> Var.t
          -> (comparison_result, 'a) Tick_or_tock.Checked.t

        val if_ :
             Tick_or_tock.Boolean.var
          -> then_:Var.t
          -> else_:Var.t
          -> (Var.t, 'a) Tick_or_tock.Checked.t

        val ( + ) : Var.t -> Var.t -> Var.t

        val ( - ) : Var.t -> Var.t -> Var.t

        val ( * ) : t -> Var.t -> Var.t

        module Unsafe : sig
          val of_index : int -> Var.t
        end

        module Assert : sig
          val lte :
               bit_length:int
            -> Var.t
            -> Var.t
            -> (unit, 'a) Tick_or_tock.Checked.t

          val gte :
               bit_length:int
            -> Var.t
            -> Var.t
            -> (unit, 'a) Tick_or_tock.Checked.t

          val lt :
               bit_length:int
            -> Var.t
            -> Var.t
            -> (unit, 'a) Tick_or_tock.Checked.t

          val gt :
               bit_length:int
            -> Var.t
            -> Var.t
            -> (unit, 'a) Tick_or_tock.Checked.t

          val not_equal : Var.t -> Var.t -> (unit, 'a) Tick_or_tock.Checked.t

          val equal : Var.t -> Var.t -> (unit, 'a) Tick_or_tock.Checked.t

          val non_zero : Var.t -> (unit, 'a) Tick_or_tock.Checked.t
        end
      end

      val typ : (Var.t, t) Tick_or_tock.Typ.t
    end

    type t = T.t [@@deriving bin_io, sexp, hash, compare]

    val of_int : int -> t

    val one : t

    val zero : t

    val add : t -> t -> t

    val sub : t -> t -> t

    val mul : t -> t -> t

    val inv : t -> t

    val square : t -> t

    val sqrt : t -> t

    val is_square : t -> bool

    val equal : t -> t -> bool

    val size_in_bits : int

    val print : t -> unit

    val random : unit -> t

    module Mutable : sig
      val add : t -> other:t -> unit

      val mul : t -> other:t -> unit

      val sub : t -> other:t -> unit

      val copy : over:t -> t -> unit
    end

    val ( += ) : t -> t -> unit

    val ( -= ) : t -> t -> unit

    val ( *= ) : t -> t -> unit

    module Vector : sig
      type elt = t

      type nonrec t = elt Snarky.Vector.t

      val typ : t Ctypes.typ

      val delete : t -> unit

      val create : unit -> t

      val get : t -> int -> elt

      val emplace_back : t -> elt -> unit

      val length : t -> int
    end

    val negate : t -> t

    val ( + ) : t -> t -> t

    val ( * ) : t -> t -> t

    val ( - ) : t -> t -> t

    val ( / ) : t -> t -> t

    val of_string : string -> t

    val to_string : t -> string

    val size : Snarky.Libsnark.Bignum_bigint.t

    val unpack : t -> bool sexp_list

    val project : bool sexp_list -> t

    val project_reference : bool sexp_list -> t

    val parity : t -> bool

    type var' = T.var'

    val of_bits : bool sexp_list -> Tick_or_tock.Field.t

    val length_in_bits : int

    type var = Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

    val typ : (var, t) Typ.t

    val gen : t Base_quickcheck.Generator.t

    val test_bit : t -> int -> bool

    module Checked : sig
      val equal :
           Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
        -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
        -> (Boolean.var, 'a) Checked.t

      val to_bits : 'a -> 'a

      module Assert : sig
        val equal : var -> var -> (unit, 'a) Checked.t
      end
    end
  end

  val ctypes_typ : t Ctypes.typ

  val scale : t -> Full.Field.t -> t

  module Checked : sig
    type t = Fq.t * Fq.t

    val typ : (t, T.t) Fq.Impl.Typ.t

    module Shifted : sig
      module type S = sig
        type t

        val zero : t

        val add : t -> t -> (t, 'a) Fq.Impl.Checked.t

        val unshift_nonzero : t -> (t, 'a) Fq.Impl.Checked.t

        val if_ :
             Fq.Impl.Boolean.var
          -> then_:t
          -> else_:t
          -> (t, 'a) Fq.Impl.Checked.t

        module Assert : sig
          val equal : t -> t -> (unit, 'a) Fq.Impl.Checked.t
        end
      end

      type 'a m = (module S with type t = 'a)

      val create : unit -> ((module S), 'a) Fq.Impl.Checked.t
    end

    val negate : t -> t

    val constant : T.t -> t

    val add_unsafe :
         t
      -> t
      -> ([`I_thought_about_this_very_carefully of t], 'a) Fq.Impl.Checked.t

    val if_ :
      Fq.Impl.Boolean.var -> then_:t -> else_:t -> (t, 'a) Fq.Impl.Checked.t

    val double : t -> (t, 'a) Fq.Impl.Checked.t

    val if_value : Fq.Impl.Boolean.var -> then_:T.t -> else_:T.t -> t

    val scale :
         's Shifted.m
      -> t
      -> Fq.Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
      -> init:'s
      -> ('s, 'a) Fq.Impl.Checked.t

    val scale_known :
         's Shifted.m
      -> T.t
      -> Fq.Impl.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t
      -> init:'s
      -> ('s, 'a) Fq.Impl.Checked.t

    val sum :
      's Shifted.m -> t sexp_list -> init:'s -> ('s, 'a) Fq.Impl.Checked.t

    module Assert : sig
      val on_curve : t -> (unit, 'a) Fq.Impl.Checked.t

      val equal : t -> t -> (unit, 'a) Fq.Impl.Checked.t
    end

    val add_known_unsafe :
         t
      -> T.t
      -> ([`I_thought_about_this_very_carefully of t], 'a) Fq.Impl.Checked.t
  end

  val typ : (Checked.t, t) Fq.Impl.Typ.t
end
