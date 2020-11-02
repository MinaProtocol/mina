type t

external size_in_bits : unit -> int = "caml_tweedle_fp_size_in_bits"

external size :
  unit -> Marlin_plonk_bindings_bigint_256.t
  = "caml_tweedle_fp_size"

external add : t -> t -> t = "caml_tweedle_fp_add"

external sub : t -> t -> t = "caml_tweedle_fp_sub"

external negate : t -> t = "caml_tweedle_fp_negate"

external mul : t -> t -> t = "caml_tweedle_fp_mul"

external div : t -> t -> t = "caml_tweedle_fp_div"

external inv : t -> t option = "caml_tweedle_fp_inv"

external square : t -> t = "caml_tweedle_fp_square"

external is_square : t -> bool = "caml_tweedle_fp_is_square"

external sqrt : t -> t option = "caml_tweedle_fp_sqrt"

external of_int : int -> t = "caml_tweedle_fp_of_int"

external to_string : t -> string = "caml_tweedle_fp_to_string"

external of_string : string -> t = "caml_tweedle_fp_of_string"

external print : t -> unit = "caml_tweedle_fp_print"

external copy : t -> t = "caml_tweedle_fp_copy"

external mut_add : t -> other:t -> unit = "caml_tweedle_fp_mut_add"

external mut_sub : t -> other:t -> unit = "caml_tweedle_fp_mut_sub"

external mut_mul : t -> other:t -> unit = "caml_tweedle_fp_mut_mul"

external mut_square : t -> unit = "caml_tweedle_fp_mut_square"

external compare : t -> t -> int = "caml_tweedle_fp_compare"

external equal : t -> t -> bool = "caml_tweedle_fp_equal"

external random : unit -> t = "caml_tweedle_fp_random"

external rng : int -> t = "caml_tweedle_fp_rng"

external to_bigint :
  t -> Marlin_plonk_bindings_bigint_256.t
  = "caml_tweedle_fp_to_bigint"

external of_bigint :
  Marlin_plonk_bindings_bigint_256.t -> t
  = "caml_tweedle_fp_of_bigint"

external two_adic_root_of_unity :
  unit -> t
  = "caml_tweedle_fp_two_adic_root_of_unity"

external domain_generator : int -> t = "caml_tweedle_fp_domain_generator"
