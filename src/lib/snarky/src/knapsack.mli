module Make (M : Snark_intf.S) : sig
  open M

  type t

  val create : dimension:int -> max_input_length:int -> t

  val hash_to_field : t -> bool list -> Field.t list

  val hash_to_bits : t -> bool list -> bool list

  module Hash (M : sig
    val knapsack : t
  end) : sig
    type value = bool list [@@deriving sexp]

    type var = Boolean.var list

    val length : int

    val typ : (var, value) Typ.t

    val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

    val hash : var -> var -> (var, _) Checked.t

    val assert_equal : var -> var -> (unit, _) Checked.t
  end

  module Checked : sig
    val hash_to_field :
      t -> Boolean.var list -> (Field.Checked.t list, _) Checked.t

    val hash_to_bits : t -> Boolean.var list -> (Boolean.var list, _) Checked.t
  end
end
