module type S = sig
  type (_, _) checked

  type (_, _) typ

  type bool_var

  type t

  val bit_length : int

  type var

  val typ : (var, t) typ

  val to_bits : t -> bool list

  val var : t -> var

  val assert_equal : var -> var -> (unit, _) checked

  val var_to_bits : var -> (bool_var list, _) checked

  val if_ : bool_var -> then_:var -> else_:var -> (var, _) checked

  val ( = ) : var -> var -> (bool_var, _) checked
end
