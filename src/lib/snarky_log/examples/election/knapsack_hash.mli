open Impl

type var

type t

val typ : (var, t) Typ.t

val var_to_bits : var -> (Boolean.var list, _) Checked.t

val to_bits : t -> bool list

val hash_var : Boolean.var list -> (var, _) Checked.t

val hash : bool list -> t

val assert_equal : var -> var -> (unit, _) Checked.t
