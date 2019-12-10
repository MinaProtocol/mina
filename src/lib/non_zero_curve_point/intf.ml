(* enough of an interface to allow the functor to work

   In its JS interface, snarky must export at least this much
 *)

open Core_kernel

module type Inputs_S = sig
  module rec Tick : sig
    type field

    module Checked : sig
      type ('a, 's) t = ('a, 's, field) Snarky.Checked.t
    end

    module Data_spec : sig
      type ('r_var, 'r_value, 'k_var, 'k_value) t =
        ('r_var, 'r_value, 'k_var, 'k_value, field) Snarky.Typ.Data_spec.t
    end

    module rec Field : sig
      type t = field [@@deriving eq, compare, hash]

      val zero : t

      val negate : t -> t

      val gen_uniform : t Quickcheck.Generator.t

      module Var : sig
        type t = field Snarky.Cvar.t

        val constant : field -> t
      end

      val typ : (Var.t, t) Typ.t

      module Checked : sig
        val equal : Var.t -> Var.t -> (Boolean.var, _) Checked.t

        val if_ :
          Boolean.var -> then_:Var.t -> else_:Var.t -> (Var.t, _) Checked.t

        val unpack_full :
             Var.t
          -> (Boolean.var Bitstring_lib.Bitstring.Lsb_first.t, _) Checked.t

        module Assert : sig
          val equal : Var.t -> Var.t -> (unit, _) Checked.t
        end
      end
    end

    and Typ : sig
      type ('var, 'value) t =
        ('var, 'value, field, (unit, unit) Checked.t) Snarky.Types.Typ.t

      val field : (Field.Var.t, field) t

      val ( * ) :
           ('var1, 'value1) t
        -> ('var2, 'value2) t
        -> ('var1 * 'var2, 'value1 * 'value2) t

      val of_hlistable :
           (unit, unit, 'k_var, 'k_value) Data_spec.t
        -> var_to_hlist:('var -> (unit, 'k_var) Snarky.H_list.t)
        -> var_of_hlist:((unit, 'k_var) Snarky.H_list.t -> 'var)
        -> value_to_hlist:('value -> (unit, 'k_value) Snarky.H_list.t)
        -> value_of_hlist:((unit, 'k_value) Snarky.H_list.t -> 'value)
        -> ('var, 'value) t
    end

    and Boolean : sig
      type var = Field.Var.t Snarky.Boolean.t

      type value = bool

      val if_ : var -> then_:var -> else_:var -> (var, 'a) Tick.Checked.t

      val var_of_value : value -> var

      val typ : (var, value) Tick.Typ.t

      val equal : var -> var -> (var, 'a) Tick.Checked.t

      val ( && ) : var -> var -> (var, 'a) Tick.Checked.t

      module Assert : sig
        val ( = ) : var -> var -> (unit, _) Tick.Checked.t
      end
    end

    module Bigint : sig
      type t

      val of_field : field -> t

      val test_bit : t -> int -> bool
    end

    module Inner_curve : sig
      type t

      module Affine : sig
        type t = field * field
      end

      val find_y : field -> field option

      val of_affine : Affine.t -> t

      val to_affine_exn : t -> Affine.t

      val to_affine : t -> Affine.t option

      module Checked : sig
        type t = Field.Var.t * Field.Var.t

        module Assert : sig
          val on_curve : t -> (unit, _) Checked.t
        end
      end
    end

    module Let_syntax : sig
      val ( >>= ) :
        ('a, 'e) Checked.t -> ('a -> ('b, 'e) Checked.t) -> ('b, 'e) Checked.t

      val ( >>| ) : ('a, 'e) Checked.t -> ('a -> 'b) -> ('b, 'e) Checked.t

      val return : 'a -> ('a, 'e) Checked.t

      val bind :
           ('a, 'e) Checked.t
        -> f:('a -> ('b, 'e) Checked.t)
        -> ('b, 'e) Checked.t

      val map : ('a, 'e) Checked.t -> f:('a -> 'b) -> ('b, 'e) Checked.t

      val both :
        ('a, 'e) Checked.t -> ('b, 'e) Checked.t -> ('a * 'b, 'e) Checked.t
    end

    module As_prover : sig
      type ('value, 's) t

      val read : ('var, 'value) Typ.t -> 'var -> ('value, 'prover_state) t

      val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t
    end

    val exists :
         ?request:('value Snarky.Request.t, 's) As_prover.t
      -> ?compute:('value, 's) As_prover.t
      -> ('var, 'value) Typ.t
      -> ('var, 's) Checked.t
  end
end
