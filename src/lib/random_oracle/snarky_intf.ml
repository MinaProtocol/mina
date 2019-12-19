(* snarky_intf.ml -- enough of an interface to allow the random oracle functor to work *)

module type Curve_choice_S = sig
  module Tick0 : sig
    module rec Field : sig
      type t [@@deriving sexp, compare, equal]

      val size_in_bits : int

      val zero : t

      val one : t

      val square : t -> t

      val random : unit -> t

      val of_string : string -> t

      val add : t -> t -> t

      val mul : t -> t -> t

      val ( + ) : t -> t -> t

      val ( * ) : t -> t -> t

      val ( += ) : t -> t -> unit

      val ( *= ) : t -> t -> unit

      val unpack : t -> bool list

      val project : bool list -> t

      module Var : sig
        type t = Field.t Snarky.Cvar.t

        val constant : Field.t -> t

        val to_constant_and_terms :
          t -> Field.t option * (Field.t * Var.t) list
      end
    end

    and Var : sig
      type t

      val index : t -> int
    end
  end

  module Runners : sig
    module Tick : sig
      module Boolean : sig
        type var
      end

      module Field : sig
        type t = Tick0.Field.Var.t

        val square : t -> t

        val ( * ) : t -> t -> t

        val choose_preimage_var : t -> length:int -> Boolean.var list

        val project : Boolean.var list -> t
      end
    end
  end
end
