(* intf.ml -- enough of an interface to allow the functor to work *)

open Core_kernel

module type Tick_S = sig
  type field

  module rec Checked : sig
    type ('a, 's) t = ('a, 's, field) Snarky.Checked.t

    val return : 'a -> ('a, 's) t

    module List : sig
      type 'a t = 'a list

      val all : ('a, 's) Checked.t t -> ('a t, 's) Checked.t
    end
  end

  module Data_spec : sig
    type ('r_var, 'r_value, 'k_var, 'k_value) t =
      ('r_var, 'r_value, 'k_var, 'k_value, field) Snarky.Typ.Data_spec.t
  end

  module rec Field : sig
    type t = field [@@deriving eq, compare, hash]

    val sexp_of_t : t -> Sexp.t

    val t_of_sexp : Sexp.t -> t

    val zero : t

    val one : t

    val negate : t -> t

    val add : t -> t -> t

    val inv : t -> t

    val of_int : int -> t

    val size_in_bits : int

    val gen_uniform : t Quickcheck.Generator.t

    module Var : sig
      type t = field Snarky.Cvar.t

      val project : Boolean.var list -> t

      val constant : field -> t

      val add : t -> t -> t

      val scale : t -> field -> t

      val pack : Boolean.var list -> t
    end

    val typ : (Var.t, t) Typ.t

    module Checked : sig
      type comparison_result

      val ( + ) : Var.t -> Var.t -> Var.t

      val ( - ) : Var.t -> Var.t -> Var.t

      val ( * ) : Field.t -> Var.t -> Var.t

      val compare :
        bit_length:int -> Var.t -> Var.t -> (comparison_result, 'a) Checked.t

      val equal : Var.t -> Var.t -> (Boolean.var, _) Checked.t

      val if_ :
        Boolean.var -> then_:Var.t -> else_:Var.t -> (Var.t, _) Checked.t

      val unpack : Var.t -> length:int -> (Boolean.var list, _) Checked.t

      val unpack_full :
        Var.t -> (Boolean.var Bitstring_lib.Bitstring.Lsb_first.t, _) Checked.t

      val mul : Var.t -> Var.t -> (Var.t, _) Checked.t

      module Assert : sig
        val equal : Var.t -> Var.t -> (unit, _) Checked.t
      end
    end
  end

  and Typ : sig
    type ('var, 'value, 'field, 'checked) typ =
          ('var, 'value, 'field, 'checked) Snarky.Types.Typ.typ =
      { store: 'value -> ('var, 'field) Snarky.Typ_monads.Store.t
      ; read: 'var -> ('value, 'field) Snarky.Typ_monads.Read.t
      ; alloc: ('var, 'field) Snarky.Typ_monads.Alloc.t
      ; check: 'var -> 'checked }

    type ('var, 'value) t = ('var, 'value, Field.t, (unit, unit) Checked.t) typ

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

    val transport :
         ('var, 'value1) t
      -> there:('value2 -> 'value1)
      -> back:('value1 -> 'value2)
      -> ('var, 'value2) t

    val list : length:int -> ('var, 'value) t -> ('var list, 'value list) t

    module Store : sig
      type 'a t = ('a, Field.t) Snarky.Typ_monads.Store.t

      val store : Field.t -> Field.Var.t t
    end

    module Alloc : sig
      type 'a t = ('a, Field.t) Snarky.Typ_monads.Alloc.t

      val alloc : Field.Var.t t
    end

    module Read : sig
      type 'a t = ('a, Field.t) Snarky.Typ_monads.Read.t

      val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

      module Let_syntax : sig
        val map : 'a t -> f:('a -> 'b) -> 'b t

        module Let_syntax : sig
          val return : 'a -> 'a t

          val bind : 'a t -> f:('a -> 'b t) -> 'b t

          val map : 'a t -> f:('a -> 'b) -> 'b t

          val both : 'a t -> 'b t -> ('a * 'b) t
        end
      end

      val read : Field.Var.t -> Field.t t
    end
  end

  and Boolean : sig
    type var = Field.Var.t Snarky.Boolean.t

    type value = bool

    val false_ : var

    val if_ : var -> then_:var -> else_:var -> (var, 'a) Checked.t

    val var_of_value : value -> var

    val typ : (var, value) Typ.t

    val equal : var -> var -> (var, 'a) Checked.t

    val ( && ) : var -> var -> (var, 'a) Checked.t

    module Unsafe : sig
      val of_cvar : Field.Var.t -> var
    end

    module Assert : sig
      val ( = ) : var -> var -> (unit, _) Checked.t
    end
  end

  module Number : sig
    type t

    val of_bits : Boolean.var list -> t
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
      ('a, 'e) Checked.t -> f:('a -> ('b, 'e) Checked.t) -> ('b, 'e) Checked.t

    val map : ('a, 'e) Checked.t -> f:('a -> 'b) -> ('b, 'e) Checked.t

    val both :
      ('a, 'e) Checked.t -> ('b, 'e) Checked.t -> ('a * 'b, 'e) Checked.t
  end

  module As_prover : sig
    type ('value, 's) t

    val read : ('var, 'value) Typ.t -> 'var -> ('value, 'prover_state) t

    val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t
  end

  val assert_r1cs :
       ?label:string
    -> Field.Var.t
    -> Field.Var.t
    -> Field.Var.t
    -> (unit, 'a) Checked.t

  val exists :
       ?request:('value Snarky.Request.t, 's) As_prover.t
    -> ?compute:('value, 's) As_prover.t
    -> ('var, 'value) Typ.t
    -> ('var, 's) Checked.t
end
