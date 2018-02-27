module type S = sig
  type (_, _) checked
  type field
  type field_var
  type bool_var

  type t

  val (+)      : t -> t -> t
  val (-)      : t -> t -> t
  val ( * )    : t -> t -> (t, _) checked
  val constant : field -> t

  val if_ : bool_var -> then_:t -> else_:t -> (t, _) checked

  val (<) : t -> t -> (bool_var, _) checked
  val (>) : t -> t -> (bool_var, _) checked
  val (<=) : t -> t -> (bool_var, _) checked
  val (>=) : t -> t -> (bool_var, _) checked
  val (=) : t -> t -> (bool_var, _) checked

  val to_var : t -> field_var

  val of_bits : bool_var list -> t
  val to_bits : t -> (bool_var list, _) checked

  val clamp_to_n_bits : t -> int -> (t, _) checked
end
