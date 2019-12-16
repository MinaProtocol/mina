(* tick_intf.ml -- enough of Snarky.Snark_intf.S to pass to Small_bit_vector functor

   if we used that full interface, callers of that functor (as in Currency) would themselves need
   access to that full interface

   for nonconsensus node compilation, we wish to have as minimal an interface as possible
*)

module type S = sig
  module rec Field : sig
    type t

    val zero : t

    val one : t

    val size_in_bits : int

    val add : t -> t -> t

    module Var : sig
      type t

      val project : Boolean.var list -> t

      val constant : Field.t -> t

      val add : t -> t -> t

      val pack : Boolean.var list -> t
    end

    module Checked : sig
      type comparison_result

      val unpack : Var.t -> length:int -> (Boolean.var list, _) Checked.t

      val compare :
        bit_length:int -> Var.t -> Var.t -> (comparison_result, 'a) Checked.t

      val equal : Var.t -> Var.t -> (Boolean.var, 's) Checked.t

      module Assert : sig
        val equal : Var.t -> Var.t -> (unit, 'a) Checked.t
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

    val typ : (var, value) Typ.t

    val var_of_value : value -> var

    val if_ : var -> then_:var -> else_:var -> (var, 'a) Checked.t
  end

  and Checked : sig
    type ('a, 's) t = ('a, 's, Field.t) Snarky.Checked.t

    val return : 'a -> ('a, 's) t

    module List : sig
      type 'a t = 'a list

      val all : ('a, 's) Checked.t t -> ('a t, 's) Checked.t
    end
  end

  module Bigint : sig
    type t

    val of_field : Field.t -> t

    val test_bit : t -> int -> bool
  end
end
