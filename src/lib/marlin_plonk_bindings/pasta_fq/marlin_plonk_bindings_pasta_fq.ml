type t

external size_in_bits : unit -> int = "caml_pasta_fq_size_in_bits"

external size : unit -> Marlin_plonk_bindings_bigint_256.t
  = "caml_pasta_fq_size"

external add : t -> t -> t = "caml_pasta_fq_add"

external sub : t -> t -> t = "caml_pasta_fq_sub"

external negate : t -> t = "caml_pasta_fq_negate"

external mul : t -> t -> t = "caml_pasta_fq_mul"

external div : t -> t -> t = "caml_pasta_fq_div"

external inv : t -> t option = "caml_pasta_fq_inv"

external square : t -> t = "caml_pasta_fq_square"

external is_square : t -> bool = "caml_pasta_fq_is_square"

external sqrt : t -> t option = "caml_pasta_fq_sqrt"

external of_int : int -> t = "caml_pasta_fq_of_int"

external to_string : t -> string = "caml_pasta_fq_to_string"

external of_string : string -> t = "caml_pasta_fq_of_string"

external print : t -> unit = "caml_pasta_fq_print"

external copy : over:t -> t -> unit = "caml_pasta_fq_copy"

external mut_add : t -> other:t -> unit = "caml_pasta_fq_mut_add"

external mut_sub : t -> other:t -> unit = "caml_pasta_fq_mut_sub"

external mut_mul : t -> other:t -> unit = "caml_pasta_fq_mut_mul"

external mut_square : t -> unit = "caml_pasta_fq_mut_square"

external compare : t -> t -> int = "caml_pasta_fq_compare"

external equal : t -> t -> bool = "caml_pasta_fq_equal"

external random : unit -> t = "caml_pasta_fq_random"

external rng : int -> t = "caml_pasta_fq_rng"

external to_bigint : t -> Marlin_plonk_bindings_bigint_256.t
  = "caml_pasta_fq_to_bigint"

external of_bigint : Marlin_plonk_bindings_bigint_256.t -> t
  = "caml_pasta_fq_of_bigint"

external two_adic_root_of_unity : unit -> t
  = "caml_pasta_fq_two_adic_root_of_unity"

external domain_generator : int -> t = "caml_pasta_fq_domain_generator"

external to_bytes : t -> Bytes.t = "caml_pasta_fq_to_bytes"

external of_bytes : Bytes.t -> t = "caml_pasta_fq_of_bytes"

external deep_copy : t -> t = "caml_pasta_fq_deep_copy"

let%test "deep_copy" =
  let x = random () in
  deep_copy x = x

let%test "operations" =
  let six = of_int 6 in
  let two = of_int 2 in
  let three = div six two in
  let six' = add three three in
  compare six six' = 0
