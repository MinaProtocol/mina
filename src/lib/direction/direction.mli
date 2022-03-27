type t = Left | Right

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val equal : t -> t -> bool

val of_bool : bool -> t

val map : left:'a -> right:'a -> t -> 'a

val to_bool : t -> bool

val to_int : t -> int

val of_int : int -> t option

val of_int_exn : int -> t

val flip : t -> t

val gen : t Core_kernel__Quickcheck.Generator.t

val gen_var_length_list :
     ?start:Core_kernel.Int.t
  -> int
  -> t Core_kernel__.Import.list Core_kernel.Quickcheck.Generator.t

val gen_list :
     Core_kernel__.Import.int
  -> t Core_kernel__.Import.list Core_kernel.Quickcheck.Generator.t

val shrinker : t Core_kernel.Quickcheck.Shrinker.t
